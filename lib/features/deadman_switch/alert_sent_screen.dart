import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/trip_model.dart';
import 'deadman_service.dart';

class AlertSentScreen extends StatefulWidget {
  final TripModel trip;
  const AlertSentScreen({super.key, required this.trip});

  @override
  State<AlertSentScreen> createState() => _AlertSentScreenState();
}

class _AlertSentScreenState extends State<AlertSentScreen> {
  bool _isCancelling = false;
  bool _alertCancelled = false;

  void _callEmergencyContact() async {
    final phone = widget.trip.emergencyContactPhone;
    final uri = Uri.parse('tel:$phone');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open phone dialer'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("=== DEADMAN: Call error: $e ===");
    }
  }

  void _sendSmsToContact() async {
    final phone = widget.trip.emergencyContactPhone;
    final locationText = widget.trip.lastKnownLat != null
        ? 'https://www.google.com/maps?q=${widget.trip.lastKnownLat},${widget.trip.lastKnownLng}'
        : 'Location not available';

    final message = 'EMERGENCY ALERT from SafePath Campus!\n\n'
        'Student needs help.\n'
        'Destination: ${widget.trip.destination}\n'
        'Last known location: $locationText\n'
        'Trip started at: ${widget.trip.startTime.hour.toString().padLeft(2, '0')}:${widget.trip.startTime.minute.toString().padLeft(2, '0')}\n'
        'Alert triggered because student did not respond to check-in.\n\n'
        'Please check on them immediately.';

    final uri =
        Uri.parse('sms:$phone?body=${Uri.encodeComponent(message)}');

    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        print("=== DEADMAN: SMS app opened for $phone ===");
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not open SMS app'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      print("=== DEADMAN: SMS error: $e ===");
    }
  }

  void _cancelAlert() async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Alert?"),
        content: const Text(
            "Confirm that you are safe and want to cancel the emergency alert. A cancellation message will be sent to your emergency contact."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("No, Keep Alert"),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              setState(() => _isCancelling = true);

              try {
                await DeadmanService()
                    .updateTripStatus(widget.trip.tripId, 'completed');

                final phone = widget.trip.emergencyContactPhone;
                final cancelMessage =
                    'UPDATE from SafePath Campus:\n\n'
                    'The student has confirmed they are SAFE.\n'
                    'Previous emergency alert for destination "${widget.trip.destination}" has been CANCELLED.\n'
                    'No action needed.';

                final uri = Uri.parse(
                    'sms:$phone?body=${Uri.encodeComponent(cancelMessage)}');
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }

                setState(() {
                  _isCancelling = false;
                  _alertCancelled = true;
                });

                print("=== DEADMAN: Alert cancelled successfully ===");
              } catch (e) {
                print("=== DEADMAN: Cancel alert error: $e ===");
                if (mounted) {
                  setState(() => _isCancelling = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style:
                ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text("Yes, I'm Safe"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor =
        _alertCancelled ? Colors.green.shade900 : Colors.red.shade900;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: bgColor,
        child: _alertCancelled ? _buildCancelledView() : _buildAlertView(),
      ),
    );
  }

  Widget _buildAlertView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Alert icon
            const Icon(Icons.warning_amber_rounded,
                size: 100, color: Colors.white),

            const SizedBox(height: 24),

            // Main text
            const Text(
              'ALERT SENT',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            // Description
            const Text(
              'An emergency alert has been sent to your contact with your last known location.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 32),

            // Contact info card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alert sent to:',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text(
                    widget.trip.emergencyContactName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.trip.emergencyContactPhone,
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white70),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white30),
                  const SizedBox(height: 12),
                  const Text('Your location:',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 4),
                  if (widget.trip.lastKnownLat != null) ...[
                    Text(
                      'Lat: ${widget.trip.lastKnownLat!.toStringAsFixed(6)}',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white),
                    ),
                    Text(
                      'Lng: ${widget.trip.lastKnownLng!.toStringAsFixed(6)}',
                      style: const TextStyle(
                          fontSize: 14, color: Colors.white),
                    ),
                  ] else
                    const Text(
                      'Location not available',
                      style: TextStyle(
                          fontSize: 14, color: Colors.white70),
                    ),
                  const SizedBox(height: 12),
                  const Divider(color: Colors.white30),
                  const SizedBox(height: 12),
                  const Text('Destination:',
                      style: TextStyle(
                          fontSize: 12, color: Colors.white60)),
                  const SizedBox(height: 4),
                  Text(
                    widget.trip.destination,
                    style: const TextStyle(
                        fontSize: 16, color: Colors.white),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Call Emergency Contact button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.phone),
                label: Text(
                    'Call ${widget.trip.emergencyContactName}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.red.shade900,
                ),
                onPressed: _callEmergencyContact,
              ),
            ),

            const SizedBox(height: 12),

            // Cancel Alert button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                icon: _isCancelling
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cancel),
                label: Text(
                    _isCancelling ? 'Cancelling...' : "I'm Safe - Cancel Alert"),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.white),
                  foregroundColor: Colors.white,
                ),
                onPressed: _isCancelling ? null : _cancelAlert,
              ),
            ),

            const SizedBox(height: 12),

            // Resend SMS button
            TextButton.icon(
              icon: const Icon(Icons.sms, color: Colors.white70),
              label: const Text('Resend SMS to contact',
                  style: TextStyle(color: Colors.white70)),
              onPressed: _sendSmsToContact,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledView() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.check_circle, size: 100, color: Colors.white),
            const SizedBox(height: 24),
            const Text(
              'ALERT CANCELLED',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'You have confirmed you are safe. Your emergency contact has been notified that the alert is cancelled.',
              style: TextStyle(fontSize: 16, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.green.shade900,
                ),
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Return to Home',
                    style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
