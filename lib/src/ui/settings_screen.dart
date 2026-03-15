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
          const ScreenIntro(
            eyebrow: 'Preferences',
            title: 'Manage the active gateway profile and UI mode.',
            description:
                'Connection data is currently stored in a local file-backed profile store until mobile-native secure storage is wired in.',
          ),
          const SizedBox(height: 16),
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
                  Text(profile.targetLabel),
                  const SizedBox(height: 6),
                  Text('Endpoint: ${profile.endpointLabel}'),
                  const SizedBox(height: 6),
                  Text('HTTP: ${profile.chatCompletionsUri}'),
                  const SizedBox(height: 6),
                  Text('WS: ${profile.websocketUri}'),
                  const SizedBox(height: 6),
                  Text('Auth: ${profile.authLabel}'),
                  const SizedBox(height: 6),
                  Text(
                    'Mode: ${profile.demoMode ? 'Demo fallback' : 'Live first'}',
                  ),
                  const SizedBox(height: 6),
                  Text('Transport: ${profile.transportLabel}'),
                  if (controller.connectionCheck != null) ...<Widget>[
                    const SizedBox(height: 6),
                    Text('Last check: ${controller.connectionCheck!.message}'),
                  ],
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
                SegmentedButton<ThemeMode>(
                  segments: const <ButtonSegment<ThemeMode>>[
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.system,
                      label: Text('System'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.dark,
                      label: Text('Dark'),
                    ),
                    ButtonSegment<ThemeMode>(
                      value: ThemeMode.light,
                      label: Text('Light'),
                    ),
                  ],
                  selected: <ThemeMode>{controller.themeMode},
                  onSelectionChanged: (Set<ThemeMode> value) {
                    controller.setThemeMode(value.first);
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
