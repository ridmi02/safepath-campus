import 'package:flutter/material.dart';
import 'package:safepath_campus/features/fake_call/fake_ringing_page.dart';

class FakeCallPage extends StatefulWidget {
  const FakeCallPage({super.key});

  @override
  State<FakeCallPage> createState() => _FakeCallPageState();
}

class _FakeCallPageState extends State<FakeCallPage> {
  final TextEditingController _nameController =
      TextEditingController(text: 'Best Friend');
  final TextEditingController _noteController = TextEditingController(
    text: 'Hey, where are you? I am waiting outside.',
  );

  String _selectedScenario = 'Friend Check-in';
  String _selectedRingtone = 'Classic';
  int _delayMinutes = 1;
  bool _vibrate = true;
  bool _flash = false;
  bool _speaker = false;

  final List<String> _scenarios = const [
    'Friend Check-in',
    'Family Urgent',
    'Office Follow-up',
    'Custom',
  ];

  final List<String> _ringtones = const [
    'Classic',
    'Soft Bell',
    'Digital',
    'Retro',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _openRingingScreen() {
    final caller = _nameController.text.trim().isEmpty
        ? 'Unknown Caller'
        : _nameController.text.trim();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FakeRingingPage(
          callerName: caller,
          scenario: _selectedScenario,
          note: _noteController.text.trim(),
          ringtone: _selectedRingtone,
        ),
      ),
    );
  }

  void _showPreview() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Incoming call preview',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(Icons.phone_in_talk, color: theme.colorScheme.primary),
                ),
                title: Text(_nameController.text.trim().isEmpty
                    ? 'Unknown Caller'
                    : _nameController.text.trim()),
                subtitle: Text('Scenario: $_selectedScenario'),
                trailing: const Text('Incoming'),
              ),
              const SizedBox(height: 8),
              Text(
                _noteController.text.trim().isEmpty
                    ? 'No custom note'
                    : _noteController.text.trim(),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _openRingingScreen();
                  },
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Open Ringing Screen'),
                ),
              ),
              const SizedBox(height: 4),
            ],
          ),
        );
      },
    );
  }

  void _scheduleFakeCall() {
    final caller = _nameController.text.trim().isEmpty
        ? 'Unknown Caller'
        : _nameController.text.trim();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Fake call from $caller set for $_delayMinutes min'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake Call'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(
                colors: [
                  theme.colorScheme.primary.withAlpha((0.95 * 255).round()),
                  theme.colorScheme.secondary.withAlpha((0.9 * 255).round()),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: theme.colorScheme.primary.withAlpha((0.25 * 255).round()),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: _openRingingScreen,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: Colors.white24,
                        child: Icon(Icons.ring_volume, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Quick Launch Ringing Screen',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Caller Profile',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Caller Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedRingtone,
                    decoration: const InputDecoration(
                      labelText: 'Ringtone',
                      prefixIcon: Icon(Icons.music_note),
                    ),
                    items: _ringtones
                        .map((tone) => DropdownMenuItem(value: tone, child: Text(tone)))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _selectedRingtone = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Call Scenario',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _scenarios.map((item) {
                      return ChoiceChip(
                        label: Text(item),
                        selected: _selectedScenario == item,
                        onSelected: (_) => setState(() => _selectedScenario = item),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Voice Script / Note',
                      hintText: 'What the fake caller should say',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Schedule: $_delayMinutes minute${_delayMinutes == 1 ? '' : 's'}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Slider(
                    min: 1,
                    max: 30,
                    value: _delayMinutes.toDouble(), // Note: value is still correct for Slider
                    divisions: 29,
                    label: '$_delayMinutes min',
                    onChanged: (value) =>
                        setState(() => _delayMinutes = value.round()),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Vibrate'),
                    value: _vibrate,
                    onChanged: (value) => setState(() => _vibrate = value),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Flash alert'),
                    value: _flash,
                    onChanged: (value) => setState(() => _flash = value),
                  ),
                  SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Auto speaker mode'),
                    value: _speaker,
                    onChanged: (value) => setState(() => _speaker = value),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showPreview,
                  icon: const Icon(Icons.visibility),
                  label: const Text('Preview'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _scheduleFakeCall,
                  icon: const Icon(Icons.alarm),
                  label: const Text('Set Fake Call'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
