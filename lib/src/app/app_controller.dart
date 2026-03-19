import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/background_notification_service.dart';
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
  ChatMessage? _streamingMessage;
  bool _loadingDevices = false;
  bool _loadingCronJobs = false;
  bool _loadingCronRuns = false;
  bool _loadingSkills = false;
  int _tabIndex = 0;
  ThemeMode _themeMode = ThemeMode.system;
  ConnectionProfile? _profile;
  DashboardSnapshot? _dashboard;
  ConnectionCheckResult? _connectionCheck;
  DateTime? _lastUpdatedAt;
  List<DeviceInfo> _devices = const <DeviceInfo>[];
  List<CronJob> _cronJobs = const <CronJob>[];
  List<CronRun> _cronRuns = const <CronRun>[];
  String? _selectedCronJobId;
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

  // Continuous gateway event subscription + polling
  StreamSubscription<Map<String, dynamic>>? _eventSub;
  Timer? _chatPollTimer;
  final Set<String> _sessionsWithUnread = <String>{};

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
  List<CronRun> get cronRuns => _cronRuns;
  bool get loadingCronRuns => _loadingCronRuns;
  String? get selectedCronJobId => _selectedCronJobId;
  List<SkillInfo> get skills => _skills;
  String get activeSessionKey => _activeSessionKey;
  bool get approvalRequired => _approvalRequired;
  String? get approvalMessage => _approvalMessage;
  List<ChatMessage> get messages => _messages;

  /// Non-null while an assistant reply is being streamed token-by-token.
  ChatMessage? get streamingMessage => _streamingMessage;
  String? get error => _error;

  /// Sessions that received a new message while not the active session.
  Set<String> get sessionsWithUnread => _sessionsWithUnread;

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
      BackgroundNotificationService.instance.start(_profile!, _profile!.secret);
      _startGatewayListener();
      _startChatPolling();
      unawaited(refresh());
    }
  }

  Future<void> saveProfile(ConnectionProfile profile) async {
    _profile = profile;
    _error = null;
    await _secretStore.save(profile);
    await _profileStore.save(profile.copyWith(token: '', password: ''));
    BackgroundNotificationService.instance.start(_profile!, _profile!.secret);
    _startGatewayListener();
    _startChatPolling();
    notifyListeners();
    unawaited(refresh());
  }

  Future<void> clearProfile() async {
    _eventSub?.cancel();
    _eventSub = null;
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
    _sessionsWithUnread.clear();
    BackgroundNotificationService.instance.stop();
    await _secretStore.clear();
    await _profileStore.clear();
    _profile = null;
    _dashboard = null;
    _connectionCheck = null;
    _lastUpdatedAt = null;
    _devices = const <DeviceInfo>[];
    _cronJobs = const <CronJob>[];
    _cronRuns = const <CronRun>[];
    _selectedCronJobId = null;
    _skills = const <SkillInfo>[];
    _activeSessionKey = 'main';
    _streamingMessage = null;
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
      _selectedCronJobId = _resolveSelectedCronJobId(
        current: _selectedCronJobId,
        jobs: _cronJobs,
      );
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

  Future<void> removeTrustedDevice(DeviceInfo device) async {
    final ConnectionProfile? profile = _profile;
    if (profile == null) {
      return;
    }
    await _repository.removeTrustedDevice(profile, device);
    await _loadDevices();
    await refresh();
  }

  Future<void> setSkillInput(SkillInfo skill, String value) async {
    final ConnectionProfile? profile = _profile;
    if (profile == null || value.trim().isEmpty) {
      return;
    }
    await _repository.setSkillInput(profile, skill, value.trim());
    await _loadSkills();
    await refresh();
  }

  Future<void> sendMessage(
    String text, {
    List<ChatAttachment> attachments = const <ChatAttachment>[],
  }) async {
    final ConnectionProfile? profile = _profile;
    if (profile == null ||
        (text.trim().isEmpty && attachments.isEmpty) ||
        _sendingMessage) {
      return;
    }

    final ChatMessage userMessage = ChatMessage(
      role: MessageRole.user,
      content: text.trim(),
      timestampLabel: 'now',
      attachments: attachments,
    );
    _messages = <ChatMessage>[..._messages, userMessage];
    // Show typing indicator immediately
    _streamingMessage = const ChatMessage(
      role: MessageRole.assistant,
      content: '',
      timestampLabel: 'now',
      isStreaming: true,
    );
    _sendingMessage = true;
    notifyListeners();

    try {
      final ChatMessage reply = await _repository.sendMessage(
        profile,
        text.trim(),
        _messages,
        sessionKey: _activeSessionKey,
        attachments: attachments,
        onStreamChunk: (String accumulated) {
          _streamingMessage = ChatMessage(
            role: MessageRole.assistant,
            content: accumulated,
            timestampLabel: 'now',
            isStreaming: true,
          );
          notifyListeners();
        },
      );
      _streamingMessage = null;
      _messages = <ChatMessage>[..._messages, reply];
      _sendingMessage = false;
      notifyListeners();
      // Reload the full chat history from the server so we get the real
      // complete response (including tool call outputs, summaries, etc.)
      await _loadChatHistoryForActiveSession();
    } catch (error) {
      _streamingMessage = null;
      _messages = <ChatMessage>[
        ..._messages,
        ChatMessage(
          role: MessageRole.assistant,
          content: error.toString(),
          timestampLabel: 'now',
        ),
      ];
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
    _sessionsWithUnread.remove(normalized); // clear unread badge on switch
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
    _eventSub?.cancel();
    _chatPollTimer?.cancel();
    _themeModeNotifier.dispose();
    super.dispose();
  }

  // ── Persistent gateway event listener ──────────────────────────────────────

  void _startGatewayListener() {
    _eventSub?.cancel();
    _eventSub = null;
    final ConnectionProfile? profile = _profile;
    if (profile == null) return;
    _eventSub = _repository
        .watchGatewayEvents(profile)
        .listen(_handleGatewayEvent, onError: (_) {}, cancelOnError: false);
  }

  void _handleGatewayEvent(Map<String, dynamic> event) {
    final String eventName = event['event'] as String? ?? '';
    if (eventName != 'chat.message' &&
        eventName != 'chat.reply' &&
        eventName != 'chat.stream') {
      return;
    }
    final Map<String, dynamic> payload =
        event['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final String role = (payload['role'] as String? ?? '').trim();
    // Only care about assistant messages (ignore user echoes)
    if (role.isNotEmpty && role != 'assistant') return;

    final String? eventSession =
        payload['sessionKey'] as String? ?? payload['session_key'] as String?;

    if (eventSession == null || eventSession == _activeSessionKey) {
      // New message in the active session — reload immediately if not sending
      if (!_sendingMessage) {
        unawaited(_loadChatHistoryForActiveSession());
      }
    } else {
      // New message in a background session — mark as unread
      _sessionsWithUnread.add(eventSession);
      notifyListeners();
    }
  }

  // ── Polling fallback (catches messages even when WS events don't fire) ─────

  void _startChatPolling() {
    _chatPollTimer?.cancel();
    // Poll every 2 s while the Chat tab is visible and no send is in-flight.
    _chatPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (_tabIndex == 1 && !_sendingMessage && !_loadingChatHistory) {
        unawaited(_loadChatHistoryForActiveSession());
      }
    });
  }

  // ── Internal helpers ────────────────────────────────────────────────────────

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
      _selectedCronJobId = _resolveSelectedCronJobId(
        current: _selectedCronJobId,
        jobs: _cronJobs,
      );
      await _loadCronRunsForSelectedJob(notify: false);
      _syncDashboardCounts();
      notifyListeners();
    } catch (_) {
      // Keep the last visible cron state.
    } finally {
      _loadingCronJobs = false;
    }
  }

  Future<void> selectCronJob(String? jobId) async {
    final String? normalized = jobId?.trim();
    if ((normalized == null || normalized.isEmpty) &&
        _selectedCronJobId == null) {
      return;
    }
    if (normalized == _selectedCronJobId) {
      return;
    }
    _selectedCronJobId = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;
    _cronRuns = const <CronRun>[];
    notifyListeners();
    await _loadCronRunsForSelectedJob();
  }

  Future<void> _loadCronRunsForSelectedJob({bool notify = true}) async {
    final ConnectionProfile? profile = _profile;
    final String? jobId = _selectedCronJobId;
    if (profile == null || jobId == null || jobId.isEmpty || _loadingCronRuns) {
      return;
    }
    _loadingCronRuns = true;
    if (notify) {
      notifyListeners();
    }
    try {
      _cronRuns = await _repository.fetchCronRuns(profile, jobId: jobId);
    } catch (_) {
      _cronRuns = const <CronRun>[];
    } finally {
      _loadingCronRuns = false;
      if (notify) {
        notifyListeners();
      }
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

  String? _resolveSelectedCronJobId({
    required String? current,
    required List<CronJob> jobs,
  }) {
    if (jobs.isEmpty) {
      return null;
    }
    if (current != null && jobs.any((CronJob job) => job.id == current)) {
      return current;
    }
    return jobs.first.id;
  }
}
