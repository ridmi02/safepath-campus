import 'package:flutter/material.dart';
import 'emergency_screen.dart';
import '../services/voice_activation_page.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Modern Dark Blue & White Theme
    const Color darkBlue = Color(0xFF0F172A);
    const Color accentBlue = Color(0xFF38BDF8);
    const Color white = Colors.white;

    return Scaffold(
      backgroundColor: darkBlue,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              Text(
                'SafePath',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(
                  color: white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const Text(
                'Campus Safety System',
                style: TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _buildMenuButton(
                context,
                title: 'Emergency Alert System',
                icon: Icons.emergency_share,
                color: accentBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EmergencyScreen()),
                ),
              ),
              const SizedBox(height: 20),
              _buildMenuButton(
                context,
                title: 'Voice Activation',
                icon: Icons.record_voice_over,
                color: white,
                textColor: darkBlue,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const VoiceActivationPage()),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    Color textColor = Colors.white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 120,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 40, color: color),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
