import 'package:flutter/material.dart';

class CompanionPage extends StatefulWidget {
  const CompanionPage({super.key});

  @override
  State<CompanionPage> createState() => _CompanionPageState();
}

class _CompanionPageState extends State<CompanionPage> {
  final List<String> _companions = const [
    'Alex (Peer Escort)',
    'Jordan (Campus Safety)',
    'Taylor (Resident Advisor)',
  ];

  String? _selectedCompanion;
  bool _requestInProgress = false;
  bool _isOnCall = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _requestCompanion() async {
    if (_selectedCompanion == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please choose a Companion first'),
        ),
      );
      return;
    }

    setState(() {
      _requestInProgress = true;
    });

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;
    setState(() {
      _requestInProgress = false;
      _isOnCall = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Companion connected (demo mode)'),
      ),
    );
  }

  void _endWalk() {
    setState(() {
      _isOnCall = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Walk completed — stay safe!'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('The Companion'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.groups_2,
                          size: 32,
                          color: colorScheme.secondary,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'The Companion',
                          style: theme.textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Request a verified student to stay with you '
                      'on an audio/video call until you reach your door.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'This prototype focuses on the safety flow only. '
                      'In a full release, the call itself would run over '
                      'secure real-time audio/video.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.disabledColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedCompanion,
                    decoration: const InputDecoration(
                      labelText: 'Choose a Companion',
                      border: OutlineInputBorder(),
                    ),
                    items: _companions
                        .map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c),
                          ),
                        )
                        .toList(),
                    onChanged: _isOnCall
                        ? null
                        : (value) {
                            setState(() {
                              _selectedCompanion = value;
                            });
                          },
                  ),
                  const SizedBox(height: 16),
                  if (_isOnCall)
                    Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.6),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.shield_moon,
                                  color: Colors.green),
                              const SizedBox(width: 8),
                              Text(
                                'Walk in progress',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'You are on a call with '
                            '${_selectedCompanion ?? 'your Companion'} '
                            'until you safely reach your door.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    )
                  else
                    Text(
                      'Your Companion will stay on the line, watch for '
                      'anything unusual, and can escalate to campus safety '
                      'if needed.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  const Spacer(),
                  if (_isOnCall)
                    ElevatedButton.icon(
                      onPressed: _endWalk,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: const Icon(Icons.call_end),
                      label: const Text('End Walk'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed:
                          _requestInProgress ? null : _requestCompanion,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      icon: _requestInProgress
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.directions_walk),
                      label: Text(
                        _requestInProgress
                            ? 'Finding a Companion...'
                            : 'Request Virtual Walk-Home',
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

