import 'package:flutter/material.dart';

import '../core/openclaw_repository.dart';
import '../core/profile_store.dart';
import '../core/theme.dart';
import '../ui/app_shell.dart';
import '../ui/connect_screen.dart';
import 'app_controller.dart';
import 'app_scope.dart';

class ClawUiBootstrap extends StatefulWidget {
  const ClawUiBootstrap({super.key});

  @override
  State<ClawUiBootstrap> createState() => _ClawUiBootstrapState();
}

class _ClawUiBootstrapState extends State<ClawUiBootstrap> {
  late final AppController _controller = AppController(
    profileStore: FileConnectionProfileStore(),
    repository: OpenClawRepositoryRouter(
      fallback: DemoOpenClawRepository(),
      network: NetworkOpenClawRepository(OpenClawApiClient()),
    ),
  );

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (BuildContext context, _) {
          return MaterialApp(
            title: 'ClawUI',
            debugShowCheckedModeBanner: false,
            themeMode: _controller.themeMode,
            theme: buildClawTheme(Brightness.light),
            darkTheme: buildClawTheme(Brightness.dark),
            home: !_controller.ready
                ? const _LaunchScreen()
                : _controller.profile == null
                ? const ConnectScreen()
                : const AppShell(),
          );
        },
      ),
    );
  }
}

class _LaunchScreen extends StatelessWidget {
  const _LaunchScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF05080E),
              Color(0xFF0F1D28),
              Color(0xFF123646),
            ],
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
