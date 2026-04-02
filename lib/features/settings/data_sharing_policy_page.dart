import 'package:flutter/material.dart';

class DataSharingPolicyPage extends StatelessWidget {
  const DataSharingPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Data Sharing Policy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        // Using standard theme properties ensures "Auto Update" works
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
        elevation: 0,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Text(
          '''
Last updated: March 2, 2026

This Data Sharing Policy outlines how your data is collected, used, and shared when you use the SafePath Campus application.

1. Information We Collect
- Location Data: We collect your real-time location to provide safety services, such as emergency SOS alerts and safe path routing. You can control location tracking in the app settings.
- Personal Information: We may collect personal information, such as your name and contact details, for account creation and emergency contact purposes.
- Usage Data: We collect information about your interactions with the app to improve our services.

2. How We Use Your Information
- To provide and maintain our services.
- To improve our services and develop new features.
- To ensure your safety and security.
- To communicate with you, including sending push notifications if enabled.

3. Data Sharing and Disclosure
- We do not sell your personal data to third parties.
- We may share your location and personal information with emergency services in case of an SOS alert.
- We may share anonymized and aggregated data for research and statistical purposes.

4. Data Security
- We implement industry-standard security measures to protect your data.

5. Your Choices
- You can control your notification and location tracking settings in the app.
- You can review and update your personal information in your profile.

By using the SafePath Campus app, you agree to the collection and use of information in accordance with this policy.
          ''',
        ),
      ),
    );
  }
}
