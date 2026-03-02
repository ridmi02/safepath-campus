import 'package:flutter/material.dart';
import '../services/emergency_alarm_service.dart';
import '../services/app_theme.dart';

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen> {
  final EmergencyAlertService _alertService = EmergencyAlertService();
  
  bool _isAlertActive = false;
  List<String> _emergencyContacts = [];
  int _countdownSeconds = 0;
  
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }
  
  Future<void> _loadPreferences() async {
    _emergencyContacts = await _alertService.getEmergencyContacts();
    if (mounted) setState(() {});
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
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a phone number')),
      );
      return;
    }

    await _alertService.addEmergencyContact(phone);
    
    _phoneController.clear();
    await _loadPreferences();
    
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$phone added to contacts')),
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
    _phoneController.clear();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Add Emergency Contact',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        content: TextField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            hintText: '+1 (555) 123-4567',
            labelText: 'Phone Number',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _addEmergencyContact,
            child: const Text('Add'),
          ),
        ],
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
              if (_countdownSeconds > 0)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(
                      'Sending alert in $_countdownSeconds...',
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
                child: ElevatedButton(
                  onPressed: _onEmergencyButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningRed,
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.emergency, size: 48),
                      SizedBox(height: 8),
                      Text('SOS ALERT', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text('Emergency Contacts', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 12),
              ..._emergencyContacts.map((contact) => Card(child: ListTile(title: Text(contact), trailing: IconButton(icon: const Icon(Icons.delete, color: AppTheme.warningRed), onPressed: () => _removeEmergencyContact(contact))))),
              const SizedBox(height: 12),
              SizedBox(width: double.infinity, child: OutlinedButton(onPressed: _showAddContactDialog, child: const Text('+ Add Contact'))),
            ],
          ),
        ),
      ),
    );
  }
}