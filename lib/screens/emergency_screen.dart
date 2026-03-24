import 'package:flutter/material.dart';
import 'package:telephony/telephony.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import '../services/emergency_alarm_service.dart';
import '../services/app_theme.dart';

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
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _relationController = TextEditingController();
  
  // Safety Tools State
  final AudioPlayer _sirenPlayer = AudioPlayer();
  bool _isSirenPlaying = false;

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
    _nameController.dispose();
    _phoneController.dispose();
    _relationController.dispose();
    _sirenPlayer.dispose();
    _pulseController.dispose();
    super.dispose();
  }
  
  Future<void> _loadPreferences() async {
    _emergencyContacts = await _alertService.getEmergencyContacts();
    if (mounted) setState(() {});
  }

  Future<void> _checkPermissions() async {
    final Telephony telephony = Telephony.instance;
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != true) {
      debugPrint("SMS permissions not granted");
    }
  }

  Future<void> _triggerEmergencyAlert() async {
    if (_isAlertActive) return;
    
    await _startCountdown();
    
    if (!mounted) return;
    
    setState(() => _isAlertActive = true);
    
    // Activate emergency alert
    await _alertService.activateEmergency();
    
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

  void _onEmergencyButtonPressed() async {
    if (_emergencyContacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add emergency contacts first')),
      );
      return;
    }

    await _triggerEmergencyAlert();
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
    await _alertService.deactivateEmergency();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Alert Cancelled'), duration: Duration(seconds: 2)),
      );
    }
  }

  void _addEmergencyContact() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();
    final relation = _relationController.text.trim();
    
    if (name.isEmpty || phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter name and phone number')),
      );
      return;
    }

    await _alertService.addEmergencyContact(name, phone, relation);
    
    _nameController.clear();
    _phoneController.clear();
    _relationController.clear();
    await _loadPreferences();
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name added to contacts')),
      );
    }
  }

  void _removeEmergencyContact(String phone) async {
    await _alertService.removeEmergencyContact(phone);

    await _loadPreferences();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$phone removed from contacts')),
      );
    }
  }

  void _showAddContactDialog() {
    _nameController.clear();
    _phoneController.clear();
    _relationController.clear();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          top: 24,
          left: 24,
          right: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Add Trusted Contact',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF0D47A1),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We will alert them when you trigger SOS.',
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildModernTextField(
              controller: _nameController,
              label: 'Full Name',
              icon: Icons.person_outline,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _phoneController,
              label: 'Phone Number',
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildModernTextField(
              controller: _relationController,
              label: 'Relationship (Optional)',
              icon: Icons.favorite_border,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _addEmergencyContact,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Save Contact',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: const Color(0xFF0D47A1), size: 22),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          labelStyle: TextStyle(color: Colors.grey[600]),
        ),
      ),
    );
  }

  Widget _buildToolCard({
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return Card(
      color: color,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: textColor),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency Alert System'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Header
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: _isAlertActive 
                        ? AppTheme.warningRed.withValues(alpha: 0.1) 
                        : const Color(0xFFE8F5E9), // Light Green
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _isAlertActive ? AppTheme.warningRed : const Color(0xFF4CAF50),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isAlertActive ? Icons.warning_amber_rounded : Icons.shield_outlined,
                        color: _isAlertActive ? AppTheme.warningRed : const Color(0xFF4CAF50),
                        size: 16
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isAlertActive ? "EMERGENCY BROADCAST ACTIVE" : "SYSTEM ARMED & READY",
                        style: TextStyle(
                          color: _isAlertActive ? AppTheme.warningRed : const Color(0xFF2E7D32),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
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
                          child: const Column(
                            children: [
                              Icon(Icons.emergency, size: 48),
                              SizedBox(height: 8),
                              Text('TAP FOR SOS', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                              Text('Hold for Instant Alert', style: TextStyle(fontSize: 12, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // Safety Toolkit Section
              Text('Safety Toolkit', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildToolCard(
                      icon: _isSirenPlaying ? Icons.volume_up : Icons.volume_off,
                      label: _isSirenPlaying ? 'Stop Siren' : 'Loud Siren',
                      color: _isSirenPlaying ? AppTheme.warningRed : Colors.white,
                      textColor: _isSirenPlaying ? Colors.white : AppTheme.textDark,
                      onTap: _toggleSiren,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildToolCard(
                      icon: Icons.phone_in_talk,
                      label: 'Fake Call',
                      color: Colors.white,
                      textColor: AppTheme.textDark,
                      onTap: () {
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulating incoming call...')));
                      },
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              Text('Emergency Contacts', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ..._emergencyContacts.map((contact) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFFBBDEFB),
                    child: Text(contact['name'][0].toUpperCase(), style: const TextStyle(color: Color(0xFF0D47A1))),
                  ),
                  title: Text(contact['name']),
                  subtitle: Text('${contact['phone']} ${contact['relation'] != null && contact['relation'].isNotEmpty ? '• ${contact['relation']}' : ''}'),
                  trailing: IconButton(icon: const Icon(Icons.delete, color: AppTheme.warningRed), onPressed: () => _removeEmergencyContact(contact['phone']))
                ),
              )),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _showAddContactDialog, child: const Text('+ Add Contact'))),
            ],
          ),
        ),
      ),
    );
  }
}