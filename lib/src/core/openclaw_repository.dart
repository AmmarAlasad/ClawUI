import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'gateway_device_auth_store.dart';
import 'gateway_http_client.dart';
import 'gateway_live_session.dart';
import 'gateway_ws_client.dart';
import 'models.dart';

abstract class OpenClawRepository {
  Future<OperatorSnapshot> fetchOverview(ConnectionProfile profile);
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile);
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile);
  Future<List<CronRun>> fetchCronRuns(
    ConnectionProfile profile, {
    required String jobId,
  });
  Future<List<SkillInfo>> fetchSkills(ConnectionProfile profile);
  Future<ConnectionCheckResult> testConnection(ConnectionProfile profile);
  Future<void> approveDevice(ConnectionProfile profile, String requestId);
  Future<void> rejectDevice(ConnectionProfile profile, String requestId);
  Future<void> removeTrustedDevice(
    ConnectionProfile profile,
    DeviceInfo device,
  );
  Future<void> setSkillInput(
    ConnectionProfile profile,
    SkillInfo skill,
    String value,
  );
  Future<List<ChatMessage>> fetchChatHistory(
    ConnectionProfile profile, {
    String sessionKey = 'main',
  });
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation, {
    String sessionKey = 'main',
    List<ChatAttachment> attachments = const <ChatAttachment>[],
    void Function(String accumulated)? onStreamChunk,
  });

  /// Continuous stream of raw gateway event frames. Auto-reconnects on drop.
  /// Emits `{type:'event', event:'chat.message'|'chat.reply'|..., payload:{...}}`.
  Stream<Map<String, dynamic>> watchGatewayEvents(ConnectionProfile profile);
}

class OpenClawRepositoryRouter implements OpenClawRepository {
  OpenClawRepositoryRouter({
    required OpenClawRepository fallback,
    OpenClawRepository? network,
  }) : _fallback = fallback,
       _network = network;

  final OpenClawRepository _fallback;
  final OpenClawRepository? _network;

  @override
  Future<void> approveDevice(
    ConnectionProfile profile,
    String requestId,
  ) async {
    if (_shouldUseFallback(profile)) {
      return;
    }
    return _network!.approveDevice(profile, requestId);
  }

  @override
  Future<void> removeTrustedDevice(
    ConnectionProfile profile,
    DeviceInfo device,
  ) async {
    if (_shouldUseFallback(profile)) {
      return;
    }
    return _network!.removeTrustedDevice(profile, device);
  }

  @override
  Future<OperatorSnapshot> fetchOverview(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchOverview(profile);
    }
    return _network!.fetchOverview(profile);
  }

  @override
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchDevices(profile);
    }
    return _network!.fetchDevices(profile);
  }

  @override
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchCronJobs(profile);
    }
    return _network!.fetchCronJobs(profile);
  }

  @override
  Future<List<CronRun>> fetchCronRuns(
    ConnectionProfile profile, {
    required String jobId,
  }) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchCronRuns(profile, jobId: jobId);
    }
    return _network!.fetchCronRuns(profile, jobId: jobId);
  }

  @override
  Future<List<SkillInfo>> fetchSkills(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchSkills(profile);
    }
    return _network!.fetchSkills(profile);
  }

  @override
  Future<void> rejectDevice(ConnectionProfile profile, String requestId) async {
    if (_shouldUseFallback(profile)) {
      return;
    }
    return _network!.rejectDevice(profile, requestId);
  }

  @override
  Future<void> setSkillInput(
    ConnectionProfile profile,
    SkillInfo skill,
    String value,
  ) async {
    if (_shouldUseFallback(profile)) {
      return;
    }
    return _network!.setSkillInput(profile, skill, value);
  }

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation, {
    String sessionKey = 'main',
    List<ChatAttachment> attachments = const <ChatAttachment>[],
    void Function(String accumulated)? onStreamChunk,
  }) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.sendMessage(
        profile,
        message,
        conversation,
        sessionKey: sessionKey,
        attachments: attachments,
        onStreamChunk: onStreamChunk,
      );
    }
    return _network!.sendMessage(
      profile,
      message,
      conversation,
      sessionKey: sessionKey,
      attachments: attachments,
      onStreamChunk: onStreamChunk,
    );
  }

  @override
  Future<List<ChatMessage>> fetchChatHistory(
    ConnectionProfile profile, {
    String sessionKey = 'main',
  }) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchChatHistory(profile, sessionKey: sessionKey);
    }
    return _network!.fetchChatHistory(profile, sessionKey: sessionKey);
  }

  @override
  Stream<Map<String, dynamic>> watchGatewayEvents(ConnectionProfile profile) {
    if (_shouldUseFallback(profile)) {
      return _fallback.watchGatewayEvents(profile);
    }
    return _network!.watchGatewayEvents(profile);
  }

  @override
  Future<ConnectionCheckResult> testConnection(
    ConnectionProfile profile,
  ) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.testConnection(profile);
    }
    try {
      return await _network!.testConnection(profile);
    } catch (_) {
      return const ConnectionCheckResult(
        reachable: false,
        authenticated: false,
        ready: false,
        latencyMs: 0,
        message: 'Connection test failed before the gateway replied.',
      );
    }
  }

  bool _shouldUseFallback(ConnectionProfile profile) {
    return profile.demoMode || _network == null;
  }
}

class DemoOpenClawRepository implements OpenClawRepository {
  @override
  Future<void> approveDevice(
    ConnectionProfile profile,
    String requestId,
  ) async {}

  @override
  Future<void> removeTrustedDevice(
    ConnectionProfile profile,
    DeviceInfo device,
  ) async {}

  @override
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile) async {
    return (await fetchOverview(profile)).cronJobs;
  }

  @override
  Future<List<CronRun>> fetchCronRuns(
    ConnectionProfile profile, {
    required String jobId,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return <CronRun>[
      CronRun(
        id: '${jobId}-run-1',
        startedAtLabel: '4m ago',
        status: CronRunStatus.ok,
        durationLabel: '2s',
        deliveryLabel: 'Announced',
        summary: 'Delivered the scheduled operator summary.',
      ),
      CronRun(
        id: '${jobId}-run-2',
        startedAtLabel: '1h ago',
        status: CronRunStatus.ok,
        durationLabel: '1s',
        deliveryLabel: 'Announced',
      ),
      CronRun(
        id: '${jobId}-run-3',
        startedAtLabel: '2h ago',
        status: CronRunStatus.skipped,
        durationLabel: '0s',
        deliveryLabel: 'Not requested',
        summary: 'Skipped because another run was already active.',
      ),
    ];
  }

  @override
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile) async {
    return (await fetchOverview(profile)).devices;
  }

  @override
  Future<List<SkillInfo>> fetchSkills(ConnectionProfile profile) async {
    return (await fetchOverview(profile)).skills;
  }

  @override
  Future<OperatorSnapshot> fetchOverview(ConnectionProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    const List<DeviceInfo> devices = <DeviceInfo>[
      DeviceInfo(
        name: 'Pixel 9 Pro',
        platform: 'Android',
        status: 'Trusted',
        lastSeen: 'Now',
      ),
      DeviceInfo(
        name: 'Field iPhone',
        platform: 'iOS',
        status: 'Pending approval',
        lastSeen: '1m ago',
        pendingApproval: true,
        requestId: 'demo-request-1',
      ),
      DeviceInfo(
        name: 'Galaxy Tab Relay',
        platform: 'Android',
        status: 'Trusted',
        lastSeen: '18m ago',
      ),
    ];
    const List<CronJob> cronJobs = <CronJob>[
      CronJob(
        id: 'inventory-sync',
        name: 'inventory-sync',
        schedule: '*/15 * * * *',
        nextRun: '12m',
        lastRun: '3m ago',
        health: JobHealth.healthy,
      ),
      CronJob(
        id: 'tailnet-prune',
        name: 'tailnet-prune',
        schedule: '0 */6 * * *',
        nextRun: '2h',
        lastRun: '4h ago',
        health: JobHealth.warning,
      ),
      CronJob(
        id: 'rebuild-embeddings',
        name: 'rebuild-embeddings',
        schedule: '30 2 * * *',
        nextRun: 'Tonight 02:30',
        lastRun: '1d ago',
        health: JobHealth.stalled,
      ),
    ];
    return OperatorSnapshot(
      connectionCheck: const ConnectionCheckResult(
        reachable: true,
        authenticated: true,
        ready: true,
        latencyMs: 42,
        message: 'Demo mode active. Live gateway calls are bypassed.',
      ),
      dashboard: DashboardSnapshot(
        gatewayStatus: const GatewayStatus(
          online: true,
          authenticated: true,
          version: 'OpenClaw Gateway surfaces',
          latencyMs: 42,
          activeSessions: 7,
          connectedDevices: 5,
          pendingApprovals: 1,
          runningJobs: 4,
        ),
        sessions: <SessionInfo>[
          SessionInfo(
            key: 'deploy-staging-rollback',
            title: 'Deploy staging rollback',
            updatedAgo: 'Updated 3m ago',
            state: 'Running',
            updatedAtMs: DateTime.now()
                .subtract(const Duration(minutes: 3))
                .millisecondsSinceEpoch,
          ),
          SessionInfo(
            key: 'investigate-gpu-node-drift',
            title: 'Investigate GPU node drift',
            updatedAgo: 'Updated 14m ago',
            state: 'Needs review',
            updatedAtMs: DateTime.now()
                .subtract(const Duration(minutes: 14))
                .millisecondsSinceEpoch,
          ),
          SessionInfo(
            key: 'nightly-summary',
            title: 'Nightly summary',
            updatedAgo: 'Updated 48m ago',
            state: 'Idle',
            updatedAtMs: DateTime.now()
                .subtract(const Duration(minutes: 48))
                .millisecondsSinceEpoch,
          ),
        ],
        connectedDevices: devices
            .where((DeviceInfo item) => !item.pendingApproval)
            .toList(),
        cronSummary: const CronSummary(
          totalJobs: 9,
          overdueJobs: 1,
          nextRunLabel: 'Inventory sync in 12m',
        ),
        skills: const <SkillInfo>[
          SkillInfo(
            name: 'web-search',
            status: 'Enabled',
            detail: 'API key configured',
            group: 'Built-in',
          ),
          SkillInfo(
            name: 'calendar',
            status: 'Blocked',
            detail: 'Missing provider credentials',
            group: 'Installed',
          ),
        ],
      ),
      devices: devices,
      cronJobs: cronJobs,
      skills: const <SkillInfo>[
        SkillInfo(
          name: 'web-search',
          status: 'Enabled',
          detail: 'API key configured',
          group: 'Built-in',
        ),
        SkillInfo(
          name: 'calendar',
          status: 'Blocked',
          detail: 'Missing provider credentials',
          group: 'Installed',
        ),
      ],
    );
  }

  @override
  Future<void> rejectDevice(
    ConnectionProfile profile,
    String requestId,
  ) async {}

  @override
  Future<void> setSkillInput(
    ConnectionProfile profile,
    SkillInfo skill,
    String value,
  ) async {}

  @override
  Future<List<ChatMessage>> fetchChatHistory(
    ConnectionProfile profile, {
    String sessionKey = 'main',
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const <ChatMessage>[
      ChatMessage(
        role: MessageRole.assistant,
        content:
            'ClawUI is ready. Ask for gateway status, sessions, devices, cron, or skills.',
        timestampLabel: 'now',
      ),
    ];
  }

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation, {
    String sessionKey = 'main',
    List<ChatAttachment> attachments = const <ChatAttachment>[],
    void Function(String accumulated)? onStreamChunk,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final String response = message.toLowerCase().contains('status')
        ? 'Gateway healthy. Sessions and devices are being served from the demo adapter.'
        : message.toLowerCase().contains('approve')
        ? 'Device approval wiring is ready for the live gateway. Demo mode does not mutate anything.'
        : 'Demo assistant is using the same repository abstraction as the live OpenClaw gateway surfaces.';
    return ChatMessage(
      role: MessageRole.assistant,
      content: response,
      timestampLabel: 'now',
    );
  }

  @override
  Stream<Map<String, dynamic>> watchGatewayEvents(ConnectionProfile profile) =>
      const Stream<Map<String, dynamic>>.empty();

  @override
  Future<ConnectionCheckResult> testConnection(
    ConnectionProfile profile,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    return const ConnectionCheckResult(
      reachable: true,
      authenticated: true,
      ready: true,
      latencyMs: 0,
      message: 'Demo mode enabled. Live network validation was skipped.',
    );
  }
}

