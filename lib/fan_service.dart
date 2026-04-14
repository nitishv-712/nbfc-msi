import 'dart:convert';
import 'dart:io';

const _helper = '/usr/local/bin/ec_helper';

// fan_mode EC values
const fanModeAuto = 140;
const fanModeSilent = 76;
const fanModeBasic = 12;
const fanModeAdvanced = 44;

class FanData {
  final int fanMode; // raw EC value
  final bool coolerBoost;
  final int cpuTemp; // °C
  final int gpuTemp; // °C
  final int cpuFanRpm;
  final int gpuFanRpm;
  final int cpuFanPct;
  final int gpuFanPct;

  FanData({
    required this.fanMode,
    required this.coolerBoost,
    required this.cpuTemp,
    required this.gpuTemp,
    required this.cpuFanRpm,
    required this.gpuFanRpm,
    required this.cpuFanPct,
    required this.gpuFanPct,
  });

  String get fanModeName => switch (fanMode) {
    fanModeAuto => 'Auto',
    fanModeSilent => 'Silent',
    fanModeBasic => 'Basic',
    fanModeAdvanced => 'Advanced',
    _ => 'Unknown ($fanMode)',
  };

  factory FanData.fromJson(Map<String, dynamic> j) => FanData(
    fanMode: j['fan_mode'] as int,
    coolerBoost: (j['cooler_boost'] as int) == 128,
    cpuTemp: j['cpu_temp'] as int,
    gpuTemp: j['gpu_temp'] as int,
    cpuFanRpm: j['cpu_fan_rpm'] as int,
    gpuFanRpm: j['gpu_fan_rpm'] as int,
    cpuFanPct: j['cpu_fan_pct'] as int,
    gpuFanPct: j['gpu_fan_pct'] as int,
  );
}

class FanService {
  static bool get helperInstalled => File(_helper).existsSync();

  static Future<FanData?> read() async {
    try {
      final r = await Process.run(_helper, ['dump']);
      if (r.exitCode != 0) return null;
      final j = jsonDecode(r.stdout as String) as Map<String, dynamic>;
      return FanData.fromJson(j);
    } catch (_) {
      return null;
    }
  }

  static Future<bool> setFanMode(int mode) => _write(0xf4, mode);

  static Future<bool> setCoolerBoost(bool on) => _write(0x98, on ? 128 : 0);

  static Future<bool> _write(int addr, int val) async {
    final r = await Process.run(_helper, [
      'write',
      '0x${addr.toRadixString(16)}',
      '$val',
    ]);
    return r.exitCode == 0;
  }
}
