import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

enum _DiagnosticTone { info, success, warning }

class _ConnectDiagnostic {
  const _ConnectDiagnostic({
    required this.title,
    required this.message,
    required this.tone,
    this.action,
  });

  final String title;
  final String message;
  final _DiagnosticTone tone;
  final String? action;
}

class _ConnectScreenState extends State<ConnectScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController(
    text: 'Primary Gateway',
  );
  final TextEditingController _directUrlController = TextEditingController(
    text: 'https://gateway.example.com',
  );
  final TextEditingController _hostController = TextEditingController(
    text: 'gateway.local',
  );
  final TextEditingController _portController = TextEditingController(
    text: '18789',
  );
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  ConnectionTargetKind _targetKind = ConnectionTargetKind.directUrl;
  TransportSecurity _transportSecurity = TransportSecurity.tls;
  AuthMode _authMode = AuthMode.token;
  bool _demoMode = false;
  bool _loadedProfile = false;
  ConnectionCheckResult? _lastCheck;
  String? _connectError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ConnectionProfile? profile = AppScope.of(context).profile;
    if (profile != null && !_loadedProfile) {
      _nameController.text = profile.name;
      _directUrlController.text = profile.directUrl;
      _hostController.text = profile.host;
      _portController.text = '${profile.port}';
      _tokenController.text = profile.token;
      _passwordController.text = profile.password;
      _targetKind = profile.targetKind;
      _transportSecurity = profile.transportSecurity;
      _authMode = profile.authMode;
      _demoMode = profile.demoMode;
      _loadedProfile = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _directUrlController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  ConnectionProfile _buildProfile() {
    return ConnectionProfile(
      name: _nameController.text.trim().isEmpty
          ? 'Primary Gateway'
          : _nameController.text.trim(),
      targetKind: _targetKind,
      transportSecurity: _transportSecurity,
      directUrl: _directUrlController.text.trim(),
      host: _hostController.text.trim(),
      port: int.tryParse(_portController.text.trim()) ?? 0,
      authMode: _authMode,
      token: _tokenController.text.trim(),
      password: _passwordController.text.trim(),
      demoMode: _demoMode,
    );
  }

  List<_ConnectDiagnostic> _buildDiagnostics(
    ConnectionProfile draft,
    ConnectionCheckResult? result,
  ) {
    final List<_ConnectDiagnostic> diagnostics = <_ConnectDiagnostic>[];
    final String endpoint = draft.endpointLabel;
    diagnostics.add(
      _ConnectDiagnostic(
        title: 'Profile target',
        message:
            '${draft.targetLabel} · ${draft.transportLabel} · ${draft.authLabel} · $endpoint',
        tone: _DiagnosticTone.info,
        action: draft.demoMode
            ? 'Demo mode is enabled, so saved profiles can be explored without a verified live gateway.'
            : 'This is the exact gateway origin ClawUI will derive HTTP and WebSocket surfaces from.',
      ),
    );
    for (final String note in draft.securityNotes()) {
      diagnostics.add(
        _ConnectDiagnostic(
          title: 'Security note',
          message: note,
          tone: _DiagnosticTone.info,
        ),
      );
    }
    if (result == null) {
      return diagnostics;
    }

    if (result.ok) {
      diagnostics.add(
        _ConnectDiagnostic(
          title: 'Gateway verified',
          message: result.message,
          tone: _DiagnosticTone.success,
          action:
              'You can safely save this profile and start using chat, sessions, devices, cron, and skills.',
        ),
      );
      return diagnostics;
    }

    final String normalized = result.message.trim().toLowerCase();
    if (!result.reachable) {
      diagnostics.add(
        _ConnectDiagnostic(
          title: 'Gateway unreachable',
          message: result.message,
          tone: _DiagnosticTone.warning,
          action:
              'Check the host/URL, port, tunnel, Tailscale route, and whether the gateway process is actually listening.',
        ),
      );
      return diagnostics;
    }

    if (normalized.contains('pairing required') ||
        normalized.contains('not paired') ||
        normalized.contains('approve this device')) {
      diagnostics.add(
        _ConnectDiagnostic(
          title: 'Device approval required',
          message: result.message,
          tone: _DiagnosticTone.warning,
          action:
              'Approve this device in OpenClaw first, then run the connection test again.',
        ),
      );
      return diagnostics;
    }

    if (normalized.contains('missing scope:')) {
      diagnostics.add(
        _ConnectDiagnostic(
          title: 'Scope mismatch',
          message: result.message,
          tone: _DiagnosticTone.warning,
          action:
              'The gateway is reachable, but this credential does not have the operator scope ClawUI needs.',
        ),
      );
      return diagnostics;
    }

    if (!result.authenticated ||
        normalized.contains('auth failed') ||
        normalized.contains('unauthorized') ||
        normalized.contains('rejected')) {
      diagnostics.add(
        _ConnectDiagnostic(
          title: 'Authentication failed',
          message: result.message,
          tone: _DiagnosticTone.warning,
          action:
              'Double-check whether this gateway expects a token or a password, then verify the secret value itself.',
        ),
      );
      return diagnostics;
    }

    if (!result.ready) {
      diagnostics.add(
        _ConnectDiagnostic(
          title: 'Gateway not ready yet',
          message: result.message,
          tone: _DiagnosticTone.warning,
          action:
              'The process answered, but the operator surfaces are not ready yet. Wait a moment and test again.',
        ),
      );
      return diagnostics;
    }

    diagnostics.add(
      _ConnectDiagnostic(
        title: 'Connection needs attention',
        message: result.message,
        tone: _DiagnosticTone.warning,
        action:
            'The gateway responded, but ClawUI still cannot confirm a healthy operator session. Re-check auth, scopes, and pairing.',
      ),
    );
    return diagnostics;
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final ConnectionProfile draft = _buildProfile();
    final List<_ConnectDiagnostic> diagnostics = _buildDiagnostics(
      draft,
      _lastCheck,
    );
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
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: <Widget>[
              const SizedBox(height: 24),
              Text(
                'Connect ClawUI',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Secure mobile control for OpenClaw over LAN, VPN, or Tailscale.',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 28),
              const ClawCard(
                child: ScreenIntro(
                  eyebrow: 'Operator Setup',
                  title:
                      'Normalize one gateway profile and keep the surfaces explicit.',
                  description:
                      'ClawUI derives HTTP and WebSocket gateway surfaces from a single validated profile and avoids path, query, and embedded-credential ambiguity.',
                ),
              ),
              const SizedBox(height: 16),
              ClawCard(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SectionTitle('Gateway Profile'),
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Profile name',
                        ),
                      ),
                      const SizedBox(height: 16),
                      SegmentedButton<ConnectionTargetKind>(
                        segments: const <ButtonSegment<ConnectionTargetKind>>[
                          ButtonSegment<ConnectionTargetKind>(
                            value: ConnectionTargetKind.directUrl,
                            label: Text('Direct URL'),
                          ),
                          ButtonSegment<ConnectionTargetKind>(
                            value: ConnectionTargetKind.hostPort,
                            label: Text('Host + port'),
                          ),
                          ButtonSegment<ConnectionTargetKind>(
                            value: ConnectionTargetKind.tailscale,
                            label: Text('Tailscale'),
                          ),
                        ],
                        selected: <ConnectionTargetKind>{_targetKind},
                        onSelectionChanged: (Set<ConnectionTargetKind> value) {
                          setState(() {
                            _targetKind = value.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_targetKind == ConnectionTargetKind.directUrl)
                        TextFormField(
                          controller: _directUrlController,
                          keyboardType: TextInputType.url,
                          decoration: const InputDecoration(
                            labelText: 'Gateway URL',
                            hintText: 'https://gateway.example.com',
                          ),
                        ),
                      if (_targetKind !=
                          ConnectionTargetKind.directUrl) ...<Widget>[
                        TextFormField(
                          controller: _hostController,
                          decoration: InputDecoration(
                            labelText:
                                _targetKind == ConnectionTargetKind.tailscale
                                ? 'MagicDNS / Tailscale host'
                                : 'Host or IP',
                            hintText:
                                _targetKind == ConnectionTargetKind.tailscale
                                ? 'gateway.tail123.ts.net'
                                : '192.168.1.20',
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Port'),
                        ),
                        const SizedBox(height: 16),
                        SegmentedButton<TransportSecurity>(
                          segments: const <ButtonSegment<TransportSecurity>>[
                            ButtonSegment<TransportSecurity>(
                              value: TransportSecurity.tls,
                              label: Text('HTTPS'),
                            ),
                            ButtonSegment<TransportSecurity>(
                              value: TransportSecurity.insecure,
                              label: Text('HTTP'),
                            ),
                          ],
                          selected: <TransportSecurity>{_transportSecurity},
                          onSelectionChanged: (Set<TransportSecurity> value) {
                            setState(() {
                              _transportSecurity = value.first;
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      SegmentedButton<AuthMode>(
                        segments: const <ButtonSegment<AuthMode>>[
                          ButtonSegment<AuthMode>(
                            value: AuthMode.token,
                            label: Text('Token'),
                          ),
                          ButtonSegment<AuthMode>(
                            value: AuthMode.password,
                            label: Text('Password'),
                          ),
                        ],
                        selected: <AuthMode>{_authMode},
                        onSelectionChanged: (Set<AuthMode> value) {
                          setState(() {
                            _authMode = value.first;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      if (_authMode == AuthMode.token)
                        TextFormField(
                          controller: _tokenController,
                          decoration: const InputDecoration(
                            labelText: 'Access token',
                          ),
                        ),
                      if (_authMode == AuthMode.password)
                        TextFormField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                          ),
                        ),
                      const SizedBox(height: 16),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        value: _demoMode,
                        title: const Text('Use demo data fallback'),
                        subtitle: const Text(
                          'Lets you explore the UI without storing an unverified live gateway.',
                        ),
                        onChanged: (bool value) {
                          setState(() {
                            _demoMode = value;
                          });
                        },
                      ),
                      if (_connectError != null) ...<Widget>[
                        const SizedBox(height: 16),
                        StatusBanner(
                          title: 'Validation issue',
                          message: _connectError!,
                          tone: BannerTone.warning,
                        ),
                      ],
                      const SizedBox(height: 12),
                      const SectionTitle('Connection Diagnostics'),
                      ...diagnostics.map(
                        (_ConnectDiagnostic diagnostic) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DiagnosticCard(diagnostic: diagnostic),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: controller.testingConnection
                                  ? null
                                  : () async {
                                      final ConnectionProfile profile =
                                          _buildProfile();
                                      final List<String> errors = profile
                                          .validate();
                                      setState(() {
                                        _connectError = errors.isEmpty
                                            ? null
                                            : errors.first;
                                      });
                                      if (errors.isNotEmpty) {
                                        return;
                                      }
                                      final ConnectionCheckResult result =
                                          await controller.testConnection(
                                            profile,
                                          );
                                      if (!mounted) {
                                        return;
                                      }
                                      setState(() {
                                        _lastCheck = result;
                                      });
                                    },
                              icon: const Icon(Icons.shield_outlined),
                              label: const Text('Test'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: controller.testingConnection
                                  ? null
                                  : () async {
                                      final ConnectionProfile profile =
                                          _buildProfile();
                                      final List<String> errors = profile
                                          .validate();
                                      setState(() {
                                        _connectError = errors.isEmpty
                                            ? null
                                            : errors.first;
                                      });
                                      if (errors.isNotEmpty) {
                                        return;
                                      }
                                      ConnectionCheckResult? result =
                                          _lastCheck;
                                      if (!profile.demoMode) {
                                        result = await controller
                                            .testConnection(profile);
                                        if (!mounted) {
                                          return;
                                        }
                                        setState(() {
                                          _lastCheck = result;
                                        });
                                        if (!result.ok) {
                                          return;
                                        }
                                      }
                                      await controller.saveProfile(profile);
                                      if (!mounted) {
                                        return;
                                      }
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Connection profile saved.',
                                          ),
                                        ),
                                      );
                                      if (Navigator.of(context).canPop()) {
                                        Navigator.of(context).pop();
                                      }
                                    },
                              icon: const Icon(Icons.link_rounded),
                              label: const Text('Save And Connect'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'HTTP: ${draft.httpBaseUri}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'WS: ${draft.websocketUri}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DiagnosticCard extends StatelessWidget {
  const _DiagnosticCard({required this.diagnostic});

  final _ConnectDiagnostic diagnostic;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ({Color color, IconData icon}) style = switch (diagnostic.tone) {
      _DiagnosticTone.info => (
        color: theme.colorScheme.primary,
        icon: Icons.info_outline_rounded,
      ),
      _DiagnosticTone.success => (
        color: Colors.green,
        icon: Icons.verified_rounded,
      ),
      _DiagnosticTone.warning => (
        color: Colors.orangeAccent,
        icon: Icons.warning_amber_rounded,
      ),
    };

    return ClawCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: style.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(style.icon, color: style.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  diagnostic.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(diagnostic.message),
                if (diagnostic.action != null &&
                    diagnostic.action!.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    diagnostic.action!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
