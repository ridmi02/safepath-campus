import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/emergency_alarm_service.dart';
import '../services/app_theme.dart';

class VoiceActivationScreen extends StatefulWidget {
  const VoiceActivationScreen({super.key});

  @override
  State<VoiceActivationScreen> createState() => _VoiceActivationScreenState();
}

class _VoiceActivationScreenState extends State<VoiceActivationScreen> {
  final EmergencyAlertService _alertService = EmergencyAlertService();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  
  late SharedPreferences _prefs;
  bool _isListening = false;
  String _lastRecognizedText = '';
  String _panicWord = 'help';
  double _voiceSensitivity = 0.8;
  
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
    _panicWordController.text = _panicWord;
    if (mounted) setState(() {});
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
    return recognizedText.contains(_panicWord.toLowerCase());
  }

  Future<void> _triggerEmergencyAlert() async {
    await _alertService.activateEmergency();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Panic Word Detected! Alert Sent.'),
          backgroundColor: AppTheme.warningRed,
        ),
      );
    }
  }

  void _savePanicWordSettings() async {
    final newPanicWord = _panicWordController.text.trim();
    if (newPanicWord.isEmpty) return;

    await _alertService.setPanicWord(newPanicWord);
    await _prefs.setDouble('voiceSensitivity', _voiceSensitivity);
    
    setState(() => _panicWord = newPanicWord);
    FlutterBackgroundService().invoke('updatePanicWord');

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
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
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Voice Settings', style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _panicWordController,
                      decoration: InputDecoration(labelText: 'Panic Word', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                    ),
                    const SizedBox(height: 20),
                    Text('Sensitivity: ${(tempSensitivity * 100).toStringAsFixed(0)}%'),
                    Slider(
                      value: tempSensitivity,
                      onChanged: (value) => setDialogState(() => tempSensitivity = value),
                      min: 0.5, max: 1.0, divisions: 10,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        _voiceSensitivity = tempSensitivity;
                        _savePanicWordSettings();
                      },
                      child: const Text('Save'),
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
      appBar: AppBar(title: const Text('Voice Activation')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.record_voice_over, size: 48, color: AppTheme.primaryPurple),
                    const SizedBox(height: 16),
                    Text('Current Panic Word: "$_panicWord"', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _toggleVoiceListening,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isListening ? AppTheme.warningRed : AppTheme.primaryPurple,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: Text(_isListening ? 'STOP LISTENING' : 'START LISTENING'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text('Last Heard: $_lastRecognizedText', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showPanicWordDialog,
                icon: const Icon(Icons.settings),
                label: const Text('Configure Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}