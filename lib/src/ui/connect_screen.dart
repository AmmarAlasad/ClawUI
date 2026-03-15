import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'app_shell.dart';
import 'widgets.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final TextEditingController _nameController = TextEditingController(
    text: 'Primary Gateway',
  );
  final TextEditingController _serverController = TextEditingController(
    text: 'https://gateway.local',
  );
  final TextEditingController _tokenController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  AuthMode _authMode = AuthMode.token;
  bool _demoMode = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ConnectionProfile? profile = AppScope.of(context).profile;
    if (profile != null && _serverController.text == 'https://gateway.local') {
      _nameController.text = profile.name;
      _serverController.text = profile.serverUrl;
      _tokenController.text = profile.token;
      _passwordController.text = profile.password;
      _authMode = profile.authMode;
      _demoMode = profile.demoMode;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _serverController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
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
              ClawCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SectionTitle('Gateway Profile'),
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Profile name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _serverController,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Server URL',
                        hintText: 'https://gateway.example.com',
                      ),
                    ),
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
                        ButtonSegment<AuthMode>(
                          value: AuthMode.none,
                          label: Text('None'),
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
                      TextField(
                        controller: _tokenController,
                        decoration: const InputDecoration(
                          labelText: 'Access token',
                        ),
                      ),
                    if (_authMode == AuthMode.password)
                      TextField(
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
                        'Keeps the app usable while the API contract is still in flux.',
                      ),
                      onChanged: (bool value) {
                        setState(() {
                          _demoMode = value;
                        });
                      },
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () async {
                        final ConnectionProfile profile = ConnectionProfile(
                          name: _nameController.text.trim().isEmpty
                              ? 'Primary Gateway'
                              : _nameController.text.trim(),
                          serverUrl: _serverController.text.trim(),
                          authMode: _authMode,
                          token: _tokenController.text.trim(),
                          password: _passwordController.text.trim(),
                          demoMode: _demoMode,
                        );
                        await controller.saveProfile(profile);
                        if (!mounted) {
                          return;
                        }
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                          return;
                        }
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute<void>(
                            builder: (_) => const AppShell(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.link_rounded),
                      label: const Text('Save And Connect'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
