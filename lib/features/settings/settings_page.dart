import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:safepath_campus/theme/theme_provider.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _pushNotificationsEnabled = true;
  bool _locationTrackingEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDarkMode = themeProvider.themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          _buildSectionHeader('Appearance'),
          SwitchListTile(
            title: const Text('Dark Mode'),
            value: isDarkMode,
            onChanged: (value) {
              final newMode = value ? ThemeMode.dark : ThemeMode.light;
              themeProvider.setThemeMode(newMode);
            },
          ),
          _buildSectionHeader('Notification Settings'),
          SwitchListTile(
            title: const Text('Enable push notifications'),
            value: _pushNotificationsEnabled,
            onChanged: (value) {
              setState(() {
                _pushNotificationsEnabled = value;
              });
            },
          ),
          _buildSectionHeader('Privacy & Security'),
          SwitchListTile(
            title: const Text('Enable location tracking always'),
            value: _locationTrackingEnabled,
            onChanged: (value) {
              setState(() {
                _locationTrackingEnabled = value;
              });
            },
          ),
          ListTile(
            title: const Text('Data sharing policy'),
            onTap: () {
              Navigator.of(context).pushNamed('/data_sharing_policy');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}

