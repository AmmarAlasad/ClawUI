import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/connection_secret_store.dart';
import '../core/models.dart';
import '../core/openclaw_repository.dart';
import '../core/profile_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required ConnectionProfileStore profileStore,
    required ConnectionSecretStore secretStore,
    required OpenClawRepository repository,
  }) : _profileStore = profileStore,
       _secretStore = secretStore,
       _repository = repository;

  final ConnectionProfileStore _profileStore;
  final ConnectionSecretStore _secretStore;
  final OpenClawRepository _repository;
  final ValueNotifier<ThemeMode> _themeModeNotifier = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  bool _ready = false;
  bool _busy = false;
  bool _testingConnection = false;
  bool _sendingMessage = false;
  bool _loadingChatHistory = false;
  bool _loadingDevices = false;
  bool _loadingCronJobs = false;
  bool _loadingSkills = false;
  int _tabIndex = 0;
  ThemeMode _themeMode = ThemeMode.system;
  ConnectionProfile? _profile;
  DashboardSnapshot? _dashboard;
  ConnectionCheckResult? _connectionCheck;
  DateTime? _lastUpdatedAt;
  List<DeviceInfo> _devices = const <DeviceInfo>[];
  List<CronJob> _cronJobs = const <CronJob>[];
  List<SkillInfo> _skills = const <SkillInfo>[];
  String _activeSessionKey = 'main';
  bool _approvalRequired = false;
  String? _approvalMessage;
  List<ChatMessage> _messages = const <ChatMessage>[
    ChatMessage(
      role: MessageRole.assistant,
      content:
          'ClawUI is ready. Ask for gateway status, sessions, devices, cron, or skills.',
      timestampLabel: 'now',
    ),
  ];
  String? _error;

  bool get ready => _ready;
  bool get busy => _busy;
  bool get testingConnection => _testingConnection;
  bool get sendingMessage => _sendingMessage;
  int get tabIndex => _tabIndex;
  ThemeMode get themeMode => _themeMode;
  ValueListenable<ThemeMode> get themeModeListenable => _themeModeNotifier;
  ConnectionProfile? get profile => _profile;
  DashboardSnapshot? get dashboard => _dashboard;
  ConnectionCheckResult? get connectionCheck => _connectionCheck;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  List<DeviceInfo> get devices => _devices;
  List<CronJob> get cronJobs => _cronJobs;
  List<SkillInfo> get skills => _skills;
  String get activeSessionKey => _activeSessionKey;
  bool get approvalRequired => _approvalRequired;
  String? get approvalMessage => _approvalMessage;
  List<ChatMessage> get messages => _messages;
  String? get error => _error;

  Future<void> initialize() async {
    final ConnectionProfile? storedProfile = await _profileStore.load();
    if (storedProfile != null) {
      final ConnectionProfile hydratedProfile = await _secretStore.hydrate(
        storedProfile,
      );
      _profile = hydratedProfile;
      final bool hadPlaintextSecret =
          storedProfile.token.isNotEmpty || storedProfile.password.isNotEmpty;
      if (hadPlaintextSecret) {
        await _secretStore.save(hydratedProfile);
        await _profileStore.save(_profile!.copyWith(token: '', password: ''));
      }
    }
    _ready = true;
    notifyListeners();
    if (_profile != null) {
      unawaited(refresh());
    }
  }

  Future<void> saveProfile(ConnectionProfile profile) async {
    _profile = profile;
    _error = null;
    await _secretStore.save(profile);
    await _profileStore.save(profile.copyWith(token: '', password: ''));
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> clearProfile() async {
    await _secretStore.clear();
    await _profileStore.clear();
    _profile = null;
    _dashboard = null;
    _connectionCheck = null;
    _lastUpdatedAt = null;
    _devices = const <DeviceInfo>[];
    _cronJobs = const <CronJob>[];
    _skills = const <SkillInfo>[];
    _activeSessionKey = 'main';
    _approvalRequired = false;
    _approvalMessage = null;
    _messages = const <ChatMessage>[
      ChatMessage(
        role: MessageRole.assistant,
        content: 'Connection removed. Configure another gateway to continue.',
        timestampLabel: 'now',
      ),
    ];
    _tabIndex = 0;
    notifyListeners();
  }

  Future<void> refresh() async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || _busy) {
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final OperatorSnapshot snapshot = await _repository.fetchOverview(
        profile,
      );
      _dashboard = snapshot.dashboard;
      if (_dashboard!.sessions.any(
        (SessionInfo item) => item.key == _activeSessionKey,
      )) {
        // keep the active session if it still exists
      } else {
        _activeSessionKey = _dashboard!.sessions.isEmpty
            ? 'main'
            : _dashboard!.sessions.first.key;
      }
      _connectionCheck = snapshot.connectionCheck;
      _lastUpdatedAt = DateTime.now();
      _devices = snapshot.devices;
      _cronJobs = snapshot.cronJobs;
      _skills = snapshot.skills;
      _approvalRequired = snapshot.approvalRequired;
      _approvalMessage = snapshot.approvalMessage;
      _loadForActiveTab();
    } catch (error) {
      _error = error.toString();
      _approvalRequired = _isApprovalRequiredError(_error);
      if (_approvalRequired) {
        _approvalMessage =
            'Approve this device in OpenClaw, then tap refresh to continue.';
      }
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<ConnectionCheckResult> testConnection(
    ConnectionProfile profile,
  ) async {
    _testingConnection = true;
    _error = null;
    notifyListeners();
    try {
      final ConnectionCheckResult result = await _repository.testConnection(
        profile,
      );
      _connectionCheck = result;
      return result;
    } finally {
      _testingConnection = false;
      notifyListeners();
    }
  }

  Future<void> approveDevice(String requestId) async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || requestId.trim().isEmpty) {
      return;
    }
    await _repository.approveDevice(profile, requestId);
    await _loadDevices();
    await refresh();
  }

  Future<void> rejectDevice(String requestId) async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || requestId.trim().isEmpty) {
      return;
    }
    await _repository.rejectDevice(profile, requestId);
    await _loadDevices();
    await refresh();
  }

  Future<void> sendMessage(String text) async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || text.trim().isEmpty || _sendingMessage) {
      return;
    }

    final ChatMessage userMessage = ChatMessage(
      role: MessageRole.user,
      content: text.trim(),
      timestampLabel: 'now',
    );
    _messages = <ChatMessage>[..._messages, userMessage];
    _sendingMessage = true;
    notifyListeners();

    try {
      final ChatMessage reply = await _repository.sendMessage(
        profile,
        text.trim(),
        _messages,
        sessionKey: _activeSessionKey,
      );
      _messages = <ChatMessage>[..._messages, reply];
    } catch (error) {
      _messages = <ChatMessage>[
        ..._messages,
        ChatMessage(
          role: MessageRole.assistant,
          content: error.toString(),
          timestampLabel: 'now',
        ),
      ];
    } finally {
      _sendingMessage = false;
      notifyListeners();
    }
  }

  Future<void> sendQuickPrompt(String text) => sendMessage(text);

  Future<void> setActiveSessionKey(String value) async {
    final String normalized = value.trim().isEmpty ? 'main' : value.trim();
    if (_activeSessionKey == normalized) {
      return;
    }
    _activeSessionKey = normalized;
    _messages = const <ChatMessage>[
      ChatMessage(
        role: MessageRole.assistant,
        content: 'Loading the selected session...',
        timestampLabel: 'now',
      ),
    ];
    notifyListeners();
    unawaited(_loadChatHistoryForActiveSession());
  }

  void setTabIndex(int value) {
    if (_tabIndex == value) {
      return;
    }
    _tabIndex = value;
    notifyListeners();
    _loadForActiveTab();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    _themeModeNotifier.value = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _themeModeNotifier.dispose();
    super.dispose();
  }

  Future<void> _loadChatHistoryForActiveSession() async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || _loadingChatHistory) {
      return;
    }
    _loadingChatHistory = true;
    try {
      _messages = await _repository.fetchChatHistory(
        profile,
        sessionKey: _activeSessionKey,
      );
      _approvalRequired = false;
      _approvalMessage = null;
      notifyListeners();
    } catch (_) {
      // Keep the current chat view if history cannot be loaded.
    } finally {
      _loadingChatHistory = false;
    }
  }

  void _loadForActiveTab() {
    switch (_tabIndex) {
      case 1:
        unawaited(_loadChatHistoryForActiveSession());
        break;
      case 2:
        unawaited(_loadDevices());
        break;
      case 3:
        unawaited(_loadCronJobs());
        break;
      case 4:
        unawaited(_loadSkills());
        break;
      default:
        break;
    }
  }

  Future<void> _loadDevices() async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || _loadingDevices) {
      return;
    }
    _loadingDevices = true;
    try {
      _devices = await _repository.fetchDevices(profile);
      _syncDashboardCounts();
      notifyListeners();
    } catch (_) {
      // Keep the last visible device state.
    } finally {
      _loadingDevices = false;
    }
  }

  Future<void> _loadCronJobs() async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || _loadingCronJobs) {
      return;
    }
    _loadingCronJobs = true;
    try {
      _cronJobs = await _repository.fetchCronJobs(profile);
      _syncDashboardCounts();
      notifyListeners();
    } catch (_) {
      // Keep the last visible cron state.
    } finally {
      _loadingCronJobs = false;
    }
  }

  Future<void> _loadSkills() async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || _loadingSkills) {
      return;
    }
    _loadingSkills = true;
    try {
      _skills = await _repository.fetchSkills(profile);
      _syncDashboardCounts();
      notifyListeners();
    } catch (_) {
      // Keep the last visible skill state.
    } finally {
      _loadingSkills = false;
    }
  }

  void _syncDashboardCounts() {
    final DashboardSnapshot? dashboard = _dashboard;
    if (dashboard == null) {
      return;
    }
    final int pendingApprovals = _devices.where((DeviceInfo item) {
      return item.pendingApproval;
    }).length;
    final int connectedDevices = _devices.where((DeviceInfo item) {
      return !item.pendingApproval;
    }).length;
    final int overdueJobs = _cronJobs.where((CronJob job) {
      return job.health != JobHealth.healthy;
    }).length;
    _dashboard = DashboardSnapshot(
      gatewayStatus: GatewayStatus(
        online: dashboard.gatewayStatus.online,
        authenticated: dashboard.gatewayStatus.authenticated,
        version: dashboard.gatewayStatus.version,
        latencyMs: dashboard.gatewayStatus.latencyMs,
        activeSessions: dashboard.gatewayStatus.activeSessions,
        connectedDevices: connectedDevices,
        pendingApprovals: pendingApprovals,
        runningJobs: _cronJobs.length,
      ),
      sessions: dashboard.sessions,
      connectedDevices: _devices
          .where((DeviceInfo item) => !item.pendingApproval)
          .toList(),
      cronSummary: CronSummary(
        totalJobs: _cronJobs.length,
        overdueJobs: overdueJobs,
        nextRunLabel: _cronJobs.isEmpty
            ? 'Open the Cron tab to load jobs'
            : '${_cronJobs.first.name} ${_cronJobs.first.nextRun}',
      ),
      skills: _skills,
    );
  }

  bool _isApprovalRequiredError(String? message) {
    final String normalized = (message ?? '').trim().toLowerCase();
    return normalized.contains('pairing required') ||
        normalized.contains('not paired') ||
        normalized.contains('device signature invalid') ||
        normalized.contains('approve this device');
  }
}
