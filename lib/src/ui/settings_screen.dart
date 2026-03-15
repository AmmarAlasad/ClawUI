import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import 'connect_screen.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final profile = controller.profile;

    return ScreenScaffold(
      title: 'Settings',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ClawCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionTitle('Connection'),
                if (profile != null) ...<Widget>[
                  Text(
                    profile.name,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(profile.serverUrl),
                  const SizedBox(height: 6),
                  Text('Auth: ${profile.authMode.name}'),
                  const SizedBox(height: 6),
                  Text(
                    'Mode: ${profile.demoMode ? 'Demo fallback' : 'Live first'}',
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ConnectScreen(),
                            ),
                          );
                        },
                        child: const Text('Edit connection'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: controller.clearProfile,
                        child: const Text('Disconnect'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ClawCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SectionTitle('Appearance'),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  value: ThemeMode.system,
                  groupValue: controller.themeMode,
                  title: const Text('System'),
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      controller.setThemeMode(value);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  value: ThemeMode.dark,
                  groupValue: controller.themeMode,
                  title: const Text('Dark'),
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      controller.setThemeMode(value);
                    }
                  },
                ),
                RadioListTile<ThemeMode>(
                  contentPadding: EdgeInsets.zero,
                  value: ThemeMode.light,
                  groupValue: controller.themeMode,
                  title: const Text('Light'),
                  onChanged: (ThemeMode? value) {
                    if (value != null) {
                      controller.setThemeMode(value);
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
