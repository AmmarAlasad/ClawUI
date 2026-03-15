import 'package:flutter/material.dart';

import '../core/connection_secret_store.dart';
import '../core/openclaw_repository.dart';
import '../core/profile_store.dart';
import '../core/theme.dart';
import '../ui/app_shell.dart';
import '../ui/connect_screen.dart';
import 'app_controller.dart';
import 'app_scope.dart';

class ClawUiBootstrap extends StatefulWidget {
  const ClawUiBootstrap({super.key, this.controller});

  final AppController? controller;

  @override
  State<ClawUiBootstrap> createState() => _ClawUiBootstrapState();
}

class _ClawUiBootstrapState extends State<ClawUiBootstrap> {
  late final AppController _controller =
      widget.controller ??
      AppController(
        profileStore: createConnectionProfileStore(),
        secretStore: SecureConnectionSecretStore(),
        repository: OpenClawRepositoryRouter(
          fallback: DemoOpenClawRepository(),
          network: NetworkOpenClawRepository(OpenClawApiClient()),
        ),
      );

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    _controller.initialize();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: _controller,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _controller.themeModeListenable,
        builder: (BuildContext context, ThemeMode themeMode, _) {
          return MaterialApp(
            title: 'ClawUI',
            debugShowCheckedModeBanner: false,
            themeMode: themeMode,
            theme: buildClawTheme(Brightness.light),
            darkTheme: buildClawTheme(Brightness.dark),
            builder: (BuildContext context, Widget? child) {
              return child ?? const SizedBox.shrink();
            },
            home: const _AppViewport(),
          );
        },
      ),
    );
  }
}

class _AppViewport extends StatelessWidget {
  const _AppViewport();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppScope.of(context),
      builder: (BuildContext context, _) {
        final AppController controller = AppScope.of(context);
        if (!controller.ready) {
          return const _LaunchScreen();
        }
        if (controller.profile == null) {
          return const ConnectScreen();
        }
        if (controller.approvalRequired) {
          return const _ApprovalRequiredScreen();
        }
        return const AppShell();
      },
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

class _ApprovalRequiredScreen extends StatelessWidget {
  const _ApprovalRequiredScreen();

  @override
  Widget build(BuildContext context) {
    final AppController controller = AppScope.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF081018),
              Color(0xFF0D1D29),
              Color(0xFF133A47),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                margin: const EdgeInsets.all(24),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Approve this device first',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        controller.approvalMessage ??
                            'This ClawUI device is waiting for approval in the OpenClaw UI.',
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'OpenClaw endpoint: ${controller.profile?.endpointLabel ?? 'Unknown'}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton(
                              onPressed: controller.busy
                                  ? null
                                  : () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const ConnectScreen(),
                                        ),
                                      );
                                    },
                              child: const Text('Edit connection'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: controller.busy
                                  ? null
                                  : controller.refresh,
                              child: controller.busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Refresh'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
