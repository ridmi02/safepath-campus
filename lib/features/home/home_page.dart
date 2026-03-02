import 'package:flutter/material.dart';
import 'package:safepath_campus/services/firebase_service.dart';

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  void _triggerSOS(BuildContext context) {
    const FirebaseService().logSosActivated();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('SOS Emergency Alert Sent!'),
        backgroundColor: Color(0xFFE63946),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final int scaffoldBgVal =
        Theme.of(context).scaffoldBackgroundColor.toARGB32();
    final int scaffoldR = (scaffoldBgVal >> 16) & 0xFF;
    final int scaffoldG = (scaffoldBgVal >> 8) & 0xFF;
    final int scaffoldB = scaffoldBgVal & 0xFF;
    final Color heroTint =
        Color.fromARGB((0.06 * 255).round(), scaffoldR, scaffoldG, scaffoldB);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SafePath Campus'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).pushNamed('/settings');
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: heroTint,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'SafePath',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Center(
              child: GestureDetector(
                onTap: () => _triggerSOS(context),
                child: Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE63946),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE63946)
                            .withAlpha((0.4 * 255).round()),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _triggerSOS(context),
                      customBorder: const CircleBorder(),
                      child: const Center(
                        child: Text(
                          'SOS',
                          style: TextStyle(
                            fontSize: 52,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFFFFFFF),
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.warning,
                          label: 'Report Incident',
                          onTap: () {
                            // TODO: navigate to Report Incident
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.map,
                          label: 'Campus Map',
                          onTap: () {
                            Navigator.of(context).pushNamed('/campus_map');
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.phone,
                          label: 'Emergency Contacts',
                          onTap: () {
                            // TODO: navigate to Emergency Contacts
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _FeatureCard(
                          icon: Icons.directions_walk,
                          label: 'The Companion',
                          onTap: () {
                            Navigator.of(context).pushNamed('/companion');
                          },
                        ),
                      ),
                    ],
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

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FeatureCard({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cardBg = colorScheme.primaryContainer;
    final cardText = colorScheme.onPrimaryContainer;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      elevation: 4,
      color: cardBg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 48, color: cardText),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cardText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

