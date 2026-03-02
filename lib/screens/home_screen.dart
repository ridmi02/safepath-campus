import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/emergency_alarm_service.dart';
import '../services/app_theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final EmergencyAlertService _alertService = EmergencyAlertService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  late SharedPreferences _prefs;
  bool _isListening = false;
  bool _isAlertActive = false;
  String _lastRecognizedText = '';
  String _panicWord = 'help';
  double _voiceSensitivity = 0.8;
  List<String> _emergencyContacts = [];
  int _countdownSeconds = 0;
  
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _panicWordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    _prefs = await SharedPreferences.getInstance();
    _loadPreferences();
    await _initializeSpeech();
  }
  
  Future<void> _loadPreferences() async {
    _panicWord = await _alertService.getPanicWord() ?? 'help';
    _voiceSensitivity = _prefs.getDouble('voiceSensitivity') ?? 0.8;
    _emergencyContacts = await _alertService.getEmergencyContacts();
    _panicWordController.text = _panicWord;
    setState(() {});
  }

  Future<void> _initializeSpeech() async {
    try {
      await _speechToText.initialize(
        onError: (error) => debugPrint('Error: $error'),
        onStatus: (status) => debugPrint('Status: $status'),
      );
    } catch (e) {
      debugPrint('Error initializing speech: $e');
    }
  }

  void _toggleVoiceListening() async {
    if (_isListening) {
      await _speechToText.stop();
      setState(() => _isListening = false);
    } else {
      if (!_speechToText.isAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Speech recognition not available')),
        );
        return;
      }

      await _speechToText.listen(
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) {
            final recognized = result.recognizedWords.toLowerCase();
            setState(() => _lastRecognizedText = recognized);
            
            // Check if panic word was detected
            if (_isPanicWordDetected(recognized)) {
              _triggerEmergencyAlert();
            }
          }
        },
      );

      setState(() => _isListening = true);
    }
  }

  bool _isPanicWordDetected(String recognizedText) {
    final panicLower = _panicWord.toLowerCase();

    // A direct 'contains' check is the most reliable way to detect a panic phrase.
    // The previous fuzzy matching logic was prone to errors and has been removed
    // for simplicity and accuracy.
    return recognizedText.contains(panicLower);
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

  void _savePanicWordSettings() async {
    final newPanicWord = _panicWordController.text.trim();
    
    if (newPanicWord.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panic word cannot be empty')),
      );
      return;
    }

    await _alertService.setPanicWord(newPanicWord);
    await _prefs.setDouble('voiceSensitivity', _voiceSensitivity);
    
    setState(() {
      _panicWord = newPanicWord;
    });

    // Notify the background service about the change
    FlutterBackgroundService().invoke('updatePanicWord');

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Panic word settings saved')),
      );
    }
  }

  void _showAddContactDialog() {
    _phoneController.clear();
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Add Emergency Contact',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 20),
              TextField(
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
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
            ],
          ),
        ),
      ),
    );
  }

  void _showPanicWordDialog() {
    _panicWordController.text = _panicWord;
    double tempSensitivity = _voiceSensitivity;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Voice Panic Settings',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _panicWordController,
                      decoration: InputDecoration(
                        labelText: 'Panic Word',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Voice Sensitivity: ${(tempSensitivity * 100).toStringAsFixed(0)}%',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Slider(
                      value: tempSensitivity,
                      onChanged: (value) {
                        setDialogState(() => tempSensitivity = value);
                      },
                      min: 0.5,
                      max: 1.0,
                      divisions: 10,
                      label: '${(tempSensitivity * 100).toStringAsFixed(0)}%',
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            _voiceSensitivity = tempSensitivity;
                            _savePanicWordSettings();
                          },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SafePath Campus'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Alert Status Card
              if (_isAlertActive)
                Card(
                  color: AppTheme.lightGray,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: AppTheme.warningRed, width: 2),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_rounded,
                              color: AppTheme.warningRed,
                              size: 28,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'EMERGENCY ALERT ACTIVE',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: AppTheme.warningRed,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Notifications sent to ${_emergencyContacts.length} contact(s)',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _cancelAlert,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.warningRed,
                          ),
                          child: const Text('Cancel Alert'),
                        ),
                      ],
                    ),
                  ),
                ),
              
              if (_countdownSeconds > 0)
                Card(
                  color: AppTheme.lightPurple,
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Emergency Alert in',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '$_countdownSeconds',
                          style: Theme.of(context).textTheme.displayLarge?.copyWith(
                            color: AppTheme.primaryPurple,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ElevatedButton(
                          onPressed: _cancelAlert,
                          child: const Text('Cancel'),
                        ),
                      ],
                    ),
                  ),
                ),
              
              const SizedBox(height: 24),
              
              // Emergency Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _onEmergencyButtonPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningRed,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Column(
                    children: [
                      const Icon(Icons.emergency, size: 36),
                      const SizedBox(height: 8),
                      Text(
                        'EMERGENCY ALERT',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Emergency Contacts Section
              Text(
                'Emergency Contacts',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              
              if (_emergencyContacts.isEmpty)
                Card(
                  color: AppTheme.lightPurple,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'No contacts added yet. Add emergency contacts to send alerts.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _emergencyContacts.length,
                  itemBuilder: (context, index) {
                    final contact = _emergencyContacts[index];
                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.person, color: Theme.of(context).colorScheme.primary),
                        title: Text(contact),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete, color: AppTheme.warningRed),
                          onPressed: () => _removeEmergencyContact(contact),
                        ),
                      ),
                    );
                  },
                ),
              
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _showAddContactDialog,
                  child: const Text('+ Add Contact'),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Voice Panic Word Section
              Text(
                'Voice Activation',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              
              Card(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Panic Word',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _panicWord.toUpperCase(),
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  color: AppTheme.primaryPurple,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: Icon(Icons.settings, color: Theme.of(context).colorScheme.primary),
                            onPressed: _showPanicWordDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _toggleVoiceListening,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isListening
                              ? AppTheme.warningRed
                              : AppTheme.primaryPurple,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(_isListening ? Icons.mic : Icons.mic_none),
                              const SizedBox(width: 8),
                              Text(_isListening ? 'LISTENING...' : 'START LISTENING'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Last Recognized: $_lastRecognizedText',
                        style: Theme.of(context).textTheme.bodySmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _panicWordController.dispose();
    _speechToText.stop();
    super.dispose();
  }
}
