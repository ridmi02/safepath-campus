import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_vibrate/flutter_vibrate.dart';
import 'package:safepath_campus/services/app_theme.dart';
import 'package:safepath_campus/services/location_service.dart';

class VoiceActivationPage extends StatefulWidget {
  const VoiceActivationPage({super.key});

  @override
  State<VoiceActivationPage> createState() => _VoiceActivationPageState();
}

class _VoiceActivationPageState extends State<VoiceActivationPage>
    with TickerProviderStateMixin {
  // Speech Recognition
  final SpeechToText _speech = SpeechToText();
  bool _speechEnabled = false;
  bool _isListening = false;
  double _confidenceLevel = 0.0;
  String _lastWords = '';
  List<double> _audioBars = List.filled(5, 10.0);

  // Settings
  double _sensitivity = 0.5; // Threshold for confidence
  bool _isDiscreetMode = false;
  final TextEditingController _triggerWordController = TextEditingController(text: 'help');

  // Advanced Settings
  bool _hapticEnabled = true;
  bool _voiceFeedback = false;
  bool _recordAudio = true;

  // Alert State
  bool _isTriggered = false;
  int _countdown = 5;
  Timer? _countdownTimer;

  // Animation
  late AnimationController _rippleController;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _initAnimation();
  }

  void _initAnimation() {
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  void _initSpeech() async {
    // Request microphone permission specifically
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is required')),
        );
      }
      return;
    }

    _speechEnabled = await _speech.initialize(
      onError: (e) => debugPrint('Speech Error: $e'),
      onStatus: (s) => debugPrint('Speech Status: $s'),
    );
    
    if (mounted) setState(() {});
  }

  void _startListening() async {
    if (!_speechEnabled) {
      _initSpeech();
      return;
    }

    // Feedback for starting
    if (_hapticEnabled && await Vibrate.canVibrate) {
      Vibrate.feedback(FeedbackType.medium);
    }

    if (!mounted) return;
    setState(() => _isListening = true);
    
    await _speech.listen(
      onResult: _onSpeechResult,
      onSoundLevelChange: (level) {
        if (mounted) {
          setState(() {
            // Simulate frequency bars based on volume level
            _audioBars = List.generate(5, (i) => 10.0 + (math.max(0, level) * (math.Random().nextDouble() + 0.5) * 5));
          });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 5),
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      ),
    );
  }

  void _stopListening() async {
    if (_hapticEnabled && await Vibrate.canVibrate) {
      Vibrate.feedback(FeedbackType.light);
    }
    await _speech.stop();
    if (!mounted) return;
    setState(() { 
      _isListening = false;
      _audioBars = List.filled(5, 10.0);
    });
  }

  void _onSpeechResult(result) {
    if (!mounted) return;
    setState(() {
      _lastWords = result.recognizedWords;
      if (result.hasConfidenceRating && result.confidence > 0) {
        _confidenceLevel = result.confidence;
      }
    });

    // Trigger logic
    // Note: Confidence check is bypassed if sensitivity is set to 0 (max sensitivity)
    // or if the platform doesn't return confidence (often returns 0.0 for partials).
    bool confidenceMet = _sensitivity == 0 || _confidenceLevel >= _sensitivity;
    
    final triggerWord = _triggerWordController.text.trim().toLowerCase();
    
    if (triggerWord.isNotEmpty && 
        _lastWords.toLowerCase().contains(triggerWord) && 
        confidenceMet && 
        !_isTriggered) {
      _triggerEmergencyProtocol();
    }
  }

  void _triggerEmergencyProtocol() async {
    _stopListening();
    
    if (await Vibrate.canVibrate) {
      Vibrate.vibrate(); // Heavy vibration
    }

    if (!mounted) return;
    setState(() {
      _isTriggered = true;
      _countdown = 5;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown == 0) {
        _sendSOS();
        timer.cancel();
      } else if (!mounted) {
        timer.cancel();
      } else {
        setState(() => _countdown--);
      }
    });
  }

  void _cancelEmergency() {
    _countdownTimer?.cancel();
    setState(() {
      _isTriggered = false;
      _lastWords = '';
      _countdown = 5;
    });
  }

  void _sendSOS() async {
    // Get Location
    final locationService = LocationService();
    await locationService.init();
    final loc = locationService.currentLocation;
    await locationService.dispose();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppTheme.warningRed,
          content: Text('SOS SENT @ ${loc?.latitude ?? "?"}, ${loc?.longitude ?? "?"}'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
    // Reset after sending
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) _cancelEmergency();
    });
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _triggerWordController.dispose();
    _countdownTimer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If Discreet Mode is active, show minimal dark UI
    if (_isDiscreetMode) {
      return _buildDiscreetUI();
    }

    // If Triggered, show Emergency Countdown
    if (_isTriggered) {
      return _buildEmergencyCountdown();
    }

    return Scaffold(
      backgroundColor: AppTheme.lightGray,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(CupertinoIcons.back, color: AppTheme.textDark),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // Animated Background Gradient Decoration
          AnimatedPositioned(
            duration: const Duration(milliseconds: 500),
            top: _isListening ? -50 : -100,
            right: _isListening ? -50 : -100,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: _isListening ? 400 : 300,
              height: _isListening ? 400 : 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (_isListening ? const Color(0xFF0D47A1) : const Color(0xFF90CAF9)).withValues(alpha: 0.4),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? const Color(0xFF0D47A1) : const Color(0xFF90CAF9)).withValues(alpha: 0.3),
                    blurRadius: 100,
                    spreadRadius: 20,
                  )
                ],
              ),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        children: [
                          // 1. Header Section
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10),
                            child: Column(
                              children: [
                                Text(
                                  "Voice Guardian",
                                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0D47A1),
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _isListening
                                        ? const Color(0xFF0D47A1).withValues(alpha: 0.1)
                                        : AppTheme.mediumGray.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      _isListening 
                                        ? _buildPulsingDot()
                                        : const Icon(CupertinoIcons.mic_off, size: 14, color: AppTheme.textLight),
                                      const SizedBox(width: 8),
                                      Text(
                                        _isListening ? "ACTIVE MONITORING" : "MONITORING PAUSED",
                                        style: TextStyle(
                                          color: _isListening ? const Color(0xFF0D47A1) : AppTheme.textLight,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const Spacer(),

                          // 2. Main Visualization (The Orb)
                          _buildVoiceVisualizer(),

                          const Spacer(),

                          // 3. Recognized Text Display
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Text(
                                _lastWords.isEmpty
                                    ? "Say \"${_triggerWordController.text.toUpperCase()}\" to trigger emergency"
                                    : "\"$_lastWords\"",
                                key: ValueKey(_lastWords),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: _lastWords.isEmpty ? 16 : 22,
                                  fontWeight: _lastWords.isEmpty ? FontWeight.normal : FontWeight.w600,
                                  fontStyle: _lastWords.isEmpty ? FontStyle.normal : FontStyle.italic,
                                  color: _lastWords.isEmpty ? AppTheme.textLight : AppTheme.textDark,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 40),

                          // 4. Control Panel
                          _buildControlPanel(context),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPulsingDot() {
    return AnimatedBuilder(
      animation: _rippleController,
      builder: (context, child) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: const Color(0xFF0D47A1).withValues(alpha: _rippleController.value),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  Widget _buildVoiceVisualizer() {
    return GestureDetector(
      onTap: _isListening ? _stopListening : _startListening,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main Microphone Button
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: _isListening ? 100 : 120,
            height: _isListening ? 100 : 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: _isListening
                    ? [const Color(0xFF0D47A1), const Color(0xFF002171)]
                    : [Colors.white, Colors.grey.shade100],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isListening ? const Color(0xFF0D47A1) : Colors.black).withValues(alpha: 0.2),
                  blurRadius: _isListening ? 30 : 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Icon(
              _isListening ? CupertinoIcons.mic_fill : CupertinoIcons.mic,
              color: _isListening ? Colors.white : const Color(0xFF0D47A1),
              size: _isListening ? 40 : 50,
            ),
          ),
          const SizedBox(height: 30),
          // Audio Frequency Bars
          SizedBox(
            height: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: _audioBars.map((height) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: 6,
                  height: _isListening ? height.clamp(5.0, 40.0) : 5.0,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D47A1).withValues(alpha: 0.7),
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

  Widget _buildControlPanel(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(CupertinoIcons.settings, size: 20, color: AppTheme.textLight),
              const SizedBox(width: 8),
              Text("SETTINGS", style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),
            ],
          ),
          const SizedBox(height: 20),
          
          // Safe Word Input
          TextField(
            controller: _triggerWordController,
            decoration: const InputDecoration(
              labelText: "Safe Word",
              prefixIcon: Icon(Icons.record_voice_over, size: 20, color: Color(0xFF0D47A1)),
              helperText: "The word that triggers the alarm",
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 20),

          // Sensitivity Slider
          Row(
            children: [
              const Text("Sensitivity", style: TextStyle(fontWeight: FontWeight.w500)),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: const Color(0xFF0D47A1),
                    inactiveTrackColor: const Color(0xFF90CAF9),
                    thumbColor: const Color(0xFF0D47A1),
                    overlayColor: const Color(0xFF0D47A1).withValues(alpha: 0.2),
                  ),
                  child: Slider(
                    value: _sensitivity,
                    min: 0.1,
                    max: 0.9,
                    onChanged: (val) => setState(() => _sensitivity = val),
                  ),
                ),
              ),
              Text("${(_sensitivity * 100).toInt()}%", style: const TextStyle(color: AppTheme.textLight)),
            ],
          ),
          
          const Divider(height: 32),
          
          // Toggles Section
          Text("FEEDBACK & ACTIONS", style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 1.5)),
          const SizedBox(height: 12),
          
          _buildSwitchTile(
            "Haptic Feedback", 
            "Vibrate on activation", 
            CupertinoIcons.waveform, 
            _hapticEnabled, 
            (v) => setState(() => _hapticEnabled = v)
          ),
          
          _buildSwitchTile(
            "Voice Feedback", 
            "Spoken confirmation", 
            CupertinoIcons.speaker_2_fill, 
            _voiceFeedback, 
            (v) => setState(() => _voiceFeedback = v)
          ),
          
          _buildSwitchTile(
            "Record Evidence", 
            "Audio during SOS", 
            CupertinoIcons.mic_circle, 
            _recordAudio, 
            (v) => setState(() => _recordAudio = v)
          ),
          
          // Discreet Mode Toggle
          Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightGray,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle),
                  child: const Icon(CupertinoIcons.eye_slash_fill, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Stealth Mode", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text("Black screen & haptics only", style: TextStyle(fontSize: 12, color: AppTheme.textLight)),
                    ],
                  ),
                ),
                Switch(
                  value: _isDiscreetMode,
                  activeTrackColor: const Color(0xFF0D47A1),
                  thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.white;
                    }
                    return Colors.grey;
                  }),
                  trackColor: _isDiscreetMode ? WidgetStateProperty.all(const Color(0xFF0D47A1).withValues(alpha: 0.5)) : null,
                  onChanged: (val) => setState(() => _isDiscreetMode = val),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSwitchTile(String title, String subtitle, IconData icon, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: value ? const Color(0xFF0D47A1) : AppTheme.textLight),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppTheme.textLight)),
              ],
            ),
          ),
          Switch(
            value: value,
            activeTrackColor: const Color(0xFF0D47A1),
            thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.white;
              }
              return Colors.grey;
            }),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildEmergencyCountdown() {
    return Scaffold(
      backgroundColor: AppTheme.warningRed,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Animated Countdown
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: CircularProgressIndicator(
                      value: _countdown / 5,
                      strokeWidth: 10,
                      color: Colors.white,
                      backgroundColor: Colors.white.withValues(alpha: 0.3),
                    ),
                  ),
                  Text(
                    "$_countdown",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 80,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              
              const Text(
                "EMERGENCY TRIGGERED",
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                )
              ),
              const SizedBox(height: 10),
              const Text(
                "Sending SOS to Campus Security...", 
                style: TextStyle(color: Colors.white70, fontSize: 16)
              ),
              
              const SizedBox(height: 60),
              
              // Cancel Button
              SizedBox(
                width: 200,
                height: 60,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppTheme.warningRed,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  onPressed: _cancelEmergency,
                  child: const Text(
                    "I'M SAFE", 
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDiscreetUI() {
    return GestureDetector(
      onTap: () {
        // Double tap to exit logic could be implemented here
        setState(() => _isDiscreetMode = false);
      },
      // Long press to start/stop listening without looking
      onLongPress: _isListening ? _stopListening : _startListening,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mimic a simple Digital Clock or completely black
              // A very dim red dot indicating recording
              if (_isListening)
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                ),
              const SizedBox(height: 20),
               Text(
                "12:00", // Fake clock to make it look like lockscreen
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.1),
                  fontSize: 48,
                  fontWeight: FontWeight.w300
                ),
              ),
              const SizedBox(height: 10),
              Text(
                "Tap to wake", 
                style: TextStyle(color: Colors.white.withValues(alpha: 0.05), fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    );
  }
}