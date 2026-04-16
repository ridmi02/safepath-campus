import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'emergency_alarm_service.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

class VoiceActivationPage extends StatefulWidget {
  const VoiceActivationPage({super.key});

  @override
  State<VoiceActivationPage> createState() => _VoiceActivationPageState();
}

class _VoiceActivationPageState extends State<VoiceActivationPage> with TickerProviderStateMixin {
  final EmergencyAlertService _alertService = EmergencyAlertService();
  final TextEditingController _panicWordController = TextEditingController();
  final TextEditingController _sosMessageController = TextEditingController();
  bool _isLoading = true;
  bool _isVoiceGuardianEnabled = true;
  double _sensitivity = 0.5;
  bool _isTestMode = false;
  bool _hapticEnabled = true;
  bool _voiceFeedback = false;
  bool _recordAudio = true;
  bool _isDiscreetMode = false;
  final List<String> _speechHistory = [];
  
  // Speech recognition state
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  String _lastWords = '';
  List<double> _audioBars = List.filled(5, 10.0);
  late AnimationController _rippleController;
  bool _isTriggered = false;
  int _countdown = 5;
  Timer? _countdownTimer;
  double _micButtonScale = 1.0;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _initSpeech();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  Future<void> _initSpeech() async {
    bool available = await _speech.initialize(
      onError: (val) => debugPrint('Speech Error: $val'),
      onStatus: (val) {
        if (mounted) setState(() => _isListening = _speech.isListening);
      },
    );
    if (mounted) {
      setState(() => _speechEnabled = available);
    }
  }

  Future<void> _loadSettings() async {
    final word = await _alertService.getPanicWord();
    final enabled = await _alertService.isVoiceGuardianEnabled();
    final sensitivity = await _alertService.getSensitivity();
    final haptic = await _alertService.getHapticFeedbackEnabled();
    final voiceFeedback = await _alertService.getVoiceFeedbackEnabled();
    final recordAudio = await _alertService.getRecordAudioEnabled();
    final discreetMode = await _alertService.getDiscreetModeEnabled();
    final customMsg = await _alertService.getCustomSosMessage();
    final countdown = await _alertService.getSosCountdown();
    
    if (mounted) {
      setState(() {
        _panicWordController.text = word ?? '';
        _isVoiceGuardianEnabled = enabled;
        _sensitivity = sensitivity;
        _hapticEnabled = haptic;
        _voiceFeedback = voiceFeedback;
        _recordAudio = recordAudio;
        _isDiscreetMode = discreetMode;
        _sosMessageController.text = customMsg;
        _countdown = countdown;
        _isLoading = false;
      });
    }
  }

  void _toggleListening() async {
    if (!_speechEnabled) {
      await _initSpeech();
      if (!_speechEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Speech recognition is not available on this device.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
    }

    if (_isListening) {
      await _speech.stop();
    } else {
      final status = await Permission.microphone.request();
      if (status.isGranted) {
        setState(() => _lastWords = '');
        await _speech.listen(
          onResult: (result) {
            if (mounted) {
              setState(() {
                _lastWords = result.recognizedWords;
                if (result.finalResult) {
                  final timestamp = DateTime.now();
                  final timeStr = "${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}";
                  
                  // Check if this was a trigger word
                  final isTrigger = _panicWordController.text.split(',').any((w) => 
                    result.recognizedWords.toLowerCase().contains(w.trim().toLowerCase()));
                  
                  _speechHistory.insert(0, "$timeStr | ${isTrigger ? '⚠️' : '🎤'} ${result.recognizedWords}");
                  if (_speechHistory.length > 3) _speechHistory.removeLast();
                }
              });
            }
            final triggerWords = _panicWordController.text
                .split(',')
                .map((e) => e.trim().toLowerCase())
                .where((w) => w.isNotEmpty);
            if (triggerWords
                .any((w) => result.recognizedWords.toLowerCase().contains(w))) {
              _triggerEmergencyProtocol();
            }
          },
          onSoundLevelChange: (level) {
            if (mounted) {
              setState(() {
                _audioBars = List.generate(
                    5,
                    (i) => 10.0 + (math.max(0, level) * (math.Random().nextDouble() + 0.5) * 5));
              });
            }
          },
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission is required to listen.')),
          );
        }
      }
    }
  }

