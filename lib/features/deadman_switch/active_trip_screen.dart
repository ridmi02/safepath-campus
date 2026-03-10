import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vibration/vibration.dart';
import '../../models/trip_model.dart';
import '../../models/sos_log_model.dart';
import 'deadman_service.dart';

class ActiveTripScreen extends StatefulWidget {
  final TripModel trip;
  const ActiveTripScreen({super.key, required this.trip});

  @override
  State<ActiveTripScreen> createState() => _ActiveTripScreenState();
}

class _ActiveTripScreenState extends State<ActiveTripScreen> {
  late TripModel _currentTrip;
  Timer? _countdownTimer;
  Duration _remainingTime = Duration.zero;
  bool _isLoading = false;
  bool _checkInPromptShown = false;
  double? _currentLat;
  double? _currentLng;
  Timer? _locationTimer;

  @override
  void initState() {
    super.initState();
    _currentTrip = widget.trip;
    _startCountdown();
    _startLocationTracking();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _locationTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateRemainingTime();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateRemainingTime();

      // Check if 2 minutes remaining - show check-in prompt
      if (_remainingTime.inSeconds <= 120 &&
          _remainingTime.inSeconds > 0 &&
          !_checkInPromptShown) {
        _checkInPromptShown = true;
        _showCheckInPrompt();
      }

      // Check if time is up
      if (_remainingTime.inSeconds <= 0) {
        timer.cancel();
        _triggerAlert();
      }
    });
  }

  void _updateRemainingTime() {
    final now = DateTime.now();
    final difference = _currentTrip.expectedArrivalTime.difference(now);
    setState(() {
      _remainingTime = difference.isNegative ? Duration.zero : difference;
    });
  }

  void _startLocationTracking() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        print("=== DEADMAN: Location permission denied ===");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Location permission denied. GPS tracking disabled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Get initial location
      await _updateLocation();

      // Update location every 30 seconds
      _locationTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _updateLocation();
      });
    } catch (e) {
      print("=== DEADMAN: Location error: $e ===");
    }
  }

  Future<void> _updateLocation() async {
    try {
      // geolocator 9.x API uses desiredAccuracy parameter
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLat = position.latitude;
        _currentLng = position.longitude;
      });
      await DeadmanService().updateTripLocation(
        _currentTrip.tripId,
        position.latitude,
        position.longitude,
      );
      print(
          "=== DEADMAN: Location updated: ${position.latitude}, ${position.longitude} ===");
    } catch (e) {
      print("=== DEADMAN: Location update failed: $e ===");
    }
  }

  void _handleImSafe() async {
    setState(() => _isLoading = true);
    try {
      _countdownTimer?.cancel();
      _locationTimer?.cancel();
      await DeadmanService().updateTripStatus(_currentTrip.tripId, 'completed');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip completed safely!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _handleExtendTime() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Extend Time"),
        content: const Text("How many minutes do you need?"),
        actions: [
          TextButton(
            onPressed: () => _extendBy(5, context),
            child: const Text("5 min"),
          ),
          TextButton(
            onPressed: () => _extendBy(10, context),
            child: const Text("10 min"),
          ),
          TextButton(
            onPressed: () => _extendBy(15, context),
            child: const Text("15 min"),
          ),
          TextButton(
            onPressed: () => _extendBy(30, context),
            child: const Text("30 min"),
          ),
        ],
      ),
    );
  }

  void _extendBy(int minutes, BuildContext dialogContext) async {
    Navigator.pop(dialogContext);
    try {
      await DeadmanService().extendTripTime(_currentTrip.tripId, minutes);
      setState(() {
        _currentTrip = _currentTrip.copyWith(
          expectedArrivalTime: _currentTrip.expectedArrivalTime
              .add(Duration(minutes: minutes)),
        );
        _checkInPromptShown = false;
      });
      _updateRemainingTime();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Time extended by $minutes minutes'),
          backgroundColor: Colors.blue,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCheckInPrompt() {
    // Vibrate the phone
    Vibration.vibrate(duration: 1000, amplitude: 255);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          backgroundColor: Colors.orange.shade50,
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded,
                  color: Colors.orange, size: 32),
              SizedBox(width: 8),
              Text("Are You Safe?",
                  style: TextStyle(color: Colors.orange)),
            ],
          ),
          content: const Text(
            "Your timer is about to expire. If you don't respond within 2 minutes, your emergency contact will be alerted with your location.",
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _handleImSafe();
                },
                icon: const Icon(Icons.check_circle),
                label: const Text("I'm Safe",
                    style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _triggerAlert();
                },
                icon: const Icon(Icons.emergency),
                label: const Text("Call for Help",
                    style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _triggerAlert() async {
    _countdownTimer?.cancel();
    _locationTimer?.cancel();

    setState(() => _isLoading = true);

    try {
      await DeadmanService().markAlertSent(_currentTrip.tripId);

      await DeadmanService().createSosLog(SosLogModel(
        logId: '',
        userId: _currentTrip.userId,
        triggerMethod: 'deadman_switch',
        latitude: _currentLat,
        longitude: _currentLng,
        timestamp: DateTime.now(),
        destination: _currentTrip.destination,
        emergencyContactName: _currentTrip.emergencyContactName,
        emergencyContactPhone: _currentTrip.emergencyContactPhone,
        contactNotified: false,
      ));

      print(
          "=== DEADMAN: ALERT TRIGGERED! Location: $_currentLat, $_currentLng ===");

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ALERT SENT to emergency contact!'),
          backgroundColor: Colors.red,
        ),
      );
      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      print("=== DEADMAN: Alert trigger error: $e ===");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error sending alert: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _cancelTrip() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Cancel Trip?"),
        content: const Text(
            "Are you sure you want to cancel this trip? The timer will stop."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("No, Keep Going"),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              _countdownTimer?.cancel();
              _locationTimer?.cancel();
              await DeadmanService()
                  .updateTripStatus(_currentTrip.tripId, 'cancelled');
              if (!mounted) return;
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text("Yes, Cancel",
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timerColor =
        _remainingTime.inSeconds > 120 ? Colors.green : Colors.red;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Active Trip"),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.cancel_outlined),
            onPressed: _cancelTrip,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Destination card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.location_on,
                        color: Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Destination',
                            style: TextStyle(
                                fontSize: 12, color: Colors.grey),
                          ),
                          Text(
                            _currentTrip.destination,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Emergency contact card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.person, color: Colors.blue, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      '${_currentTrip.emergencyContactName} (${_currentTrip.emergencyContactPhone})',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Countdown timer
            Center(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: timerColor, width: 4),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      'TIME LEFT',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_remainingTime.inMinutes.toString().padLeft(2, '0')}:${(_remainingTime.inSeconds % 60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        color: timerColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'remaining',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // GPS status
            Center(
              child: Text(
                _currentLat != null
                    ? 'GPS: ${_currentLat!.toStringAsFixed(4)}, ${_currentLng!.toStringAsFixed(4)}'
                    : 'GPS: Acquiring location...',
                style:
                    const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ),

            const SizedBox(height: 32),

            // I'm Safe button
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle, size: 28),
                label: const Text(
                  "I'm Safe / Arrived",
                  style: TextStyle(fontSize: 20),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isLoading ? null : _handleImSafe,
              ),
            ),

            const SizedBox(height: 12),

            // Extend Time button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.timer_outlined),
                label: const Text("Extend Time"),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.blue),
                  foregroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _handleExtendTime,
              ),
            ),

            const SizedBox(height: 24),

            // Warning text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.red, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Keep this app open. If you don't respond to the check-in prompt, an alert will be sent automatically.",
                      style:
                          TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
