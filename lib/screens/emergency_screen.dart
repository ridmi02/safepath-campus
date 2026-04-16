import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'dart:ui';
import '../services/emergency_alarm_service.dart';
import '../services/app_theme.dart';
import 'emergency_active_page.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> with SingleTickerProviderStateMixin {
  final EmergencyAlertService _alertService = EmergencyAlertService();

  bool _isAlertActive = false;
  List<Map<String, dynamic>> _emergencyContacts = [];
  int _countdownSeconds = 0;
  bool _showSosCountdown = false;

  // Safety Tools State
  final AudioPlayer _sirenPlayer = AudioPlayer();
  bool _isSirenPlaying = false;
  String _selectedEmergencyType = 'General';
  List<String> _dispatchSteps = [];
  final Map<String, String> _contactAckStatus = <String, String>{};

  final List<String> _emergencyTypes = const [
    'General',
    'Medical',
    'Threat',
    'Accident',
  ];

  IconData _typeIcon(String type) {
    switch (type) {
      case 'Medical':
        return Icons.medical_services_rounded;
      case 'Threat':
        return Icons.report_gmailerrorred_rounded;
      case 'Accident':
        return Icons.car_crash_rounded;
      case 'General':
      default:
        return Icons.shield_rounded;
    }
  }

  String _typeSubtitle(String type) {
    switch (type) {
      case 'Medical':
        return 'Health emergency';
      case 'Threat':
        return 'Immediate danger';
      case 'Accident':
        return 'Incident / crash';
      case 'General':
      default:
        return 'General SOS';
    }
  }

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shadowAnimation;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermissions();
    
    // Initialize heartbeat animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _shadowAnimation = Tween<double>(begin: 4.0, end: 12.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sirenPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPreferences() async {
    _emergencyContacts = await _alertService.getEmergencyContacts();
    if (mounted) setState(() {});
  }

  Future<void> _checkPermissions() async {
    // url_launcher opens the system SMS app — no direct SMS send permission required.
    debugPrint("SMS will be sent via url_launcher (system SMS app).");
  }

  Future<void> _triggerEmergencyAlert() async {
    if (_isAlertActive) return;
    
    await _startCountdown();
    
    if (!mounted) return;
    
    setState(() => _isAlertActive = true);
    setState(() {
      _dispatchSteps = [
        'Preparing $_selectedEmergencyType alert',
      ];
      _contactAckStatus.clear();
      for (final contact in _emergencyContacts) {
        final phone = (contact['phone'] ?? '').toString();
        if (phone.isNotEmpty) {
          _contactAckStatus[phone] = 'Pending';
        }
      }
    });
    
    // Activate emergency alert
    await _alertService.activateEmergency(emergencyType: _selectedEmergencyType);
    _simulateDispatchProgress();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Emergency Alert Activated!'),
          backgroundColor: AppTheme.warningRed,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'CANCEL',
            textColor: Colors.white,
            onPressed: _cancelAlert,
          ),
        ),
      );
    }
  }

  Future<void> _simulateDispatchProgress() async {
    final stagedSteps = <String>[
      'Sending emergency messages',
      'Broadcasting live location',
      'Waiting for acknowledgements',
    ];
    for (final step in stagedSteps) {
      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted || !_isAlertActive) return;
      setState(() => _dispatchSteps = [..._dispatchSteps, step]);
    }

    if (!mounted || !_isAlertActive) return;
    var index = 0;
    final phones = _contactAckStatus.keys.toList();
    for (final phone in phones) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (!mounted || !_isAlertActive) return;
      setState(() {
        _contactAckStatus[phone] = index == 0 ? 'Responded' : 'Seen';
      });
      index++;
    }
  }

  void _onEmergencyButtonPressed() async {
    if (_emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add emergency contacts first')),
      );
      return;
    }

    await _runSosCountdownThenNavigate();
  }

  Future<void> _runSosCountdownThenNavigate() async {
    if (_showSosCountdown) return;
    setState(() => _showSosCountdown = true);

    var seconds = 3;
    while (seconds > 0 && mounted && _showSosCountdown) {
      setState(() => _countdownSeconds = seconds);
      await Future.delayed(const Duration(seconds: 1));
      seconds--;
    }

    if (!mounted) return;
    if (!_showSosCountdown) return;

    setState(() {
      _countdownSeconds = 0;
      _showSosCountdown = false;
    });

    // Trigger the actual SOS alerts (SMS and Firestore)
    final smsLaunchSuccess = await _alertService.activateEmergency(emergencyType: _selectedEmergencyType);

    if (mounted) {
      if (smsLaunchSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Emergency Alert Activated! Opening SMS app(s)...'),
            backgroundColor: AppTheme.warningRed,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'CANCEL',
              textColor: Colors.white,
              onPressed: _cancelAlert,
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to open SMS app. Alert sent to server.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushNamed(
      '/emergency_active',
      arguments: EmergencyActiveArgs(
        emergencyType: _selectedEmergencyType,
        contacts: List<Map<String, dynamic>>.from(_emergencyContacts),
      ),
    );
  }

  void _toggleSiren() async {
    setState(() => _isSirenPlaying = !_isSirenPlaying);
    
    if (_isSirenPlaying) {
      // Note: Ensure you have added 'assets/sounds/siren.mp3' to your pubspec.yaml
      // await _sirenPlayer.play(AssetSource('sounds/siren.mp3'));
      
      // Haptic Feedback loop as fallback or addition
      bool canVibrate = await Vibrate.canVibrate;
      if (canVibrate) {
        Vibrate.vibrateWithPauses([
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 1000),
          const Duration(milliseconds: 500),
          const Duration(milliseconds: 1000),
        ]);
      }
    } else {
      await _sirenPlayer.stop();
    }
  }

  Future<void> _startCountdown() async {
    setState(() => _countdownSeconds = 5);
    
    for (int i = 5; i > 0; i--) {
      if (!mounted) return;
      
      setState(() => _countdownSeconds = i);
      await Future.delayed(const Duration(seconds: 1));
    }
    if (mounted) setState(() => _countdownSeconds = 0);
  }

  void _cancelAlert() async {
    setState(() => _isAlertActive = false);
    setState(() => _countdownSeconds = 0);
    setState(() {
      _dispatchSteps = [];
      _contactAckStatus.clear();
    });
    await _alertService.deactivateEmergency();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert Cancelled'), duration: Duration(seconds: 2)),
      );
    }
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Card(
      color: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        onTap: onTap,
          borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: textColor),
                const SizedBox(height: 10),
                Text(
                  label,
                  style: TextStyle(color: textColor, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlertTypeSelector() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Alert type',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          // Make cards tall enough for icon + 2 text lines.
          childAspectRatio: 2.6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: _emergencyTypes.map((type) {
            final selected = _selectedEmergencyType == type;
            final color = selected ? colorScheme.primary : colorScheme.onSurface;
            return InkWell(
              onTap: _isAlertActive ? null : () => setState(() => _selectedEmergencyType = type),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primary.withValues(alpha: 0.10)
                      : colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? colorScheme.primary.withValues(alpha: 0.45)
                        : colorScheme.outlineVariant,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: selected
                            ? colorScheme.primary.withValues(alpha: 0.18)
                            : colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_typeIcon(type), color: color, size: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            type,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: color,
                              fontSize: 12.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _typeSubtitle(type),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(
                        Icons.check_circle_rounded,
                        color: theme.colorScheme.primary,
                        size: 18,
                      ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildContactsNavCard() {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emergency contacts',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => Navigator.of(context).pushNamed('/emergency_contacts'),
          borderRadius: BorderRadius.circular(24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                if (_emergencyContacts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: Icon(Icons.people_outline, color: primaryColor),
                  )
                else
                  SizedBox(
                    width: 100,
                    height: 40,
                    child: Stack(
                      children: List.generate(_emergencyContacts.length > 3 ? 3 : _emergencyContacts.length, (i) {
                        final name = _emergencyContacts[i]['name'] ?? '?';
                        return Positioned(
                          left: i * 25,
                          child: CircleAvatar(
                            radius: 20,
                            backgroundColor: primaryColor.withValues(alpha: 0.8),
                            child: Text(name[0].toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                          ),
                        );
                      }),
                    ),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _emergencyContacts.isEmpty ? 'Add emergency contacts' : 'Manage Contacts',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text('${_emergencyContacts.length} people will be alerted', style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDispatchSection() {
    if (!_isAlertActive) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lastIdx = _dispatchSteps.isEmpty ? -1 : _dispatchSteps.length - 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Dispatch progress',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(_dispatchSteps.length, (i) {
                final step = _dispatchSteps[i];
                final isLast = i == lastIdx;
                final isDone = !isLast;
                final dotColor = isDone
                    ? const Color(0xFF2E7D32)
                    : theme.colorScheme.primary;

                return Padding(
                  padding: EdgeInsets.only(bottom: i == lastIdx ? 0 : 12),
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
                                color: colorScheme.outlineVariant,
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
                              color: colorScheme.onSurface,
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
        ),
        const SizedBox(height: 10),
        Text(
          'Contact Acknowledgement',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 10),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: colorScheme.outlineVariant),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: _contactAckStatus.entries.map((entry) {
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
                      Expanded(child: Text(entry.key)),
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
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _isAlertActive 
        ? AppTheme.warningRed 
        : const Color(0xFF2E7D32);
    final statusBg = _isAlertActive 
        ? AppTheme.warningRed.withValues(alpha: 0.1) 
        : (Theme.of(context).brightness == Brightness.dark ? Colors.green.withValues(alpha: 0.2) : const Color(0xFFE8F5E9));
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Emergency Alert System'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  gradient: LinearGradient(
                    colors: _isAlertActive
                        ? const [Color(0xFFFFE2E2), Color(0xFFFFF1F1)]
                        : (Theme.of(context).brightness == Brightness.dark
                            ? [colorScheme.tertiaryContainer.withOpacity(0.2), colorScheme.tertiaryContainer.withOpacity(0.1)]
                            : const [Color(0xFFE3F7EA), Color(0xFFEEF9F2)]),
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: statusColor.withValues(alpha: 0.10),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  ),
                  child: Row(
                    children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: statusBg,
                      child: Icon(
                        _isAlertActive ? Icons.warning_amber_rounded : Icons.shield_outlined,
                        color: _isAlertActive
                            ? statusColor
                            : (Theme.of(context).brightness == Brightness.dark ? colorScheme.onTertiaryContainer : statusColor),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(
                            _isAlertActive ? 'Emergency Active' : 'System Ready',
                        style: TextStyle(
                              color: statusColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_emergencyContacts.length} trusted contacts configured',
                            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                        ),
                      ),
                    ],
                ),
              ),

              if (_countdownSeconds > 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Sending alert in $_countdownSeconds',
                      style: const TextStyle(fontSize: 20, color: AppTheme.warningRed, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                
              if (_isAlertActive) ...[
                Card(
                  color: AppTheme.lightGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.warningRed, width: 2),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        const Text('EMERGENCY ALERT ACTIVE', style: TextStyle(color: AppTheme.warningRed, fontWeight: FontWeight.bold, fontSize: 18)),
                        const SizedBox(height: 10),
                        ElevatedButton(onPressed: _cancelAlert, style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningRed), child: const Text('Cancel Alert')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _buildAlertTypeSelector(),
              const SizedBox(height: 16),
              
              SizedBox(
                width: double.infinity,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _isAlertActive ? 1.0 : _scaleAnimation.value,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.warningRed.withValues(alpha: 0.4),
                              blurRadius: _shadowAnimation.value,
                              spreadRadius: 0,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _onEmergencyButtonPressed,
                          onLongPress: _triggerEmergencyAlert,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningRed,
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0, // Handled by container for animation
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.emergency, size: 48),
                              const SizedBox(height: 8),
                              const Text('TAP FOR SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text('Hold for Instant Alert', style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              // _buildDispatchSection(), // This section is now handled by EmergencyActivePage
              if (_isAlertActive) const SizedBox(height: 24),

              Text(
                'Safety Toolkit',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildToolCard(
                      icon: _isSirenPlaying ? Icons.volume_up : Icons.volume_off,
                      label: _isSirenPlaying ? 'Stop Siren' : 'Loud Siren',
                      color: _isSirenPlaying ? AppTheme.warningRed : Theme.of(context).colorScheme.surfaceContainerHigh,
            textColor: _isSirenPlaying ? Theme.of(context).colorScheme.onError : Theme.of(context).colorScheme.onSurface,
                      onTap: _toggleSiren,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToolCard(
                      icon: Icons.phone_in_talk,
                      label: 'Fake Call',
                      color: Theme.of(context).colorScheme.surfaceContainerHigh,
                      textColor: Theme.of(context).colorScheme.onSurface,
                      onTap: () {
                        Navigator.of(context).pushNamed('/fake_call');
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              _buildContactsNavCard(),
              const SizedBox(height: 24),
            ],
              ),
            ),
          ),
          if (_showSosCountdown)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 300,
                        padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.12),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppTheme.warningRed.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(
                                    Icons.emergency,
                                    color: AppTheme.warningRed,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Starting SOS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _showSosCountdown = false;
                                      _countdownSeconds = 0;
                                    });
                                  },
                                  icon: const Icon(Icons.close),
                                  tooltip: 'Cancel',
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                'Hold tight. We’re preparing your alert…',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              width: 130,
                              height: 130,
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: (_countdownSeconds <= 0)
                                          ? 1
                                          : (1 - ((_countdownSeconds - 1) / 3)),
                                    ),
                                    duration: const Duration(milliseconds: 260),
                                    builder: (context, value, _) {
                                      return CircularProgressIndicator(
                                        strokeWidth: 10,
                                        value: value.clamp(0, 1),
                                        backgroundColor: Colors.black.withValues(alpha: 0.06),
                                        valueColor: const AlwaysStoppedAnimation<Color>(
                                          AppTheme.warningRed,
                                        ),
                                      );
                                    },
                                  ),
                                  Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      color: colorScheme.surface,
                                      shape: BoxShape.circle,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.1),
                                          blurRadius: 12,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$_countdownSeconds',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 44,
                                          color: AppTheme.warningRed,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _showSosCountdown = false;
                                    _countdownSeconds = 0;
                                  });
                                },
                                child: const Text('Cancel'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}