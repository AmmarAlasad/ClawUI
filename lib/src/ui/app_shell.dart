import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import 'chat_screen.dart';
import 'cron_screen.dart';
import 'devices_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'skills_screen.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final int selectedIndex = controller.tabIndex.clamp(0, 5);
    final Widget screen = switch (selectedIndex) {
      0 => const HomeScreen(),
      1 => const ChatScreen(),
      2 => const DevicesScreen(),
      3 => const CronScreen(),
      4 => const SkillsScreen(),
      _ => const SettingsScreen(),
    };

    return Scaffold(
      extendBody: true,
      body: screen,
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: controller.setTabIndex,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_rounded),
              label: 'Chat',
            ),
            NavigationDestination(
              icon: Icon(Icons.devices_other_outlined),
              selectedIcon: Icon(Icons.devices_other_rounded),
              label: 'Devices',
            ),
            NavigationDestination(
              icon: Icon(Icons.schedule_outlined),
              selectedIcon: Icon(Icons.schedule_rounded),
              label: 'Cron',
            ),
            NavigationDestination(
              icon: Icon(Icons.extension_outlined),
              selectedIcon: Icon(Icons.extension_rounded),
              label: 'Skills',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Settings',
            ),
          ],
        ),
      ),
    );
  }
}