class NetworkOpenClawRepository implements OpenClawRepository {
  NetworkOpenClawRepository(
    this._client, {
    GatewayWsClient? wsClient,
    GatewayDeviceAuthStore? deviceAuthStore,
  }) : _wsClient = wsClient ?? createGatewayWsClient(),
       _deviceAuthStore = deviceAuthStore ?? GatewayDeviceAuthStore();

  final OpenClawApiClient _client;
  final GatewayWsClient _wsClient;
  final GatewayDeviceAuthStore _deviceAuthStore;

  @override
  Future<void> approveDevice(
    ConnectionProfile profile,
    String requestId,
  ) async {
    await _callRpc(profile, 'device.pair.approve', <String, dynamic>{
      'requestId': requestId,
    });
  }

  @override
  Future<OperatorSnapshot> fetchOverview(ConnectionProfile profile) async {
    final Future<ConnectionCheckResult> connectionFuture = testConnection(
      profile,
    ).timeout(const Duration(seconds: 10));
    final ConnectionCheckResult connection = await connectionFuture;
    final GatewayHelloSnapshot? helloSnapshot = await _loadHelloSnapshot(
      profile,
    ).timeout(const Duration(seconds: 8), onTimeout: () => null);
    final String statusVersion =
        helloSnapshot?.serverVersion ??
        helloSnapshot?.healthVersion ??
        'OpenClaw Gateway';
    final _GatewayData gatewayData = await _loadGatewayData(
      profile,
      helloSnapshot,
    );

    return OperatorSnapshot(
      connectionCheck: connection,
      approvalRequired: gatewayData.approvalRequired,
      approvalMessage: gatewayData.approvalMessage,
      dashboard: DashboardSnapshot(
        gatewayStatus: GatewayStatus(
          online: connection.reachable,
          authenticated: connection.authenticated,
          version: statusVersion,
          latencyMs: connection.latencyMs,
          activeSessions: gatewayData.sessions.length,
          connectedDevices: gatewayData.devices
              .where((DeviceInfo item) => !item.pendingApproval)
              .length,
          pendingApprovals: gatewayData.devices
              .where((DeviceInfo item) => item.pendingApproval)
              .length,
          runningJobs: gatewayData.cronJobs.length,
        ),
        sessions: gatewayData.sessions,
        connectedDevices: gatewayData.devices
            .where((DeviceInfo item) => !item.pendingApproval)
            .toList(),
        cronSummary: CronSummary(
          totalJobs: gatewayData.cronJobs.length,
          overdueJobs: gatewayData.cronJobs
              .where((CronJob job) => job.health != JobHealth.healthy)
              .length,
          nextRunLabel: gatewayData.cronJobs.isEmpty
              ? 'Open the Cron tab to load jobs'
              : _resolveNextRunLabel(gatewayData.cronJobs),
        ),
        skills: gatewayData.skills,
      ),
      devices: gatewayData.devices,
      cronJobs: gatewayData.cronJobs,
      skills: gatewayData.skills,
    );
  }

  @override
  Future<void> rejectDevice(ConnectionProfile profile, String requestId) async {
    await _callRpc(profile, 'device.pair.reject', <String, dynamic>{
      'requestId': requestId,
    });
  }

  @override
  Future<void> removeTrustedDevice(
    ConnectionProfile profile,
    DeviceInfo device,
  ) async {
    final String? deviceId = device.deviceId;
    if (deviceId == null || deviceId.trim().isEmpty) {
      throw const OpenClawApiException(
        'This device entry does not include a removable device ID.',
        400,
      );
    }
    try {
      await _callRpc(profile, 'device.remove', <String, dynamic>{
        'deviceId': deviceId,
      });
    } on OpenClawApiException {
      await _callRpc(profile, 'device.token.revoke', <String, dynamic>{
        'deviceId': deviceId,
        'role': device.role,
      });
    }
  }

  @override
  Future<void> setSkillInput(
    ConnectionProfile profile,
    SkillInfo skill,
    String value,
  ) async {
    final String? inputPath = skill.inputPath?.trim();
    if (inputPath == null || inputPath.isEmpty) {
      throw const OpenClawApiException(
        'No configurable input path was found for this skill.',
        400,
      );
    }
    final Map<String, dynamic> current = await _callRpc(
      profile,
      'config.get',
      const <String, dynamic>{},
    );
    final Map<String, dynamic> details = _unwrapGatewayResult(current);
    final String? baseHash =
        details['baseHash'] as String? ?? details['hash'] as String?;
    await _callRpc(profile, 'config.patch', <String, dynamic>{
      'baseHash': baseHash,
      'patch': _buildConfigPatch(inputPath, value),
      'note': 'Updated from ClawUI for ${skill.displayName}',
    });
  }