  void _triggerEmergencyProtocol() async {
    _speech.stop();
    final startValue = await _alertService.getSosCountdown();
    setState(() {
      _isTriggered = true;
      _countdown = startValue;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        _alertService.activateEmergency();
        timer.cancel();
      } else {
        if (mounted) setState(() => _countdown--);
      }
    });
  }

  void _cancelEmergency() async {
    _countdownTimer?.cancel();
    final originalCountdown = await _alertService.getSosCountdown();
    setState(() {
      _isTriggered = false;
      _countdown = originalCountdown;
    });
  }

  Future<void> _saveSettings() async {
    final word = _panicWordController.text.trim();
    if (word.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a panic word')),
      );
      return;
    }

    // Save all values to persistent storage
    await _alertService.setPanicWord(word);
    await _alertService.setVoiceGuardianEnabled(_isVoiceGuardianEnabled);
    await _alertService.setSensitivity(_sensitivity);
    await _alertService.setHapticFeedbackEnabled(_hapticEnabled);
    await _alertService.setVoiceFeedbackEnabled(_voiceFeedback);
    await _alertService.setRecordAudioEnabled(_recordAudio);
    await _alertService.setDiscreetModeEnabled(_isDiscreetMode);
    await _alertService.setCustomSosMessage(_sosMessageController.text.trim());
    await _alertService.setSosCountdown(_countdown);
    
    // Notify background service to refresh its listeners
    FlutterBackgroundService().invoke('updateSettings');

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Voice Activation settings saved')),
      );
    }
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _panicWordController.dispose();
    _sosMessageController.dispose();
    _countdownTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    return Stack(
      children: [
        Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: const Text('Voice Activation',
                style: TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: colorScheme.primaryContainer,
            foregroundColor: colorScheme.onPrimaryContainer,
            elevation: 0,
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderSection(),
                      const SizedBox(height: 16),
                      _buildInstructionCard(primaryColor),
                      const SizedBox(height: 32),
                      _buildVisualizerSection(),
                      const SizedBox(height: 32),
                      _buildTranscriptSection(),
                      const SizedBox(height: 24),
                      _buildMessageSection(),
                      const SizedBox(height: 24),
                      _buildRecentActivitySection(primaryColor),
                      const SizedBox(height: 32),
                      _buildSettingsSection(context),
                      const SizedBox(height: 40),
                      ElevatedButton(
                        onPressed: _saveSettings,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          minimumSize: const Size(double.infinity, 54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Save Settings',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
        ),
        if (_isTriggered) _buildEmergencyCountdown(),
      ],
    );
  }

  Widget _buildRecentActivitySection(Color primaryColor) {
    if (_speechHistory.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Recent Activity',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: primaryColor.withValues(alpha: 0.03),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: primaryColor.withValues(alpha: 0.1)),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _speechHistory.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: primaryColor.withValues(alpha: 0.1),
            ),
            itemBuilder: (context, index) {
              return ListTile(
                dense: true,
                leading: Icon(Icons.history, size: 16, color: primaryColor),
                title: Text(
                  _speechHistory[index],
                  style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionCard(Color primaryColor) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: primaryColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: primaryColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Set trigger words (comma separated). SafePath will listen and trigger SOS if any match.',
                style: TextStyle(fontSize: 13, color: colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Voice Guardian',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: primaryColor),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _isListening ? Colors.green.withValues(alpha: 0.1) : colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _isListening ? '● Actively Listening' : '○ Monitoring Paused',
                style: TextStyle(
                    color: _isListening ? Colors.green : colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        Switch(
          value: _isVoiceGuardianEnabled,
          onChanged: (value) => setState(() => _isVoiceGuardianEnabled = value),
          activeThumbColor: primaryColor,
        ),
      ],
    );
  }

  Widget _buildVisualizerSection() {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              if (_isListening)
                AnimatedBuilder(
                  animation: _rippleController,
                  builder: (context, child) {
                    return Container(
                      width: 120 + (40 * _rippleController.value),
                      height: 120 + (40 * _rippleController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: primaryColor
                            .withValues(alpha: 0.3 * (1 - _rippleController.value)),
                      ),
                    );
                  },
                ),
              GestureDetector(
                onTapDown: (_) => setState(() => _micButtonScale = 0.9),
                onTapUp: (_) => setState(() => _micButtonScale = 1.0),
                onTapCancel: () => setState(() => _micButtonScale = 1.0),
                onTap: _toggleListening,
                child: AnimatedScale(
                  scale: _isListening ? 1.15 : _micButtonScale,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isListening ? Theme.of(context).colorScheme.error : primaryColor,
                      boxShadow: [
                        BoxShadow(
                            color: (_isListening ? Theme.of(context).colorScheme.error : primaryColor)
                                .withValues(alpha: 0.4),
                            blurRadius: 20,
                            spreadRadius: 5)
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      color: _isListening ? Theme.of(context).colorScheme.onError : Colors.white,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: _audioBars.map((height) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: 8,
                  height: _isListening ? height : 4,
                  decoration: BoxDecoration(
                    color: primaryColor.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Panic Word Trigger',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _panicWordController,
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            hintText: 'e.g. Help, Emergency, Save me',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        if (_lastWords.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colorScheme.primary.withValues(alpha: 0.2))),
              child: Text('Recognized: "$_lastWords"',
                  style: TextStyle(
                      fontStyle: FontStyle.italic, color: colorScheme.onSurface)),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Custom SOS Message',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        TextField(
          controller: _sosMessageController,
          maxLines: 2,
          decoration: InputDecoration(
            filled: true,
            fillColor: colorScheme.surfaceContainerLow,
            hintText: 'Enter custom text to send in SMS...',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
        const SizedBox(height: 4),
        Text('Location link will be added automatically.',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primaryColor = colorScheme.primary;
    return Card(
      color: colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Text("Sensitivity",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _sensitivity,
                    onChanged: (value) => setState(() => _sensitivity = value),
                    activeColor: primaryColor,
                    inactiveColor: primaryColor.withValues(alpha: 0.2),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                const Text("Security Delay",
                    style: TextStyle(fontWeight: FontWeight.w600)),
                Expanded(
                  child: Slider(
                    value: _countdown.toDouble(),
                    min: 0,
                    max: 10,
                    divisions: 10,
                    label: "$_countdown s",
                    onChanged: (value) =>
                        setState(() => _countdown = value.toInt()),
                    activeColor: primaryColor,
                    inactiveColor: primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                Text("$_countdown s", style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
            const Divider(),
            _buildSwitchTile("Test Mode (No SOS)", _isTestMode,
                (v) => setState(() => _isTestMode = v)),
            _buildSwitchTile("Haptic Feedback", _hapticEnabled,
                (v) => setState(() => _hapticEnabled = v)),
            _buildSwitchTile("Voice Confirmation", _voiceFeedback,
                (v) => setState(() => _voiceFeedback = v)),
            _buildSwitchTile("Record Evidence", _recordAudio,
                (v) => setState(() => _recordAudio = v)),
            _buildSwitchTile("Discreet Listening", _isDiscreetMode,
                (v) => setState(() => _isDiscreetMode = v)),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String title, bool value, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: Theme.of(context).colorScheme.primary,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildEmergencyCountdown() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.error.withValues(alpha: 0.9),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("EMERGENCY TRIGGERED",
                style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text("$_countdown",
                style: TextStyle(
                    color: colorScheme.onError,
                    fontSize: 80,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: _cancelEmergency,
              style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.onError, foregroundColor: colorScheme.error),
              child: const Text("CANCEL ALERT"),
            ),
          ],
        ),
      ),
    );
  }
}