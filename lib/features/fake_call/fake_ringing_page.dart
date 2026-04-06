import 'package:flutter/material.dart';

class FakeRingingPage extends StatefulWidget {
  const FakeRingingPage({
    super.key,
    required this.callerName,
    required this.scenario,
    required this.note,
    required this.ringtone,
  });

  final String callerName;
  final String scenario;
  final String note;
  final String ringtone;

  @override
  State<FakeRingingPage> createState() => _FakeRingingPageState();
}

class _FakeRingingPageState extends State<FakeRingingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _onDecline() {
    Navigator.of(context).pop();
  }

  void _onAccept() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Call connected (simulation)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final caller = widget.callerName.trim().isEmpty
        ? 'Unknown Caller'
        : widget.callerName.trim();

    return Scaffold(
      backgroundColor: const Color(0xFF0C1324),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          child: Column(
            children: [
              const Text(
                'Incoming call',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                caller,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                widget.scenario,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const Spacer(),
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha((0.08 * 255).round()),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Center(
                    child: Icon(Icons.person, size: 90, color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha((0.08 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ringtone: ${widget.ringtone}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      widget.note.trim().isEmpty ? 'No note provided' : widget.note,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: _CallActionButton(
                      icon: Icons.call_end,
                      label: 'Decline',
                      color: const Color(0xFFE53935),
                      onTap: _onDecline,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _CallActionButton(
                      icon: Icons.call,
                      label: 'Accept',
                      color: theme.colorScheme.primary,
                      onTap: _onAccept,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}