  @override
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile) async {
    try {
      final Map<String, dynamic> devicesPayload = await _callRpc(
        profile,
        'device.pair.list',
        const <String, dynamic>{},
      );
      Map<String, dynamic> nodesPayload = const <String, dynamic>{};
      try {
        nodesPayload = await _callRpc(
          profile,
          'node.list',
          const <String, dynamic>{},
        );
      } on OpenClawApiException {
        nodesPayload = const <String, dynamic>{};
      }
      return _mergeDevices(
        _parsePairingDevices(devicesPayload),
        _parseNodeDevices(nodesPayload),
      );
    } on OpenClawApiException {
      final GatewayHelloSnapshot? helloSnapshot = await _loadHelloSnapshot(
        profile,
      );
      return helloSnapshot?.presenceDevices ?? const <DeviceInfo>[];
    }
  }

  @override
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile) async {
    try {
      final Map<String, dynamic> cronPayload = await _callRpc(
        profile,
        'cron.list',
        <String, dynamic>{'includeDisabled': true, 'limit': 100, 'offset': 0},
      );
      return _parseCronJobs(cronPayload);
    } on OpenClawApiException {
      final GatewayHelloSnapshot? helloSnapshot = await _loadHelloSnapshot(
        profile,
      );
      return helloSnapshot?.cronFallbackJobs ?? const <CronJob>[];
    }
  }

  @override
  Future<List<CronRun>> fetchCronRuns(
    ConnectionProfile profile, {
    required String jobId,
  }) async {
    try {
      final Map<String, dynamic> payload = await _callRpc(
        profile,
        'cron.runs',
        <String, dynamic>{'jobId': jobId, 'limit': 20},
      );
      return _parseCronRuns(payload);
    } on OpenClawApiException {
      final Map<String, dynamic> payload = await _client.invokeTool(
        profile,
        'cron',
        <String, dynamic>{'action': 'runs', 'jobId': jobId},
      );
      return _parseCronRuns(payload);
    }
  }

  @override
  Future<List<SkillInfo>> fetchSkills(ConnectionProfile profile) async {
    try {
      final Map<String, dynamic> skillsPayload = await _callRpc(
        profile,
        'skills.status',
        const <String, dynamic>{},
      );
      return _parseSkills(skillsPayload);
    } on OpenClawApiException {
      final GatewayHelloSnapshot? helloSnapshot = await _loadHelloSnapshot(
        profile,
      );
      return helloSnapshot?.skillsFallback ?? const <SkillInfo>[];
    }
  }

  @override
  Stream<Map<String, dynamic>> watchGatewayEvents(ConnectionProfile profile) =>
      _gatewayEventStream(profile);

  /// Auto-reconnecting stream of raw gateway event frames.
  Stream<Map<String, dynamic>> _gatewayEventStream(
    ConnectionProfile profile,
  ) async* {
    if (kIsWeb) return;
    while (true) {
      try {
        final String key = _scopeKey(profile.websocketUri);
        final GatewayLiveSession session = await GatewaySessionPool.instance
            .acquire(
              key,
              profile.websocketUri,
              (GatewayWsChallenge c) => _buildConnectPayload(profile, c),
            )
            .timeout(const Duration(seconds: 15));
        await for (final Map<String, dynamic> event in session.events) {
          yield event;
        }
      } catch (_) {
        // Session dropped or connect failed — wait then retry.
      }
      await Future<void>.delayed(const Duration(seconds: 3));
    }
  }

  @override
  Future<List<ChatMessage>> fetchChatHistory(
    ConnectionProfile profile, {
    String sessionKey = 'main',
  }) async {
    final Map<String, dynamic> history = await _callRpc(
      profile,
      'chat.history',
      <String, dynamic>{'sessionKey': sessionKey, 'limit': 40},
    );
    final Map<String, dynamic> details = _unwrapGatewayResult(history);
    final List<dynamic> messages = _readList(details['messages']);
    final List<ChatMessage> parsed = messages
        .whereType<Map<String, dynamic>>()
        .map(_toChatMessage)
        .whereType<ChatMessage>()
        .toList();
    if (parsed.isNotEmpty) {
      return parsed;
    }
    return const <ChatMessage>[
      ChatMessage(
        role: MessageRole.assistant,
        content:
            'ClawUI is ready. Ask for gateway status, sessions, devices, cron, or skills.',
        timestampLabel: 'now',
      ),
    ];
  }

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation, {
    String sessionKey = 'main',
    List<ChatAttachment> attachments = const <ChatAttachment>[],
    void Function(String accumulated)? onStreamChunk,
  }) async {
    // Record how many assistant messages exist BEFORE we send, so we can
    // detect only the NEW reply rather than matching an old one.
    final int existingAssistantCount = conversation
        .where((ChatMessage m) => m.role == MessageRole.assistant)
        .length;

    // ── Streaming path (IO platforms with persistent session) ──────────────
    // CRITICAL: subscribe to events BEFORE sending chat.send, otherwise early
    // events emitted during the RPC's round-trip are lost on the broadcast stream.
    if (!kIsWeb && onStreamChunk != null) {
      try {
        final String key = _scopeKey(profile.websocketUri);
        final GatewayLiveSession session = await GatewaySessionPool.instance
            .acquire(
              key,
              profile.websocketUri,
              (GatewayWsChallenge challenge) =>
                  _buildConnectPayload(profile, challenge),
            )
            .timeout(const Duration(seconds: 15));

        final StringBuffer buf = StringBuffer();
        bool streamDone = false;
        final StreamSubscription<Map<String, dynamic>> sub = session.events
            .listen((Map<String, dynamic> event) {
              final String eventName = event['event'] as String? ?? '';
              if (eventName == 'chat.stream' ||
                  eventName == 'chat.reply' ||
                  eventName == 'chat.message') {
                final Map<String, dynamic> payload =
                    event['payload'] as Map<String, dynamic>? ??
                    <String, dynamic>{};
                final String role = payload['role'] as String? ?? '';
                if (role == 'assistant' || role.isEmpty) {
                  final String delta = payload['delta'] as String? ?? '';
                  final String full =
                      _extractTextContent(
                        payload['text'] ?? payload['content'],
                      ) ??
                      '';
                  if (delta.isNotEmpty) {
                    buf.write(delta);
                    onStreamChunk(buf.toString());
                  } else if (full.isNotEmpty) {
                    onStreamChunk(full);
                  }
                  if (payload['done'] as bool? ?? false) {
                    streamDone = true;
                  }
                }
              }
            });

        // Send AFTER subscribing so no events are missed.
        // Only include 'message' when non-empty — gateway rejects empty strings.
        final GatewayWsResponse sendResp = await session
            .rpc('chat.send', <String, dynamic>{
              'sessionKey': sessionKey,
              if (message.isNotEmpty) 'message': message,
              if (attachments.isNotEmpty)
                'attachment': attachments
                    .map((ChatAttachment a) => a.toJson())
                    .toList(),
              'deliver': false,
              'idempotencyKey': DateTime.now().millisecondsSinceEpoch
                  .toString(),
            })
            .timeout(const Duration(seconds: 30));

        if (!sendResp.ok) {
          await sub.cancel();
          throw OpenClawApiException(
            sendResp.errorMessage ?? 'chat.send failed',
            403,
          );
        }
        await _saveDeviceToken(profile, sendResp.payload);

        // Give the gateway up to 3 s to start pushing events.
        // If nothing arrives in that window, this gateway doesn't push stream
        // events — cancel and fall through to polling immediately.
        int coldWaits = 0;
        while (!streamDone && buf.isEmpty && coldWaits < 15) {
          await Future<void>.delayed(const Duration(milliseconds: 200));
          coldWaits++;
        }
        if (buf.isEmpty) {
          await sub.cancel();
          // Fall through to polling
        } else {
          // Events are flowing — wait up to 90 s for completion.
          int waits = 0;
          while (!streamDone && waits < 450) {
            await Future<void>.delayed(const Duration(milliseconds: 200));
            waits++;
          }
          await sub.cancel();
          final String accumulated = buf.toString().trim();
          if (accumulated.isNotEmpty) {
            return ChatMessage(
              role: MessageRole.assistant,
              content: accumulated,
              timestampLabel: 'now',
            );
          }
          // Fall through to polling if stream ended with empty content
        }
      } catch (e) {
        if (e is OpenClawApiException) rethrow;
        // Session error — fall through to polling path
      }
    } else {
      // No streaming — just send the message and let polling pick up the reply.
      await _callRpc(profile, 'chat.send', <String, dynamic>{
        'sessionKey': sessionKey,
        if (message.isNotEmpty) 'message': message,
        if (attachments.isNotEmpty)
          'attachment': attachments
              .map((ChatAttachment a) => a.toJson())
              .toList(),
        'deliver': false,
        'idempotencyKey': DateTime.now().millisecondsSinceEpoch.toString(),
      });
    }

    // ── Polling path ────────────────────────────────────────────────────────
    // Poll for a NEW assistant reply (strictly more than before we sent).
    const int maxAttempts = 150; // 150 × 400 ms = 60 s
    const Duration pollInterval = Duration(milliseconds: 400);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      await Future<void>.delayed(pollInterval);
      try {
        final List<ChatMessage> history = await fetchChatHistory(
          profile,
          sessionKey: sessionKey,
        );
        final List<ChatMessage> assistantMsgs = history
            .where((ChatMessage m) => m.role == MessageRole.assistant)
            .toList();
        if (assistantMsgs.length > existingAssistantCount &&
            assistantMsgs.last.content.trim().isNotEmpty) {
          final ChatMessage newest = assistantMsgs.last;
          onStreamChunk?.call(newest.content);
          return newest;
        }
      } catch (_) {
        // Network hiccup during poll — continue trying
      }
    }

    throw const OpenClawApiException(
      'Chat request was sent, but no assistant reply arrived within 60 seconds.',
      504,
    );
  }

  static String? _extractTextContent(dynamic content) {
    if (content is String)
      return content.trim().isEmpty ? null : content.trim();
    if (content is List) {
      for (final dynamic item in content) {
        if (item is Map<String, dynamic>) {
          final String? text = item['text'] as String?;
          if (text != null && text.trim().isNotEmpty) return text.trim();
        }
      }
    }
    return null;
  }

  @override
  Future<ConnectionCheckResult> testConnection(
    ConnectionProfile profile,
  ) async {
    final ProbeResponse probe = await _client.probe(profile);
    return ConnectionCheckResult(
      reachable: probe.reachable,
      authenticated: probe.authenticated,
      ready: probe.ready,
      latencyMs: probe.latencyMs,
      httpStatusCode: probe.statusCode,
      message: probe.message,
      checkedAt: DateTime.now(),
    );
  }

  List<CronJob> _parseCronJobs(Map<String, dynamic> payload) {
    final Map<String, dynamic> details = _unwrapGatewayResult(payload);
    final List<dynamic> rawJobs = _readList(details['jobs']);
    return rawJobs.map((dynamic item) {
      final Map<String, dynamic> job = item as Map<String, dynamic>;
      final Map<String, dynamic> schedule =
          job['schedule'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final Map<String, dynamic> state =
          job['state'] as Map<String, dynamic>? ?? <String, dynamic>{};
      final String lastStatus = (state['lastStatus'] as String? ?? '')
          .trim()
          .toLowerCase();
      return CronJob(
        id:
            (job['jobId'] as String? ??
                    job['id'] as String? ??
                    job['name'] as String? ??
                    'cron-job')
                .trim(),
        name: (job['name'] as String? ?? job['id'] as String? ?? 'cron-job')
            .trim(),
        schedule: _formatSchedule(schedule),
        nextRun: _formatTimestamp(
          _readInt(job['nextRunAtMs']) ?? _readInt(state['nextRunAtMs']),
        ),
        lastRun: _formatTimestamp(_readInt(state['lastRunAtMs'])),
        health: switch (lastStatus) {
          'ok' || 'healthy' || 'success' => JobHealth.healthy,
          'failed' || 'error' => JobHealth.stalled,
          _ => JobHealth.warning,
        },
      );
    }).toList();
  }

  List<CronRun> _parseCronRuns(Map<String, dynamic> payload) {
    final Map<String, dynamic> details = _unwrapGatewayResult(payload);
    final List<dynamic> rawRuns = _readList(details['runs']);
    return rawRuns.map((dynamic item) {
      final Map<String, dynamic> run = item as Map<String, dynamic>;
      final String statusRaw =
          (run['status'] as String? ?? run['lastStatus'] as String? ?? '')
              .trim()
              .toLowerCase();
      final Map<String, dynamic> delivery = _readMap(
        run['delivery'] ?? run['deliveryStatus'],
      );
      final int? startedAt =
          _readInt(run['startedAtMs']) ??
          _readInt(run['ts']) ??
          _readInt(run['createdAtMs']) ??
          _readInt(run['runAtMs']);
      final int? durationMs =
          _readInt(run['durationMs']) ?? _readInt(run['elapsedMs']);
      final String summaryRaw =
          (run['summary'] as String? ?? run['message'] as String? ?? '').trim();
      return CronRun(
        id: (run['runId'] as String? ?? run['id'] as String? ?? '$startedAt')
            .trim(),
        startedAtLabel: _formatTimestamp(startedAt),
        status: switch (statusRaw) {
          'ok' || 'success' => CronRunStatus.ok,
          'error' || 'failed' => CronRunStatus.error,
          'skipped' => CronRunStatus.skipped,
          _ => CronRunStatus.unknown,
        },
        durationLabel: _formatDuration(durationMs),
        deliveryLabel: _resolveDeliveryLabel(delivery, run),
        summary: summaryRaw.isEmpty ? null : summaryRaw,
      );
    }).toList();
  }

  List<DeviceInfo> _parseDevices(
    Map<String, dynamic> nodesPayload,
    Map<String, dynamic> pendingPayload,
  ) {
    final List<DeviceInfo> devices = <DeviceInfo>[];
    final Map<String, dynamic> nodesDetails = _unwrapGatewayResult(
      nodesPayload,
    );
    final Map<String, dynamic> pendingDetails = _unwrapGatewayResult(
      pendingPayload,
    );
    final List<dynamic> rawNodes = _readList(nodesDetails['nodes']);
    for (final dynamic item in rawNodes) {
      final Map<String, dynamic> node = item as Map<String, dynamic>;
      devices.add(
        DeviceInfo(
          name:
              (node['displayName'] as String? ??
                      node['name'] as String? ??
                      node['nodeId'] as String? ??
                      'Node')
                  .trim(),
          platform:
              (node['platform'] as String? ??
                      node['deviceFamily'] as String? ??
                      'Unknown')
                  .trim(),
          status: (node['connected'] as bool? ?? true) ? 'Trusted' : 'Offline',
          lastSeen: _formatTimestamp(_readInt(node['lastSeenAtMs'])),
        ),
      );
    }

    final List<dynamic> pending = _readList(pendingDetails['pending']);
    for (final dynamic item in pending) {
      final Map<String, dynamic> request = item as Map<String, dynamic>;
      devices.add(
        DeviceInfo(
          name:
              (request['displayName'] as String? ??
                      request['deviceId'] as String? ??
                      'Pending device')
                  .trim(),
          platform:
              (request['platform'] as String? ??
                      request['deviceFamily'] as String? ??
                      'Unknown')
                  .trim(),
          status: 'Pending approval',
          lastSeen: _formatTimestamp(_readInt(request['ts'])),
          pendingApproval: true,
          requestId: request['requestId'] as String?,
        ),
      );
    }
    return devices;
  }

  List<SessionInfo> _parseSessions(
    Map<String, dynamic> payload,
    GatewayHelloSnapshot? helloSnapshot,
  ) {
    final Map<String, dynamic> details = _unwrapGatewayResult(payload);
    final List<dynamic> rawSessions = _readList(details['sessions']);
    final List<SessionInfo> sessions = rawSessions.map((dynamic item) {
      final Map<String, dynamic> session = item as Map<String, dynamic>;
      final String label =
          (session['label'] as String? ??
                  session['displayName'] as String? ??
                  session['key'] as String? ??
                  'Session')
              .trim();
      final String kind = (session['kind'] as String? ?? 'session').trim();
      return SessionInfo(
        key: (session['key'] as String? ?? label).trim(),
        title: label,
        updatedAgo: _formatTimestamp(_readInt(session['updatedAt'])),
        state: kind,
      );
    }).toList();
    if (sessions.isNotEmpty) {
      return sessions;
    }
    return helloSnapshot?.recentSessions
            .map(
              (GatewayRecentSession item) => SessionInfo(
                key: item.key,
                title: item.label,
                updatedAgo: _formatTimestamp(item.updatedAt),
                state: item.kind,
                updatedAtMs: item.updatedAt,
              ),
            )
            .toList() ??
        const <SessionInfo>[];
  }

  Future<_GatewayData> _loadGatewayData(
    ConnectionProfile profile,
    GatewayHelloSnapshot? helloSnapshot,
  ) async {
    final _GatewayData? wsData = await _loadWsGatewayData(profile);
    if (wsData != null) {
      return wsData;
    }

    try {
      final Map<String, dynamic> nodesPayload = await _client.invokeTool(
        profile,
        'nodes',
        <String, dynamic>{'action': 'status'},
      );
      final Map<String, dynamic> pendingPayload = await _client.invokeTool(
        profile,
        'nodes',
        <String, dynamic>{'action': 'pending'},
      );
      final Map<String, dynamic> cronStatusPayload = await _client.invokeTool(
        profile,
        'cron',
        <String, dynamic>{'action': 'status'},
      );
      final Map<String, dynamic> cronListPayload = await _client.invokeTool(
        profile,
        'cron',
        <String, dynamic>{'action': 'list', 'includeDisabled': true},
      );
      final Map<String, dynamic> cronStatusDetails = _unwrapGatewayResult(
        cronStatusPayload,
      );
      final Map<String, dynamic> sessionsPayload = await _client.invokeTool(
        profile,
        'sessions_list',
        <String, dynamic>{'limit': 12, 'messageLimit': 0},
      );
      return _GatewayData(
        sessions: _parseSessions(sessionsPayload, helloSnapshot),
        devices: _parseDevices(nodesPayload, pendingPayload),
        cronJobs: _parseCronJobs(cronListPayload),
        skills: const <SkillInfo>[],
        totalJobs: _readInt(cronStatusDetails['totalJobs']),
      );
    } on OpenClawApiException catch (error) {
      final bool insufficientScope =
          error.message.contains('missing scope:') ||
          error.message.contains('Tool not available');
      if (!insufficientScope) {
        rethrow;
      }
      return _GatewayData(
        sessions:
            helloSnapshot?.recentSessions
                .map(
                  (GatewayRecentSession item) => SessionInfo(
                    key: item.key,
                    title: item.label,
                    updatedAgo: _formatTimestamp(item.updatedAt),
                    state: item.kind,
                    updatedAtMs: item.updatedAt,
                  ),
                )
                .toList() ??
            const <SessionInfo>[],
        devices: helloSnapshot?.presenceDevices ?? const <DeviceInfo>[],
        cronJobs: helloSnapshot?.cronFallbackJobs ?? const <CronJob>[],
        skills: helloSnapshot?.skillsFallback ?? const <SkillInfo>[],
        totalJobs: helloSnapshot?.cronFallbackJobs.length,
      );
    }
  }

  Future<_GatewayData?> _loadWsGatewayData(ConnectionProfile profile) async {
    try {
      // Fire all five requests concurrently over the same persistent session.
      final List<Map<String, dynamic>> results = await Future.wait(
        <Future<Map<String, dynamic>>>[
          _callRpc(profile, 'sessions.list', <String, dynamic>{
            'includeGlobal': true,
            'includeUnknown': true,
            'limit': 20,
          }),
          _callRpc(profile, 'device.pair.list', const <String, dynamic>{}),
          _callRpcOrEmpty(profile, 'node.list', const <String, dynamic>{}),
          _callRpc(profile, 'cron.list', <String, dynamic>{
            'includeDisabled': true,
            'limit': 100,
            'offset': 0,
          }),
          _callRpcOrEmpty(profile, 'skills.status', const <String, dynamic>{}),
        ],
      );

      final Map<String, dynamic> sessionsPayload = results[0];
      final Map<String, dynamic> devicesPayload = results[1];
      final Map<String, dynamic> nodesPayload = results[2];
      final Map<String, dynamic> cronPayload = results[3];
      final Map<String, dynamic> skillsPayload = results[4];

      return _GatewayData(
        sessions: _parseWsSessions(sessionsPayload),
        devices: _mergeDevices(
          _parsePairingDevices(devicesPayload),
          _parseNodeDevices(nodesPayload),
        ),
        cronJobs: _parseCronJobs(cronPayload),
        skills: _parseSkills(skillsPayload),
        totalJobs:
            _readInt(cronPayload['total']) ??
            _readInt(cronPayload['count']) ??
            (cronPayload['jobs'] as List<dynamic>?)?.length,
      );
    } on OpenClawApiException catch (error) {
      final bool pairingRequired = _isApprovalRequiredMessage(error.message);
      if (!pairingRequired) {
        rethrow;
      }
      return const _GatewayData(
        sessions: <SessionInfo>[],
        devices: <DeviceInfo>[],
        cronJobs: <CronJob>[],
        skills: <SkillInfo>[],
        totalJobs: 0,
        approvalRequired: true,
        approvalMessage:
            'Approve this device in the OpenClaw UI before opening the operator shell.',
      );
    }
  }

  Future<GatewayHelloSnapshot?> _loadHelloSnapshot(
    ConnectionProfile profile,
  ) async {
    try {
      final GatewayWsConnectContext context = await _wsClient.connect(
        profile.websocketUri,
        buildConnect: (GatewayWsChallenge challenge) =>
            _buildConnectPayload(profile, challenge),
      );
      if (context.errorCode != null) {
        return null;
      }
      await _saveDeviceToken(profile, context.payload);
      return GatewayHelloSnapshot.fromPayload(context.payload);
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _buildConnectPayload(
    ConnectionProfile profile,
    GatewayWsChallenge challenge,
  ) async {
    final String scopeKey = _scopeKey(profile.websocketUri);
    final GatewayDeviceIdentity identity = await _deviceAuthStore
        .loadOrCreateIdentity(scopeKey);
    final GatewayDeviceToken? cachedToken = await _deviceAuthStore
        .loadDeviceToken(scopeKey);
    final List<String> scopes = <String>[
      'operator.read',
      'operator.write',
      'operator.admin',
      'operator.approvals',
      'operator.pairing',
    ];
    final Map<String, dynamic> auth = <String, dynamic>{};
    if (profile.authMode == AuthMode.token && profile.token.trim().isNotEmpty) {
      auth['token'] = profile.token.trim();
    } else if (profile.password.trim().isNotEmpty) {
      auth['password'] = profile.password.trim();
    }
    if (cachedToken != null && cachedToken.token.trim().isNotEmpty) {
      auth['deviceToken'] = cachedToken.token.trim();
    }

    final int signedAt =
        challenge.timestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final String tokenForSignature =
        (cachedToken?.token.trim().isNotEmpty ?? false)
        ? cachedToken!.token.trim()
        : (auth['token'] as String? ?? '');
    final String signaturePayload = <String>[
      'v2',
      identity.deviceId,
      'openclaw-android',
      'ui',
      'operator',
      scopes.join(','),
      '$signedAt',
      tokenForSignature,
      challenge.nonce ?? '',
    ].join('|');
    final String signature = await _deviceAuthStore.sign(
      identity,
      signaturePayload,
    );

    return <String, dynamic>{
      'minProtocol': 3,
      'maxProtocol': 3,
      'client': <String, dynamic>{
        'id': 'openclaw-android',
        'version': '0.1.0',
        'platform': 'android',
        'mode': 'ui',
        'instanceId': 'clawui-mobile',
      },
      'role': 'operator',
      'scopes': scopes,
      'auth': auth,
      'locale': 'en-US',
      'device': <String, dynamic>{
        'id': identity.deviceId,
        'publicKey': _deviceAuthStore.encodePublicKeyForWire(
          identity.publicKey,
        ),
        'signature': signature,
        'signedAt': signedAt,
        if (challenge.nonce != null) 'nonce': challenge.nonce,
      },
      'caps': const <String>['tool-events'],
    };
  }

  /// Like [_callRpc] but returns an empty map instead of throwing on error.
  Future<Map<String, dynamic>> _callRpcOrEmpty(
    ConnectionProfile profile,
    String method,
    Map<String, dynamic> params,
  ) async {
    try {
      return await _callRpc(profile, method, params);
    } on OpenClawApiException {
      return const <String, dynamic>{};
    }
  }

  Future<Map<String, dynamic>> _callRpc(
    ConnectionProfile profile,
    String method,
    Map<String, dynamic> params,
  ) async {
    if (!kIsWeb) {
      return _callRpcSession(profile, method, params);
    }
    return _callRpcDirect(profile, method, params);
  }

  Future<Map<String, dynamic>> _callRpcSession(
    ConnectionProfile profile,
    String method,
    Map<String, dynamic> params,
  ) async {
    final String key = _scopeKey(profile.websocketUri);
    try {
      final GatewayLiveSession session = await GatewaySessionPool.instance
          .acquire(
            key,
            profile.websocketUri,
            (GatewayWsChallenge challenge) =>
                _buildConnectPayload(profile, challenge),
          )
          .timeout(const Duration(seconds: 15));

      GatewayWsResponse response = await session.rpc(method, params);
      if (!response.ok && _shouldRetryDeviceAuth(response)) {
        await _deviceAuthStore.clearDeviceToken(key);
        GatewaySessionPool.instance.invalidate(key);
        final GatewayLiveSession retry = await GatewaySessionPool.instance
            .acquire(
              key,
              profile.websocketUri,
              (GatewayWsChallenge challenge) =>
                  _buildConnectPayload(profile, challenge),
            )
            .timeout(const Duration(seconds: 15));
        response = await retry.rpc(method, params);
      }
      if (!response.ok) {
        throw OpenClawApiException(
          response.errorMessage ?? 'Request failed.',
          403,
        );
      }
      await _saveDeviceToken(profile, response.payload);
      return response.payload;
    } on StateError {
      // Session disconnected mid-request — invalidate and fall back to per-call WS.
      GatewaySessionPool.instance.invalidate(key);
      return _callRpcDirect(profile, method, params);
    }
  }

  Future<Map<String, dynamic>> _callRpcDirect(
    ConnectionProfile profile,
    String method,
    Map<String, dynamic> params,
  ) async {
    GatewayWsResponse response = await _wsClient.request(
      profile.websocketUri,
      buildConnect: (GatewayWsChallenge challenge) =>
          _buildConnectPayload(profile, challenge),
      method: method,
      params: params,
    );
    if (!response.ok && _shouldRetryDeviceAuth(response)) {
      await _deviceAuthStore.clearDeviceToken(_scopeKey(profile.websocketUri));
      response = await _wsClient.request(
        profile.websocketUri,
        buildConnect: (GatewayWsChallenge challenge) =>
            _buildConnectPayload(profile, challenge),
        method: method,
        params: params,
      );
    }
    if (!response.ok) {
      throw OpenClawApiException(
        response.errorMessage ?? 'Gateway WS request failed.',
        403,
      );
    }
    await _saveDeviceToken(profile, response.payload);
    return response.payload;
  }

  bool _shouldRetryDeviceAuth(GatewayWsResponse response) {
    final String code = (response.errorCode ?? '').trim().toLowerCase();
    final String message = (response.errorMessage ?? '').trim().toLowerCase();
    return code.contains('device_token_invalid') ||
        message.contains('device token invalid') ||
        message.contains('device token mismatch');
  }

  Future<void> _saveDeviceToken(
    ConnectionProfile profile,
    Map<String, dynamic> payload,
  ) async {
    final Map<String, dynamic> auth = _readMap(
      payload['auth'] ?? _unwrapGatewayResult(payload)['auth'],
    );
    final String token = auth['deviceToken'] as String? ?? '';
    if (token.trim().isEmpty) {
      return;
    }
    await _deviceAuthStore.saveDeviceToken(
      _scopeKey(profile.websocketUri),
      GatewayDeviceToken(
        token: token.trim(),
        role: auth['role'] as String? ?? 'operator',
        scopes: _readList(
          auth['scopes'],
        ).map((dynamic item) => item.toString()).toList(),
      ),
    );
  }

  List<SessionInfo> _parseWsSessions(Map<String, dynamic> payload) {
    final Map<String, dynamic> details = _unwrapGatewayResult(payload);
    final List<dynamic> rawSessions = _readList(
      details['sessions'] ?? details['items'],
    );
    return rawSessions.map((dynamic item) {
      final Map<String, dynamic> session = item as Map<String, dynamic>;
      final int? updatedAtMs =
          _readInt(session['updatedAt']) ??
          _readInt(session['updatedAtMs']) ??
          _readInt(session['lastMessageAt']) ??
          _readInt(session['lastMessageAtMs']);
      return SessionInfo(
        key:
            (session['key'] as String? ??
                    session['sessionKey'] as String? ??
                    session['id'] as String? ??
                    titleFromSession(session))
                .trim(),
        title: titleFromSession(session),
        updatedAgo: _formatTimestamp(updatedAtMs),
        state:
            (session['kind'] as String? ??
                    session['state'] as String? ??
                    session['status'] as String? ??
                    'session')
                .trim(),
        updatedAtMs: updatedAtMs,
      );
    }).toList();
  }

  String titleFromSession(Map<String, dynamic> session) {
    return (session['label'] as String? ??
            session['title'] as String? ??
            session['displayName'] as String? ??
            session['key'] as String? ??
            'Session')
        .trim();
  }

  List<DeviceInfo> _parsePairingDevices(Map<String, dynamic> payload) {
    final List<DeviceInfo> devices = <DeviceInfo>[];
    final Map<String, dynamic> details = _unwrapGatewayResult(payload);
    final List<dynamic> pending = _readList(details['pending']);
    final List<dynamic> paired = _readList(details['paired']);
    for (final dynamic item in pending) {
      final Map<String, dynamic> device = item as Map<String, dynamic>;
      devices.add(
        DeviceInfo(
          name:
              (device['displayName'] as String? ??
                      device['name'] as String? ??
                      device['deviceId'] as String? ??
                      'Pending device')
                  .trim(),
          platform:
              (device['platform'] as String? ??
                      device['deviceFamily'] as String? ??
                      'Unknown')
                  .trim(),
          status: 'Pending approval',
          lastSeen: _formatTimestamp(
            _readInt(device['lastSeenAtMs']) ??
                _readInt(device['updatedAtMs']) ??
                _readInt(device['ts']),
          ),
          deviceId: device['deviceId'] as String?,
          pendingApproval: true,
          requestId: device['requestId'] as String?,
        ),
      );
    }
    for (final dynamic item in paired) {
      final Map<String, dynamic> device = item as Map<String, dynamic>;
      devices.add(
        DeviceInfo(
          name:
              (device['displayName'] as String? ??
                      device['name'] as String? ??
                      device['deviceId'] as String? ??
                      'Trusted device')
                  .trim(),
          platform:
              (device['platform'] as String? ??
                      device['deviceFamily'] as String? ??
                      'Unknown')
                  .trim(),
          status: 'Trusted',
          lastSeen: _formatTimestamp(
            _readInt(device['lastSeenAtMs']) ??
                _readInt(device['rotatedAtMs']) ??
                _readInt(device['updatedAtMs']) ??
                _readInt(device['ts']),
          ),
          deviceId: device['deviceId'] as String?,
          role: device['role'] as String? ?? 'operator',
        ),
      );
    }
    return devices;
  }

  List<DeviceInfo> _parseNodeDevices(Map<String, dynamic> payload) {
    final Map<String, dynamic> details = _unwrapGatewayResult(payload);
    final List<dynamic> rawNodes = _readList(details['nodes']);
    return rawNodes.map((dynamic item) {
      final Map<String, dynamic> node = item as Map<String, dynamic>;
      final bool connected = node['connected'] as bool? ?? true;
      return DeviceInfo(
        name:
            (node['displayName'] as String? ??
                    node['name'] as String? ??
                    node['host'] as String? ??
                    node['nodeId'] as String? ??
                    'Node')
                .trim(),
        platform:
            (node['platform'] as String? ??
                    node['deviceFamily'] as String? ??
                    'Unknown')
                .trim(),
        status: connected ? 'Connected' : 'Offline',
        lastSeen: _formatTimestamp(
          _readInt(node['lastSeenAtMs']) ??
              _readInt(node['updatedAtMs']) ??
              _readInt(node['ts']),
        ),
        deviceId:
            node['deviceId'] as String? ??
            node['nodeId'] as String? ??
            node['id'] as String?,
      );
    }).toList();
  }

  List<DeviceInfo> _mergeDevices(
    List<DeviceInfo> pairingDevices,
    List<DeviceInfo> nodeDevices,
  ) {
    final Map<String, DeviceInfo> merged = <String, DeviceInfo>{};
    for (final DeviceInfo item in pairingDevices) {
      merged['${item.name}|${item.platform}|${item.pendingApproval}'] = item;
    }
    for (final DeviceInfo item in nodeDevices) {
      merged.putIfAbsent(
        '${item.name}|${item.platform}|${item.pendingApproval}',
        () => item,
      );
    }
    return merged.values.toList();
  }

  List<SkillInfo> _parseSkills(Map<String, dynamic> payload) {
    final Map<String, dynamic> details = _unwrapGatewayResult(payload);
    final List<dynamic> rawSkills = _readList(
      details['skills'] ?? details['items'] ?? details['report'],
    );
    return rawSkills.map((dynamic item) {
      final Map<String, dynamic> skill = item as Map<String, dynamic>;
      final List<dynamic> missing = _readList(skill['missing']);
      final bool disabled = skill['disabled'] as bool? ?? false;
      final bool blocked = skill['blockedByAllowlist'] as bool? ?? false;
      final String status = blocked
          ? 'Blocked'
          : disabled
          ? 'Disabled'
          : missing.isNotEmpty
          ? 'Missing deps'
          : 'Enabled';
      final String detail = blocked
          ? 'Blocked by allowlist'
          : missing.isNotEmpty
          ? missing.map((dynamic item) => item.toString()).join(', ')
          : (skill['description'] as String? ?? 'Ready');
      return SkillInfo(
        name: (skill['name'] as String? ?? skill['key'] as String? ?? 'Skill')
            .trim(),
        status: status,
        detail: _formatSkillDetail(
          detail,
          missing,
          skill['platforms'] ?? skill['platform'],
        ),
        group: _resolveSkillGroup(skill),
        inputPath: _resolveSkillInputPath(skill, missing),
      );
    }).toList();
  }
}

class OpenClawApiClient {
  OpenClawApiClient({GatewayHttpClient? httpClient})
    : _httpClient = httpClient ?? createGatewayHttpClient();

  final GatewayHttpClient _httpClient;

  Future<Map<String, dynamic>> invokeTool(
    ConnectionProfile profile,
    String tool, [
    Map<String, dynamic> args = const <String, dynamic>{},
  ]) async {
    final GatewayHttpResponse response = await _sendJson(
      profile.toolsInvokeUri,
      profile,
      method: 'POST',
      payload: <String, dynamic>{'tool': tool, 'args': args},
    );
    final Map<String, dynamic> json = _decodeJsonObject(response.body);
    final bool ok = json['ok'] as bool? ?? false;
    if (!ok) {
      final Map<String, dynamic> error =
          json['error'] as Map<String, dynamic>? ?? <String, dynamic>{};
      throw OpenClawApiException(
        error['message'] as String? ?? 'Tool invocation failed.',
        response.statusCode,
      );
    }
    return json['result'] as Map<String, dynamic>? ?? <String, dynamic>{};
  }

  Future<Map<String, dynamic>> postChatCompletions(
    ConnectionProfile profile,
    Map<String, dynamic> payload,
  ) async {
    final GatewayHttpResponse response = await _sendJson(
      profile.chatCompletionsUri,
      profile,
      method: 'POST',
      payload: payload,
    );
    return _decodeJsonObject(response.body);
  }

  Future<ProbeResponse> probe(ConnectionProfile profile) async {
    final Stopwatch stopwatch = Stopwatch()..start();
    final GatewayHttpResponse readyResponse = await _sendRaw(
      profile.readyUri,
      profile,
      method: 'GET',
    );
    final bool ready =
        readyResponse.statusCode >= 200 && readyResponse.statusCode < 300;
    if (!ready) {
      final GatewayHttpResponse healthResponse = await _sendRaw(
        profile.healthUri,
        profile,
        method: 'GET',
      );
      stopwatch.stop();
      if (healthResponse.statusCode == 401 ||
          healthResponse.statusCode == 403) {
        return ProbeResponse(
          reachable: true,
          authenticated: false,
          ready: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          statusCode: healthResponse.statusCode,
          message: 'Gateway reached, but auth was rejected.',
        );
      }
      if (healthResponse.statusCode < 200 || healthResponse.statusCode >= 300) {
        return ProbeResponse(
          reachable: false,
          authenticated: false,
          ready: false,
          latencyMs: stopwatch.elapsedMilliseconds,
          statusCode: healthResponse.statusCode,
          message: 'Gateway did not report healthy or ready.',
        );
      }
    }

    try {
      await invokeTool(profile, 'sessions_list', <String, dynamic>{
        'limit': 1,
        'messageLimit': 0,
      });
      stopwatch.stop();
      return ProbeResponse(
        reachable: true,
        authenticated: true,
        ready: ready,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: readyResponse.statusCode,
        message: ready
            ? 'Gateway ready. HTTP and WebSocket surfaces are derivable from this profile.'
            : 'Gateway is reachable but not yet ready.',
      );
    } on OpenClawApiException catch (error) {
      stopwatch.stop();
      return ProbeResponse(
        reachable: true,
        authenticated: false,
        ready: false,
        latencyMs: stopwatch.elapsedMilliseconds,
        statusCode: error.statusCode,
        message: error.message,
      );
    }
  }

  Future<GatewayHttpResponse> _sendJson(
    Uri uri,
    ConnectionProfile profile, {
    required String method,
    required Map<String, dynamic> payload,
  }) async {
    final GatewayHttpResponse response = await _sendRaw(
      uri,
      profile,
      method: method,
      body: jsonEncode(payload),
      includeJsonContentType: true,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw OpenClawApiException(
        _extractErrorMessage(response.body) ?? 'Gateway request failed.',
        response.statusCode,
      );
    }
    return response;
  }

  Future<GatewayHttpResponse> _sendRaw(
    Uri uri,
    ConnectionProfile profile, {
    required String method,
    String? body,
    bool includeJsonContentType = false,
  }) {
    final Map<String, String> headers = <String, String>{
      'Accept': 'application/json',
      'Authorization': 'Bearer ${profile.secret}',
      'X-OpenClaw-Message-Channel': 'mobile',
    };
    if (includeJsonContentType) {
      headers['Content-Type'] = 'application/json';
    }
    return _httpClient.send(uri, method: method, headers: headers, body: body);
  }
}

class ProbeResponse {
  const ProbeResponse({
    required this.reachable,
    required this.authenticated,
    required this.ready,
    required this.latencyMs,
    required this.message,
    required this.statusCode,
  });

  final bool reachable;
  final bool authenticated;
  final bool ready;
  final int latencyMs;
  final int statusCode;
  final String message;
}

class OpenClawApiException implements Exception {
  const OpenClawApiException(this.message, this.statusCode);

  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

Map<String, dynamic> _decodeJsonObject(String body) {
  if (body.trim().isEmpty) {
    return <String, dynamic>{};
  }
  return jsonDecode(body) as Map<String, dynamic>;
}

Map<String, dynamic> _unwrapGatewayResult(Map<String, dynamic> payload) {
  final Map<String, dynamic> details =
      payload['details'] as Map<String, dynamic>? ?? <String, dynamic>{};
  return details.isEmpty ? payload : details;
}

String? _extractErrorMessage(String body) {
  try {
    final Map<String, dynamic> json = _decodeJsonObject(body);
    final Map<String, dynamic> error =
        json['error'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return error['message'] as String?;
  } catch (_) {
    return body.trim().isEmpty ? null : body.trim();
  }
}

String _formatSchedule(Map<String, dynamic> schedule) {
  final String kind = schedule['kind'] as String? ?? 'cron';
  return switch (kind) {
    'every' => 'every ${schedule['everyMs'] ?? 0} ms',
    'at' => 'at ${schedule['at'] ?? 'unknown'}',
    _ => schedule['expr'] as String? ?? 'cron',
  };
}

String _formatTimestamp(int? millisecondsSinceEpoch) {
  if (millisecondsSinceEpoch == null || millisecondsSinceEpoch <= 0) {
    return 'Unavailable';
  }
  final Duration delta = DateTime.now().difference(
    DateTime.fromMillisecondsSinceEpoch(millisecondsSinceEpoch),
  );
  if (delta.inMinutes.abs() < 1) {
    return 'Just now';
  }
  if (delta.inMinutes.abs() < 60) {
    return '${delta.inMinutes.abs()}m ago';
  }
  if (delta.inHours.abs() < 24) {
    return '${delta.inHours.abs()}h ago';
  }
  return '${delta.inDays.abs()}d ago';
}

String? _formatDuration(int? durationMs) {
  if (durationMs == null || durationMs < 0) {
    return null;
  }
  if (durationMs < 1000) {
    return '${durationMs}ms';
  }
  final Duration duration = Duration(milliseconds: durationMs);
  if (duration.inMinutes < 1) {
    return '${duration.inSeconds}s';
  }
  if (duration.inHours < 1) {
    return '${duration.inMinutes}m';
  }
  return '${duration.inHours}h';
}

String? _resolveDeliveryLabel(
  Map<String, dynamic> delivery,
  Map<String, dynamic> run,
) {
  final String raw =
      (delivery['status'] as String? ??
              run['deliveryStatus'] as String? ??
              run['announceStatus'] as String? ??
              '')
          .trim();
  if (raw.isNotEmpty) {
    return _formatGroupLabel(raw);
  }
  final bool? delivered = delivery['delivered'] as bool?;
  if (delivered == null) {
    return null;
  }
  return delivered ? 'Delivered' : 'Not delivered';
}

int? _readInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '');
}

String _resolveNextRunLabel(List<CronJob> cronJobs) {
  if (cronJobs.isEmpty) {
    return 'No cron jobs found';
  }
  return '${cronJobs.first.name} ${cronJobs.first.nextRun}';
}

bool _isApprovalRequiredMessage(String message) {
  final String normalized = message.trim().toLowerCase();
  return normalized.contains('pairing required') ||
      normalized.contains('not paired') ||
      normalized.contains('device signature invalid') ||
      normalized.contains('approve this device');
}

String _resolveSkillGroup(Map<String, dynamic> skill) {
  final bool isCore =
      (skill['core'] as bool? ?? false) ||
      (skill['isCore'] as bool? ?? false) ||
      (skill['group'] as String? ?? '').trim().toLowerCase() == 'core' ||
      (skill['category'] as String? ?? '').trim().toLowerCase() == 'core' ||
      (skill['source'] as String? ?? '').trim().toLowerCase() == 'core';
  if (isCore) {
    return 'Core';
  }
  final bool isBuiltIn =
      (skill['builtin'] as bool? ?? false) ||
      (skill['builtIn'] as bool? ?? false) ||
      (skill['isBuiltin'] as bool? ?? false) ||
      <String>{
        'builtin',
        'built-in',
        'native',
        'system',
      }.contains((skill['group'] as String? ?? '').trim().toLowerCase()) ||
      <String>{
        'builtin',
        'built-in',
        'native',
        'system',
      }.contains((skill['category'] as String? ?? '').trim().toLowerCase()) ||
      <String>{
        'builtin',
        'built-in',
        'native',
        'system',
      }.contains((skill['source'] as String? ?? '').trim().toLowerCase());
  if (isBuiltIn) {
    return 'Built-in';
  }
  final String explicit =
      (skill['groupLabel'] as String? ??
              skill['group'] as String? ??
              skill['category'] as String? ??
              skill['source'] as String? ??
              '')
          .trim();
  if (explicit.isNotEmpty) {
    return _formatGroupLabel(explicit);
  }
  return 'Installed';
}

String _formatGroupLabel(String raw) {
  return raw
      .split(RegExp(r'[-_]+'))
      .where((String part) => part.trim().isNotEmpty)
      .map((String part) {
        if (part.length == 1) {
          return part.toUpperCase();
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}

String _formatSkillDetail(
  String rawDetail,
  List<dynamic> missing,
  dynamic platformValue,
) {
  final List<String> missingParts = _flattenSkillTokens(missing);
  if (missingParts.isNotEmpty) {
    final String joined = missingParts.take(4).join(', ');
    return 'Missing: $joined';
  }
  final List<String> platforms = _flattenSkillTokens(platformValue);
  final String detail = _cleanSkillText(rawDetail);
  if (platforms.isNotEmpty &&
      detail.isNotEmpty &&
      detail.toLowerCase() != 'ready') {
    return '$detail\nPlatforms: ${platforms.join(', ')}';
  }
  if (platforms.isNotEmpty) {
    return 'Platforms: ${platforms.join(', ')}';
  }
  return detail.isEmpty ? 'Ready' : detail;
}

List<String> _flattenSkillTokens(dynamic value) {
  final List<String> tokens = <String>[];

  void collect(dynamic item) {
    if (item == null) {
      return;
    }
    if (item is List) {
      for (final dynamic nested in item) {
        collect(nested);
      }
      return;
    }
    if (item is Map) {
      item.values.forEach(collect);
      return;
    }
    final String normalized = _cleanSkillText(item.toString());
    if (normalized.isEmpty || normalized == 'null') {
      return;
    }
    if (!RegExp(r'[A-Za-z0-9]').hasMatch(normalized)) {
      return;
    }
    tokens.add(normalized);
  }

  collect(value);
  return tokens
      .map(_humanizeSkillToken)
      .where((String token) => token.isNotEmpty)
      .toSet()
      .toList();
}

String _cleanSkillText(String raw) {
  return raw
      .replaceAll(RegExp(r'[\[\]\{\}]'), ' ')
      .replaceAll(RegExp(r'\s*,\s*'), ', ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _humanizeSkillToken(String raw) {
  final String cleaned = raw.trim().toLowerCase();
  if (cleaned.isEmpty) {
    return '';
  }
  const Map<String, String> tokenMap = <String, String>{
    'darwin': 'macOS',
    'ios': 'iOS',
    'android': 'Android',
    'memo': 'Memo',
    'remindctl': 'Reminders',
    'opl': '1Password CLI',
    'gh': 'GitHub CLI',
  };
  return tokenMap[cleaned] ?? raw.trim();
}

String? _resolveSkillInputPath(
  Map<String, dynamic> skill,
  List<dynamic> missing,
) {
  final String explicit =
      (skill['inputPath'] as String? ??
              skill['configPath'] as String? ??
              skill['secretPath'] as String? ??
              '')
          .trim();
  if (explicit.isNotEmpty) {
    return explicit;
  }
  final List<String> missingTokens = _flattenSkillTokens(missing);
  for (final String token in missingTokens) {
    if (token.contains('.') && RegExp(r'[A-Za-z]').hasMatch(token)) {
      return token;
    }
  }
  return null;
}

String _scopeKey(Uri uri) {
  final int port = uri.hasPort ? uri.port : (uri.scheme == 'wss' ? 443 : 80);
  return '${uri.scheme}__${uri.host}__$port'.replaceAll(
    RegExp(r'[^a-zA-Z0-9_]'),
    '_',
  );
}

String _extractMessageText(Map<String, dynamic>? message) {
  if (message == null || message.isEmpty) {
    return '';
  }
  if (message['text'] is String) {
    return (message['text'] as String).trim();
  }
  final dynamic content = message['content'];
  if (content is String) {
    return content.trim();
  }
  if (content is List<dynamic>) {
    return content
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => item['text'] as String? ?? '')
        .where((String value) => value.trim().isNotEmpty)
        .join('\n\n')
        .trim();
  }
  return '';
}

String? _resolveMessageSummary(Map<String, dynamic> message) {
  final Map<String, dynamic> metadata = _readMap(
    message['metadata'] ?? message['meta'],
  );
  final List<String> candidates =
      <String>[
            message['summary'] as String? ?? '',
            metadata['summary'] as String? ?? '',
            metadata['workingOn'] as String? ?? '',
            metadata['title'] as String? ?? '',
          ]
          .map((String value) => value.trim())
          .where((String value) => value.isNotEmpty)
          .toList();
  if (candidates.isEmpty) {
    return null;
  }
  return candidates.first;
}

List<ChatToolCall> _resolveToolCalls(Map<String, dynamic> message) {
  final Map<String, dynamic> metadata = _readMap(
    message['metadata'] ?? message['meta'],
  );
  final List<dynamic> contentItems = message['content'] is List<dynamic>
      ? message['content'] as List<dynamic>
      : const <dynamic>[];
  final List<dynamic> rawToolCalls = <dynamic>[
    ..._readList(message['toolCalls'] ?? message['tool_calls']),
    ..._readList(metadata['toolCalls'] ?? metadata['tool_calls']),
  ];

  for (final dynamic item in contentItems) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final String type = (item['type'] as String? ?? '').trim().toLowerCase();
    if (type.contains('tool') ||
        type.contains('exec') ||
        type.contains('step')) {
      rawToolCalls.add(item);
    }
  }

  return rawToolCalls
      .map((dynamic item) => _toToolCall(item))
      .whereType<ChatToolCall>()
      .toList();
}

ChatToolCall? _toToolCall(dynamic raw) {
  final Map<String, dynamic> item = _readMap(raw);
  if (item.isEmpty) {
    return null;
  }
  final String name =
      (item['name'] as String? ??
              item['tool'] as String? ??
              item['title'] as String? ??
              item['label'] as String? ??
              item['id'] as String? ??
              'Tool call')
          .trim();
  final String summary =
      (item['summary'] as String? ??
              item['statusText'] as String? ??
              item['workingOn'] as String? ??
              '')
          .trim();
  final String output =
      (item['output'] as String? ??
              item['result'] as String? ??
              item['text'] as String? ??
              _extractMessageText(item))
          .trim();
  return ChatToolCall(
    name: name,
    summary: summary.isEmpty ? null : summary,
    output: output.isEmpty ? null : output,
  );
}

Map<String, dynamic> _buildConfigPatch(String path, String value) {
  final List<String> segments = path
      .split('.')
      .map((String item) => item.trim())
      .where((String item) => item.isNotEmpty)
      .toList();
  Map<String, dynamic> root = <String, dynamic>{};
  Map<String, dynamic> cursor = root;
  for (int index = 0; index < segments.length; index++) {
    final String segment = segments[index];
    if (index == segments.length - 1) {
      cursor[segment] = value;
    } else {
      final Map<String, dynamic> next = <String, dynamic>{};
      cursor[segment] = next;
      cursor = next;
    }
  }
  return root;
}

ChatMessage? _toChatMessage(Map<String, dynamic> message) {
  final String roleRaw = (message['role'] as String? ?? '')
      .trim()
      .toLowerCase();
  final MessageRole role = switch (roleRaw) {
    'assistant' => MessageRole.assistant,
    'user' => MessageRole.user,
    'system' => MessageRole.system,
    _ => MessageRole.system,
  };
  final String content = _extractMessageText(message);
  final List<ChatAttachment> attachments = <ChatAttachment>[
    ..._readList(message['attachments'])
        .map((dynamic item) => _toChatAttachment(item))
        .whereType<ChatAttachment>(),
    ..._extractImageAttachments(message),
  ];
  // Skip messages with no text and no attachments
  if (content.isEmpty && attachments.isEmpty) {
    return null;
  }
  return ChatMessage(
    role: role,
    content: content,
    timestampLabel: _formatTimestamp(
      _readInt(message['timestamp']) ??
          _readInt(message['timestampMs']) ??
          _readInt(message['createdAt']) ??
          _readInt(message['createdAtMs']),
    ),
    summary: _resolveMessageSummary(message),
    toolCalls: _resolveToolCalls(message),
    attachments: attachments,
  );
}

/// Extracts image attachments from the OpenAI-format content array.
/// Handles `{type: 'image_url', image_url: {url: '...'}}` items.
List<ChatAttachment> _extractImageAttachments(Map<String, dynamic> message) {
  final dynamic content = message['content'];
  if (content is! List<dynamic>) {
    return const <ChatAttachment>[];
  }
  final List<ChatAttachment> result = <ChatAttachment>[];
  for (final dynamic item in content) {
    if (item is! Map<String, dynamic>) {
      continue;
    }
    final String type = (item['type'] as String? ?? '').toLowerCase();
    if (type != 'image_url') {
      continue;
    }
    final dynamic imageUrl = item['image_url'];
    String url = '';
    if (imageUrl is Map) {
      url = (imageUrl['url'] as String? ?? '').trim();
    } else if (imageUrl is String) {
      url = imageUrl.trim();
    }
    if (url.isEmpty) {
      continue;
    }
    String mimeType = 'image/jpeg';
    if (url.startsWith('data:')) {
      final int semicolon = url.indexOf(';');
      if (semicolon > 5) {
        mimeType = url.substring(5, semicolon);
      }
    }
    result.add(ChatAttachment(name: 'image', mimeType: mimeType, media: url));
  }
  return result;
}

ChatAttachment? _toChatAttachment(dynamic raw) {
  final Map<String, dynamic> item = _readMap(raw);
  if (item.isEmpty) {
    return null;
  }
  return ChatAttachment(
    name: item['name'] as String? ?? 'file',
    mimeType: item['mimeType'] as String? ?? 'application/octet-stream',
    media: item['media'] as String? ?? item['dataUrl'] as String? ?? '',
  );
}

Map<String, dynamic> _readMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (dynamic key, dynamic item) => MapEntry(key.toString(), item),
    );
  }
  return <String, dynamic>{};
}

List<dynamic> _readList(dynamic value) {
  if (value is List<dynamic>) {
    return value;
  }
  if (value is List) {
    return List<dynamic>.from(value);
  }
  if (value is Map<String, dynamic>) {
    if (value['items'] is List) {
      return _readList(value['items']);
    }
    if (value['skills'] is List) {
      return _readList(value['skills']);
    }
    if (value['nodes'] is List) {
      return _readList(value['nodes']);
    }
    if (value['pending'] is List) {
      return _readList(value['pending']);
    }
    if (value['paired'] is List) {
      return _readList(value['paired']);
    }
    if (value['jobs'] is List) {
      return _readList(value['jobs']);
    }
    if (value['messages'] is List) {
      return _readList(value['messages']);
    }
    return value.values.toList(growable: false);
  }
  return const <dynamic>[];
}

class _GatewayData {
  const _GatewayData({
    required this.sessions,
    required this.devices,
    required this.cronJobs,
    required this.skills,
    required this.totalJobs,
    this.approvalRequired = false,
    this.approvalMessage,
  });

  final List<SessionInfo> sessions;
  final List<DeviceInfo> devices;
  final List<CronJob> cronJobs;
  final List<SkillInfo> skills;
  final int? totalJobs;
  final bool approvalRequired;
  final String? approvalMessage;
}

class GatewayHelloSnapshot {
  const GatewayHelloSnapshot({
    required this.serverVersion,
    required this.healthVersion,
    required this.recentSessions,
    required this.presenceDevices,
    required this.cronFallbackJobs,
    required this.skillsFallback,
  });

  final String? serverVersion;
  final String? healthVersion;
  final List<GatewayRecentSession> recentSessions;
  final List<DeviceInfo> presenceDevices;
  final List<CronJob> cronFallbackJobs;
  final List<SkillInfo> skillsFallback;

  factory GatewayHelloSnapshot.fromPayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> snapshot = _readMap(payload['snapshot']);
    final Map<String, dynamic> health = _readMap(snapshot['health']);
    final Map<String, dynamic> healthSessions = _readMap(health['sessions']);
    final List<dynamic> recent = _readList(healthSessions['recent']);
    final List<dynamic> presence = _readList(snapshot['presence']);
    final List<dynamic> agents = _readList(health['agents']);
    final Map<String, dynamic> skillsReport = _readMap(payload['skillsReport']);
    final Map<String, dynamic> skillsRoot = _readMap(payload['skills']);
    final List<dynamic> skills = _readList(
      skillsReport['skills'] ?? payload['skillsReport'] ?? skillsRoot['skills'],
    );
    return GatewayHelloSnapshot(
      serverVersion:
          (payload['server'] as Map<String, dynamic>? ??
                  <String, dynamic>{})['version']
              as String?,
      healthVersion: health['version'] as String?,
      recentSessions: recent.map((dynamic item) {
        final Map<String, dynamic> session = item as Map<String, dynamic>;
        return GatewayRecentSession(
          key:
              (session['key'] as String? ??
                      session['sessionKey'] as String? ??
                      session['label'] as String? ??
                      'session')
                  .trim(),
          label:
              (session['label'] as String? ??
                      session['key'] as String? ??
                      'Session')
                  .trim(),
          kind: (session['kind'] as String? ?? 'session').trim(),
          updatedAt: _readInt(session['updatedAt']) ?? 0,
        );
      }).toList(),
      presenceDevices: presence.map((dynamic item) {
        final Map<String, dynamic> node = item as Map<String, dynamic>;
        final String host =
            (node['host'] as String? ?? node['text'] as String? ?? 'Node')
                .trim();
        final String mode = (node['mode'] as String? ?? 'ui').trim();
        return DeviceInfo(
          name: host,
          platform: (node['platform'] as String? ?? 'Unknown').trim(),
          status: mode == 'gateway' ? 'Gateway' : 'Connected',
          lastSeen: _formatTimestamp(_readInt(node['ts'])),
        );
      }).toList(),
      cronFallbackJobs: agents.map((dynamic item) {
        final Map<String, dynamic> agent = item as Map<String, dynamic>;
        final Map<String, dynamic> heartbeat =
            agent['heartbeat'] as Map<String, dynamic>? ?? <String, dynamic>{};
        return CronJob(
          id: ((agent['agentId'] as String? ?? 'main').trim()) + '-heartbeat',
          name: (agent['agentId'] as String? ?? 'main').trim() + ' heartbeat',
          schedule: (heartbeat['every'] as String? ?? 'heartbeat').trim(),
          nextRun: 'Managed by gateway heartbeat',
          lastRun: 'Unavailable',
          health: heartbeat['enabled'] as bool? ?? false
              ? JobHealth.healthy
              : JobHealth.warning,
        );
      }).toList(),
      skillsFallback: skills.map((dynamic item) {
        final Map<String, dynamic> skill = item as Map<String, dynamic>;
        return SkillInfo(
          name: (skill['name'] as String? ?? skill['key'] as String? ?? 'Skill')
              .trim(),
          status: (skill['disabled'] as bool? ?? false)
              ? 'Disabled'
              : 'Enabled',
          detail: _formatSkillDetail(
            skill['description'] as String? ?? 'Ready',
            _readList(skill['missing']),
            skill['platforms'] ?? skill['platform'],
          ),
          group: _resolveSkillGroup(skill),
        );
      }).toList(),
    );
  }
}

class GatewayRecentSession {
  const GatewayRecentSession({
    required this.key,
    required this.label,
    required this.kind,
    required this.updatedAt,
  });

  final String key;
  final String label;
  final String kind;
  final int updatedAt;
}
