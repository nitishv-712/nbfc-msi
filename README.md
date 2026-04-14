# MSI Fan Control

A Flutter Linux desktop app for monitoring and controlling fan speed on **MSI GF63 Thin 11SC** (and compatible MSI GF-series laptops).

> Works by reading/writing MSI Embedded Controller (EC) registers directly via `/dev/port` — no kernel module required.

---

## Features

- Real-time CPU & GPU temperature monitoring
- CPU & GPU fan RPM + speed percentage
- All 8 CPU core temperatures (Intel i7-11800H)
- NVMe SSD temperature
- Battery status, charge level, health & cycle count
- CPU frequency per-core + governor
- Fan mode switching: **Auto / Silent / Basic / Advanced**
- **Cooler Boost** toggle (forces fans to 100%)
- Auto-refresh every 2 seconds

---

## Hardware

| Component | Details |
|-----------|---------|
| Laptop | MSI GF63 Thin 11SC |
| CPU | Intel Core i7-11800H (8C/16T, up to 4.6 GHz) |
| EC Layout | `MSI_ADDRESS_DEFAULT` |
| Kernel | Linux (tested on 6.19 zen) |
| Distro | Garuda Linux (Arch-based) |

---

## Project Structure

```
nbfc/
├── lib/
│   ├── main.dart          # Flutter UI
│   └── fan_service.dart   # EC read/write service
├── ec_helper/
│   ├── ec_helper.c        # C helper binary (reads/writes /dev/port)
│   └── install.sh         # Build & install script (setuid root)
└── README.md
```

---

## How It Works

The MSI EC is accessed via the standard ACPI EC I/O ports:

| Port | Role |
|------|------|
| `0x62` | EC data port |
| `0x66` | EC command/status port |

The `ec_helper` C binary communicates with the EC using the standard read (`0x80`) / write (`0x81`) protocol, waiting on IBF/OBF status bits before each operation.

### EC Register Map (`MSI_ADDRESS_DEFAULT`)

| Register | Address | Description |
|----------|---------|-------------|
| `fan_mode` | `0xF4` | Fan control mode |
| `cooler_boost` | `0x98` | Cooler Boost (0=off, 128=on) |
| `cpu_temp` (realtime) | `0x68` | CPU temperature °C |
| `gpu_temp` (realtime) | `0x80` | GPU temperature °C |
| `cpu_fan_speed` (realtime) | `0x71` | CPU fan speed % |
| `gpu_fan_speed` (realtime) | `0x89` | GPU fan speed % |
| `cpu_fan_rpm` | `0xCC–0xCD` | CPU fan RPM (16-bit, formula: `478000 / raw`) |
| `gpu_fan_rpm` | `0xCA–0xCB` | GPU fan RPM (16-bit, formula: `478000 / raw`) |
| `battery_threshold` | `0xEF` | Battery charge limit % |
| `usb_backlight` | `0xF7` | USB backlight control |

### Fan Mode Values

| Mode | Value | Description |
|------|-------|-------------|
| Auto | `140` | EC controls fan automatically |
| Silent | `76` | Low noise, reduced performance |
| Basic | `12` | Manual fixed-speed curve |
| Advanced | `44` | Aggressive cooling |

### CPU Fan Speed Curve (from isw GF63_9SC profile)

| CPU Temp (°C) | Fan Speed (%) |
|--------------|--------------|
| 55 | 35 |
| 64 | 38 |
| 73 | 42 |
| 76 | 45 |
| 82 | 50 |
| 88 | 55 |
| >88 | 62 |

---

## Setup

### Prerequisites

- Flutter SDK (`sdk: ^3.11.4`)
- GCC (for compiling `ec_helper`)
- Linux with `/dev/port` accessible

### 1. Install the EC helper

```bash
cd ec_helper
chmod +x install.sh
./install.sh
```

This compiles `ec_helper.c` and installs it to `/usr/local/bin/ec_helper` with **setuid root** so the Flutter app can access EC registers without a password prompt.

Verify it works:

```bash
ec_helper dump
```

Expected output:

```json
{
  "fan_mode": 140,
  "cooler_boost": 0,
  "cpu_temp": 55,
  "gpu_temp": 48,
  "cpu_fan_pct": 38,
  "gpu_fan_pct": 0,
  "cpu_fan_rpm": 2318,
  "gpu_fan_rpm": 0
}
```

### 2. Run the app

```bash
flutter pub get
flutter run -d linux
```

### 3. Build a release binary

```bash
flutter build linux --release
```

Output: `build/linux/x64/release/bundle/nbfc`

---

## Sysfs Data Sources

In addition to EC registers, the app reads supplementary data from sysfs:

| Data | Path |
|------|------|
| CPU package temp | `/sys/class/hwmon/hwmon5/temp1_input` |
| CPU core temps (×8) | `/sys/class/hwmon/hwmon5/temp2–9_input` |
| NVMe temp | `/sys/class/hwmon/hwmon3/temp1_input` |
| NVMe crit temp | `/sys/class/hwmon/hwmon3/temp1_crit` (`94.85°C`) |
| Battery capacity % | `/sys/class/power_supply/BAT1/capacity` |
| Battery status | `/sys/class/power_supply/BAT1/status` |
| Battery charge now | `/sys/class/power_supply/BAT1/charge_now` |
| Battery charge full | `/sys/class/power_supply/BAT1/charge_full` |
| Battery design cap | `/sys/class/power_supply/BAT1/charge_full_design` |
| Battery cycle count | `/sys/class/power_supply/BAT1/cycle_count` |
| Battery voltage | `/sys/class/power_supply/BAT1/voltage_now` |
| Battery current | `/sys/class/power_supply/BAT1/current_now` |
| CPU freq per-core | `/sys/devices/system/cpu/cpuN/cpufreq/scaling_cur_freq` |
| CPU governor | `/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor` |
| Available governors | `performance`, `powersave` |

---

## Why Not msi-ec or nbfc-linux?

| Tool | Status |
|------|--------|
| `msi-ec` kernel module | `Operation not supported` — GF63 Thin 11SC EC firmware not in supported list |
| `nbfc-linux` | No config for GF63 Thin 11SC |
| `isw` | Has GF63 up to 9SC only, not 11SC |
| **This app** | Direct EC I/O via `/dev/port` — works on any MSI using `MSI_ADDRESS_DEFAULT` layout |

---

## ec_helper Usage (CLI)

```bash
# Dump all EC values as JSON
ec_helper dump

# Read a single register
ec_helper read 0xf4        # fan mode
ec_helper read 0x98        # cooler boost

# Write a register
ec_helper write 0xf4 140   # set fan mode to Auto
ec_helper write 0xf4 76    # set fan mode to Silent
ec_helper write 0x98 128   # enable Cooler Boost
ec_helper write 0x98 0     # disable Cooler Boost
```

---

## Compatibility

This app targets MSI laptops using the `MSI_ADDRESS_DEFAULT` EC register layout. Confirmed working models from the isw project:

- GF62 7RD/7RE/8RE/8RC/8RD
- GF63 8RC/8RD/8RCS/9RC/9RCX/9SC
- GF65 9SD/9SE
- **GF63 Thin 11SC** (this device — same EC layout confirmed)

For other MSI models, verify your EC addresses using:

```bash
ec_helper read 0xf4   # should return 140 (auto mode) on a fresh boot
```
# nbfc-msi
