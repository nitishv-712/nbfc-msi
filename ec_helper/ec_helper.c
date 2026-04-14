// MSI EC helper - reads/writes EC registers via /dev/port
// Usage:
//   ec_helper read <hex_addr>
//   ec_helper write <hex_addr> <value>
//   ec_helper dump   -> prints all relevant MSI EC values as JSON

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>

#define EC_DATA_PORT  0x62
#define EC_CMD_PORT   0x66
#define EC_CMD_READ   0x80
#define EC_CMD_WRITE  0x81
#define EC_IBF        0x02
#define EC_OBF        0x01

// MSI EC register addresses
#define ADDR_FAN_MODE       0xf4
#define ADDR_COOLER_BOOST   0x98
#define ADDR_CPU_TEMP       0x68
#define ADDR_CPU_FAN_RPM    0xcc
#define ADDR_GPU_TEMP       0x80
#define ADDR_GPU_FAN_RPM    0xca
#define ADDR_CPU_FAN_SPEED  0x71
#define ADDR_GPU_FAN_SPEED  0x89

// Fan mode values
#define FAN_MODE_AUTO     140
#define FAN_MODE_SILENT    76
#define FAN_MODE_BASIC     12
#define FAN_MODE_ADVANCED  44

static int port_fd = -1;

static int open_port() {
    port_fd = open("/dev/port", O_RDWR);
    if (port_fd < 0) {
        perror("open /dev/port");
        return -1;
    }
    return 0;
}

static unsigned char read_port(int addr) {
    unsigned char val;
    lseek(port_fd, addr, SEEK_SET);
    read(port_fd, &val, 1);
    return val;
}

static void write_port(int addr, unsigned char val) {
    lseek(port_fd, addr, SEEK_SET);
    write(port_fd, &val, 1);
}

static void wait_ibf_clear() {
    while (read_port(EC_CMD_PORT) & EC_IBF);
}

static void wait_obf_set() {
    while (!(read_port(EC_CMD_PORT) & EC_OBF));
}

static unsigned char ec_read(unsigned char addr) {
    wait_ibf_clear();
    write_port(EC_CMD_PORT, EC_CMD_READ);
    wait_ibf_clear();
    write_port(EC_DATA_PORT, addr);
    wait_obf_set();
    return read_port(EC_DATA_PORT);
}

static void ec_write(unsigned char addr, unsigned char val) {
    wait_ibf_clear();
    write_port(EC_CMD_PORT, EC_CMD_WRITE);
    wait_ibf_clear();
    write_port(EC_DATA_PORT, addr);
    wait_ibf_clear();
    write_port(EC_DATA_PORT, val);
}

static int rpm_from_ec(unsigned char hi, unsigned char lo) {
    int raw = (hi << 8) | lo;
    if (raw == 0 || raw == 0xffff) return 0;
    return 478000 / raw;
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        fprintf(stderr, "Usage: ec_helper <read|write|dump> [addr] [val]\n");
        return 1;
    }

    if (open_port() < 0) return 1;

    if (strcmp(argv[1], "read") == 0 && argc == 3) {
        unsigned char addr = (unsigned char)strtol(argv[2], NULL, 16);
        printf("%d\n", ec_read(addr));

    } else if (strcmp(argv[1], "write") == 0 && argc == 4) {
        unsigned char addr = (unsigned char)strtol(argv[2], NULL, 16);
        unsigned char val  = (unsigned char)atoi(argv[3]);
        ec_write(addr, val);
        printf("ok\n");

    } else if (strcmp(argv[1], "dump") == 0) {
        unsigned char fan_mode     = ec_read(ADDR_FAN_MODE);
        unsigned char cooler_boost = ec_read(ADDR_COOLER_BOOST);
        unsigned char cpu_temp     = ec_read(ADDR_CPU_TEMP);
        unsigned char gpu_temp     = ec_read(ADDR_GPU_TEMP);
        unsigned char cpu_fan_pct  = ec_read(ADDR_CPU_FAN_SPEED);
        unsigned char gpu_fan_pct  = ec_read(ADDR_GPU_FAN_SPEED);
        unsigned char cpu_rpm_hi   = ec_read(ADDR_CPU_FAN_RPM);
        unsigned char cpu_rpm_lo   = ec_read(ADDR_CPU_FAN_RPM + 1);
        unsigned char gpu_rpm_hi   = ec_read(ADDR_GPU_FAN_RPM);
        unsigned char gpu_rpm_lo   = ec_read(ADDR_GPU_FAN_RPM + 1);

        printf("{\n");
        printf("  \"fan_mode\": %d,\n", fan_mode);
        printf("  \"cooler_boost\": %d,\n", cooler_boost);
        printf("  \"cpu_temp\": %d,\n", cpu_temp);
        printf("  \"gpu_temp\": %d,\n", gpu_temp);
        printf("  \"cpu_fan_pct\": %d,\n", cpu_fan_pct);
        printf("  \"gpu_fan_pct\": %d,\n", gpu_fan_pct);
        printf("  \"cpu_fan_rpm\": %d,\n", rpm_from_ec(cpu_rpm_hi, cpu_rpm_lo));
        printf("  \"gpu_fan_rpm\": %d\n",  rpm_from_ec(gpu_rpm_hi, gpu_rpm_lo));
        printf("}\n");

    } else {
        fprintf(stderr, "Unknown command\n");
        close(port_fd);
        return 1;
    }

    close(port_fd);
    return 0;
}
