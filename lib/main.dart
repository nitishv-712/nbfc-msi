import 'dart:async';
import 'package:flutter/material.dart';
import 'fan_service.dart';

void main() => runApp(const FanControlApp());

class FanControlApp extends StatelessWidget {
  const FanControlApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MSI Fan Control',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.cyan,
          brightness: Brightness.dark,
        ),
      ),
      home: const FanPage(),
    );
  }
}

class FanPage extends StatefulWidget {
  const FanPage({super.key});

  @override
  State<FanPage> createState() => _FanPageState();
}

class _FanPageState extends State<FanPage> {
  FanData? _data;
  bool _busy = false;
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _refresh();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  Future<void> _refresh() async {
    if (!FanService.helperInstalled) {
      setState(
        () => _error = 'ec_helper not installed.\nRun: ec_helper/install.sh',
      );
      return;
    }
    final data = await FanService.read();
    if (mounted)
      setState(() {
        _data = data;
        _error = data == null ? 'Failed to read EC' : null;
      });
  }

  Future<void> _setMode(int mode) async {
    setState(() => _busy = true);
    await FanService.setFanMode(mode);
    await _refresh();
    setState(() => _busy = false);
  }

  Future<void> _toggleCoolerBoost() async {
    if (_data == null) return;
    setState(() => _busy = true);
    await FanService.setCoolerBoost(!_data!.coolerBoost);
    await _refresh();
    setState(() => _busy = false);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MSI Fan Control'),
        backgroundColor: Colors.transparent,
      ),
      body: _error != null
          ? Center(
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            )
          : _data == null
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final d = _data!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: _TempCard(label: 'CPU', temp: d.cpuTemp),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _TempCard(label: 'GPU', temp: d.gpuTemp),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _FanCard(
                  label: 'CPU Fan',
                  rpm: d.cpuFanRpm,
                  pct: d.cpuFanPct,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _FanCard(
                  label: 'GPU Fan',
                  rpm: d.gpuFanRpm,
                  pct: d.gpuFanPct,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ModeSelector(current: d.fanMode, busy: _busy, onSelect: _setMode),
          const SizedBox(height: 12),
          _CoolerBoostTile(
            on: d.coolerBoost,
            busy: _busy,
            onToggle: _toggleCoolerBoost,
          ),
        ],
      ),
    );
  }
}

class _TempCard extends StatelessWidget {
  final String label;
  final int temp;
  const _TempCard({required this.label, required this.temp});

  Color get _color => temp >= 90
      ? Colors.red
      : temp >= 70
      ? Colors.orange
      : Colors.green;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Icon(Icons.thermostat, color: _color, size: 28),
            Text(
              '$temp °C',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: _color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FanCard extends StatelessWidget {
  final String label;
  final int rpm;
  final int pct;
  const _FanCard({required this.label, required this.rpm, required this.pct});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            const Icon(Icons.wind_power, color: Colors.cyan, size: 28),
            Text(
              '$rpm RPM',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text('$pct%', style: const TextStyle(color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final int current;
  final bool busy;
  final void Function(int) onSelect;

  const _ModeSelector({
    required this.current,
    required this.busy,
    required this.onSelect,
  });

  static const _modes = [
    (label: 'Auto', value: fanModeAuto, icon: Icons.auto_mode),
    (label: 'Silent', value: fanModeSilent, icon: Icons.volume_off),
    (label: 'Basic', value: fanModeBasic, icon: Icons.tune),
    (label: 'Advanced', value: fanModeAdvanced, icon: Icons.rocket_launch),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Fan Mode',
              style: TextStyle(fontSize: 14, color: Colors.white54),
            ),
            const SizedBox(height: 12),
            Row(
              children: _modes.map((m) {
                final selected = current == m.value;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilledButton.tonal(
                      style: FilledButton.styleFrom(
                        backgroundColor: selected
                            ? cs.primary
                            : cs.surfaceContainerHighest,
                        foregroundColor: selected ? cs.onPrimary : cs.onSurface,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: busy || selected
                          ? null
                          : () => onSelect(m.value),
                      child: Column(
                        children: [
                          Icon(m.icon, size: 20),
                          const SizedBox(height: 4),
                          Text(m.label, style: const TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoolerBoostTile extends StatelessWidget {
  final bool on;
  final bool busy;
  final VoidCallback onToggle;
  const _CoolerBoostTile({
    required this.on,
    required this.busy,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: on ? Colors.red.withValues(alpha: 0.15) : null,
      child: ListTile(
        leading: Icon(
          Icons.local_fire_department,
          color: on ? Colors.red : Colors.white38,
          size: 32,
        ),
        title: const Text(
          'Cooler Boost',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          on ? 'Fans at 100% speed' : 'Normal fan control',
          style: const TextStyle(color: Colors.white54),
        ),
        trailing: busy
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Switch(value: on, onChanged: (_) => onToggle()),
      ),
    );
  }
}
