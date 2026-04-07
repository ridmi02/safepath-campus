import 'package:flutter/material.dart';
import '../../models/trip_model.dart';
import '../../services/auth_service.dart';
import 'active_trip_screen.dart';
import 'deadman_service.dart';

class DeadmanSetupScreen extends StatefulWidget {
  const DeadmanSetupScreen({super.key});

  @override
  State<DeadmanSetupScreen> createState() => _DeadmanSetupScreenState();
}

class _DeadmanSetupScreenState extends State<DeadmanSetupScreen> {
  String _selectedDestination = '';
  int _selectedMinutes = 30;
  bool _isCustomTime = false;
  bool _isLoading = false;

  final _contactNameController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _customDestinationController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final List<String> _campusLocations = [
    'SLIIT Main Gate',
    'SLIIT Library',
    'Hostel A',
    'Hostel B',
    'Student Canteen',
    'Lecture Hall Complex',
    'Parking Area',
    'Sports Ground',
    'IT Faculty Building',
    'Other',
  ];

  final List<Map<String, dynamic>> _timePresets = [
    {'label': '15 min', 'minutes': 15},
    {'label': '30 min', 'minutes': 30},
    {'label': '1 hour', 'minutes': 60},
    {'label': 'Custom', 'minutes': -1},
  ];

  @override
  void dispose() {
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    _customDestinationController.dispose();
    super.dispose();
  }

  String _calculateArrivalTime() {
    final arrival = DateTime.now().add(Duration(minutes: _selectedMinutes));
    return '${arrival.hour.toString().padLeft(2, '0')}:${arrival.minute.toString().padLeft(2, '0')}';
  }

  void _handleStartTrip() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = AuthService().getCurrentUser();
      if (user == null) throw "Not logged in";

      final destination = _selectedDestination == 'Other'
          ? _customDestinationController.text.trim()
          : _selectedDestination;

      final trip = TripModel(
        tripId: '',
        userId: user.uid,
        destination: destination,
        startTime: DateTime.now(),
        expectedArrivalTime:
            DateTime.now().add(Duration(minutes: _selectedMinutes)),
        emergencyContactName: _contactNameController.text.trim(),
        emergencyContactPhone: _contactPhoneController.text.trim(),
      );

      final createdTrip = await DeadmanService().createTrip(trip);

      if (!mounted) return;

      debugPrint(
        "=== DEADMAN: Trip started successfully. ID: ${createdTrip.tripId} ===",
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ActiveTripScreen(trip: createdTrip)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Deadman's Switch"),
        leading: BackButton(onPressed: () => Navigator.of(context).pop()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Safety info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.3),
                  ),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.shield, color: Colors.orange, size: 32),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Safety Timer',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Set your destination and time. If you don't check in, your emergency contact will be alerted automatically.",
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Destination section
              const Text(
                'Where are you going?',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                key: ValueKey(_selectedDestination),
                decoration: InputDecoration(
                  labelText: 'Select Destination',
                  prefixIcon: const Icon(Icons.location_on),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                initialValue:
                    _selectedDestination.isEmpty ? null : _selectedDestination,
                items: _campusLocations
                    .map((loc) => DropdownMenuItem(value: loc, child: Text(loc)))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedDestination = value ?? '');
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a destination';
                  }
                  return null;
                },
              ),

              if (_selectedDestination == 'Other') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customDestinationController,
                  decoration: InputDecoration(
                    labelText: 'Enter destination',
                    prefixIcon: const Icon(Icons.edit_location),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  validator: (value) {
                    if (_selectedDestination == 'Other' &&
                        (value == null || value.trim().isEmpty)) {
                      return 'Please enter a destination';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 24),

              // Timer section
              const Text(
                'Expected arrival time',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _timePresets.map((preset) {
                  final isCustom = preset['minutes'] == -1;
                  final isSelected = isCustom
                      ? _isCustomTime
                      : (!_isCustomTime &&
                          _selectedMinutes == preset['minutes']);
                  return ChoiceChip(
                    label: Text(preset['label'] as String),
                    selected: isSelected,
                    selectedColor: Colors.orange,
                    onSelected: (_) {
                      setState(() {
                        if (isCustom) {
                          _isCustomTime = true;
                        } else {
                          _isCustomTime = false;
                          _selectedMinutes = preset['minutes'] as int;
                        }
                      });
                    },
                  );
                }).toList(),
              ),

              if (_isCustomTime) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Slider(
                        min: 5,
                        max: 180,
                        divisions: 35,
                        value: _selectedMinutes.toDouble(),
                        activeColor: Colors.orange,
                        onChanged: (value) {
                          setState(() => _selectedMinutes = value.round());
                        },
                      ),
                    ),
                    Text(
                      '$_selectedMinutes min',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Expected arrival: ${_calculateArrivalTime()}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),

              const SizedBox(height: 24),

              // Emergency contact section
              const Text(
                'Emergency Contact',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'This person will be alerted if you don\'t check in.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _contactNameController,
                decoration: InputDecoration(
                  labelText: 'Contact Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Contact name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _contactPhoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
                  hintText: '+94XXXXXXXXX',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Phone number is required';
                  }
                  if (value.trim().length < 10) {
                    return 'Enter a valid phone number';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 12),

              // Default contact option
              TextButton.icon(
                icon: const Icon(Icons.security),
                label: const Text('Use Campus Security (+94112345678)'),
                onPressed: () {
                  setState(() {
                    _contactNameController.text = 'Campus Security';
                    _contactPhoneController.text = '+94112345678';
                  });
                },
              ),

              const SizedBox(height: 32),

              // Start Trip button
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _handleStartTrip,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.play_arrow),
                            SizedBox(width: 8),
                            Text(
                              'Start Trip',
                              style: TextStyle(fontSize: 18),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              // Warning text
              const Text(
                'Do not close the app while your trip is active.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.red,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
