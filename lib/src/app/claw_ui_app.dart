import 'package:flutter/material.dart';
import 'dart:math' as math;

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
        // Show waiting screen while the first connection attempt is in-flight.
        if (controller.busy && controller.dashboard == null && controller.error == null) {
          return _ConnectionWaitingScreen(
            endpointLabel: controller.profile?.endpointLabel ?? 'OpenClaw',
          );
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
              Color(0xFF10131A),
              Color(0xFF171B24),
              Color(0xFF241920),
            ],
          ),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _ConnectionWaitingScreen extends StatefulWidget {
  const _ConnectionWaitingScreen({required this.endpointLabel});

  final String endpointLabel;

  @override
  State<_ConnectionWaitingScreen> createState() => _ConnectionWaitingScreenState();
}

class _ConnectionWaitingScreenState extends State<_ConnectionWaitingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[
              Color(0xFF10131A),
              Color(0xFF171B24),
              Color(0xFF241920),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (BuildContext context, Widget? child) {
                    final double scale = 0.88 + 0.12 * _pulse.value;
                    final double opacity = 0.55 + 0.45 * _pulse.value;
                    return Opacity(
                      opacity: opacity,
                      child: Transform.scale(
                        scale: scale,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      Icons.hub_rounded,
                      size: 34,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Connecting…',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.endpointLabel,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(height: 40),
                _OrbitingDots(color: theme.colorScheme.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitingDots extends StatefulWidget {
  const _OrbitingDots({required this.color});

  final Color color;

  @override
  State<_OrbitingDots> createState() => _OrbitingDotsState();
}

class _OrbitingDotsState extends State<_OrbitingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _spin,
      builder: (BuildContext context, _) {
        return SizedBox(
          width: 48,
          height: 48,
          child: CustomPaint(
            painter: _DotsPainter(
              progress: _spin.value,
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _DotsPainter extends CustomPainter {
  const _DotsPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;
    final Offset center = Offset(size.width / 2, size.height / 2);
    const int count = 5;
    const double radius = 16;
    for (int i = 0; i < count; i++) {
      final double angle = 2 * math.pi * (i / count + progress);
      final double dotRadius = 3.5;
      final double opacity = (0.25 + 0.75 * ((i / count + progress) % 1.0)).clamp(0.0, 1.0);
      paint.color = color.withValues(alpha: opacity);
      canvas.drawCircle(
        Offset(
          center.dx + radius * math.cos(angle),
          center.dy + radius * math.sin(angle),
        ),
        dotRadius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.progress != progress;
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
              Color(0xFF151117),
              Color(0xFF241820),
              Color(0xFF2C1D24),
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
