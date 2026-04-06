import 'dart:async';

import 'package:flutter/material.dart';
import 'package:safepath_campus/services/app_theme.dart';
import 'package:flutter/services.dart';

class EmergencyActiveArgs {
  EmergencyActiveArgs({
    required this.emergencyType,
    required this.contacts,
  });

  final String emergencyType;
  final List<Map<String, dynamic>> contacts;
}

class EmergencyActivePage extends StatefulWidget {
  const EmergencyActivePage({super.key, required this.args});

  final EmergencyActiveArgs args;

  @override
  State<EmergencyActivePage> createState() => _EmergencyActivePageState();
}

class _EmergencyActivePageState extends State<EmergencyActivePage> {
  bool _active = true;
  final List<String> _steps = [];
  final Map<String, String> _ack = <String, String>{};
  Timer? _timer;
  late final DateTime _startedAt;
  Timer? _clockTimer;
  Duration _elapsed = Duration.zero;
  bool _silentMode = false;
  bool _shareLocation = true;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();
    for (final c in widget.args.contacts) {
      final phone = (c['phone'] ?? '').toString();
      if (phone.isNotEmpty) {
        _ack[phone] = 'Pending';
      }
    }
    _start();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(_startedAt));
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    setState(() {
      _steps
        ..clear()
        ..add('Preparing ${widget.args.emergencyType} alert');
    });
    _simulateProgress();
  }

  void _simulateProgress() {
    final staged = <String>[
      'Sending messages to trusted contacts',
      'Sharing live location',
      'Waiting for acknowledgements',
    ];

    var idx = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 900), (t) {
      if (!mounted || !_active) {
        t.cancel();
        return;
      }
      if (idx < staged.length) {
        setState(() => _steps.add(staged[idx]));
        idx++;
        return;
      }

      // After steps, simulate acknowledgements
      t.cancel();
      final phones = _ack.keys.toList();
      var j = 0;
      Timer.periodic(const Duration(milliseconds: 700), (t2) {
        if (!mounted || !_active) {
          t2.cancel();
          return;
        }
        if (j >= phones.length) {
          t2.cancel();
          return;
        }
        setState(() {
          _ack[phones[j]] = j == 0 ? 'Responded' : 'Seen';
        });
        j++;
      });
    });
  }

  Future<void> _cancel() async {
    setState(() => _active = false);
    if (mounted) Navigator.of(context).pop();
  }

  String _formatElapsed(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${d.inHours > 0 ? '${d.inHours}:' : ''}$mm:$ss';
  }

  Widget _progressCard() {
    final theme = Theme.of(context);
    final last = _steps.isEmpty ? -1 : _steps.length - 1;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(_steps.length, (i) {
            final step = _steps[i];
            final isLast = i == last;
            final isDone = !isLast;
            final dotColor =
                isDone ? const Color(0xFF2E7D32) : theme.colorScheme.primary;

            return Padding(
              padding: EdgeInsets.only(bottom: i == last ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: dotColor.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                          border: Border.all(color: dotColor.withValues(alpha: 0.35)),
                        ),
                        child: isDone
                            ? const Icon(Icons.check, size: 16, color: Color(0xFF2E7D32))
                            : Padding(
                                padding: const EdgeInsets.all(6),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(dotColor),
                                ),
                              ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 18,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        step,
                        style: TextStyle(
                          fontWeight: isLast ? FontWeight.w800 : FontWeight.w600,
                          color: Colors.black.withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _ackCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: _ack.entries.map((entry) {
            final status = entry.value;
            final statusColor = status == 'Responded'
                ? const Color(0xFF2E7D32)
                : status == 'Seen'
                    ? const Color(0xFF1565C0)
                    : const Color(0xFFEF6C00);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  const Icon(Icons.phone, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      entry.key,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: const Text('Emergency Active'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE2E2), Color(0xFFFFF1F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppTheme.warningRed.withValues(alpha: 0.30)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppTheme.warningRed.withValues(alpha: 0.12),
                  child: const Icon(Icons.warning_amber_rounded, color: AppTheme.warningRed),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Emergency Alert Active',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: AppTheme.warningRed,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Type: ${widget.args.emergencyType}',
                        style: const TextStyle(color: Colors.black54),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.timer, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Text(
                            'Active: ${_formatElapsed(_elapsed)}',
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: _cancel,
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick controls',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Silent mode'),
                    subtitle: const Text('Reduce attention while alert remains active'),
                    value: _silentMode,
                    onChanged: (v) => setState(() => _silentMode = v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Share live location'),
                    subtitle: const Text('Frontend simulation toggle'),
                    value: _shareLocation,
                    onChanged: (v) => setState(() => _shareLocation = v),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              const ClipboardData(text: 'SOS! I need help.'),
                            );
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Emergency message copied')),
                            );
                          },
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy message'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Resend simulated')),
                            );
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Resend'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dispatch progress',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _progressCard(),
          const SizedBox(height: 16),
          Text(
            'Contact acknowledgements',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          _ackCard(),
        ],
      ),
    );
  }
}

