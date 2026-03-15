import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/openclaw_repository.dart';
import '../core/profile_store.dart';

class AppController extends ChangeNotifier {
  AppController({
    required ConnectionProfileStore profileStore,
    required OpenClawRepository repository,
  }) : _profileStore = profileStore,
       _repository = repository;

  final ConnectionProfileStore _profileStore;
  final OpenClawRepository _repository;

  bool _ready = false;
  bool _busy = false;
  bool _sendingMessage = false;
  int _tabIndex = 0;
  ThemeMode _themeMode = ThemeMode.system;
  ConnectionProfile? _profile;
  DashboardSnapshot? _dashboard;
  DateTime? _lastUpdatedAt;
  List<DeviceInfo> _devices = const <DeviceInfo>[];
  List<CronJob> _cronJobs = const <CronJob>[];
  List<ChatMessage> _messages = const <ChatMessage>[
    ChatMessage(
      role: MessageRole.assistant,
      content:
          'ClawUI is ready. Ask for gateway status, device approvals, or cron health.',
      timestampLabel: 'now',
    ),
  ];
  String? _error;

  bool get ready => _ready;
  bool get busy => _busy;
  bool get sendingMessage => _sendingMessage;
  int get tabIndex => _tabIndex;
  ThemeMode get themeMode => _themeMode;
  ConnectionProfile? get profile => _profile;
  DashboardSnapshot? get dashboard => _dashboard;
  DateTime? get lastUpdatedAt => _lastUpdatedAt;
  List<DeviceInfo> get devices => _devices;
  List<CronJob> get cronJobs => _cronJobs;
  List<ChatMessage> get messages => _messages;
  String? get error => _error;

  Future<void> initialize() async {
    _profile = await _profileStore.load();
    _ready = true;
    notifyListeners();
    if (_profile != null) {
      await refresh();
    }
  }

  Future<void> saveProfile(ConnectionProfile profile) async {
    _profile = profile;
    _error = null;
    await _profileStore.save(profile);
    notifyListeners();
    await refresh();
  }

  Future<void> clearProfile() async {
    await _profileStore.clear();
    _profile = null;
    _dashboard = null;
    _lastUpdatedAt = null;
    _devices = const <DeviceInfo>[];
    _cronJobs = const <CronJob>[];
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
    if (profile == null) {
      return;
    }
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      final List<Object> results = await Future.wait<Object>(<Future<Object>>[
        _repository.fetchDashboard(profile),
        _repository.fetchDevices(profile),
        _repository.fetchCronJobs(profile),
      ]);
      _dashboard = results[0] as DashboardSnapshot;
      _devices = results[1] as List<DeviceInfo>;
      _cronJobs = results[2] as List<CronJob>;
      _lastUpdatedAt = DateTime.now();
    } catch (_) {
      _error =
          'Unable to refresh gateway data. Demo data will remain available.';
    } finally {
      _busy = false;
      notifyListeners();
    }
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
      );
      _messages = <ChatMessage>[..._messages, reply];
    } catch (_) {
      _messages = <ChatMessage>[
        ..._messages,
        const ChatMessage(
          role: MessageRole.assistant,
          content:
              'The gateway did not respond. Falling back to cached context.',
          timestampLabel: 'now',
        ),
      ];
    } finally {
      _sendingMessage = false;
      notifyListeners();
    }
  }

  Future<void> sendQuickPrompt(String text) => sendMessage(text);

  void setTabIndex(int value) {
    if (_tabIndex == value) {
      return;
    }
    _tabIndex = value;
    notifyListeners();
  }

  void setThemeMode(ThemeMode value) {
    if (_themeMode == value) {
      return;
    }
    _themeMode = value;
    notifyListeners();
  }
}
