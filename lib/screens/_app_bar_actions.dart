import 'package:flutter/material.dart';

import '../services/secure_settings_service.dart';
import 'settings_screen.dart';

/// Common app-bar actions shared across the three main tabs.
///
/// Right now this is just a settings icon that opens the Hub Connection
/// screen. Centralising it here means adding new actions (e.g., About,
/// elder profile switcher) doesn't require editing every tab screen.
class CommonAppBarActions extends StatelessWidget {
  final SecureSettingsService settings;

  const CommonAppBarActions({super.key, required this.settings});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.settings_outlined),
      tooltip: 'Settings',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SettingsScreen(settings: settings),
          ),
        );
      },
    );
  }
}
