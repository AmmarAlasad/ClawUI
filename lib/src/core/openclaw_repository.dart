import 'dart:convert';

import 'gateway_http_client.dart';
import 'models.dart';

abstract class OpenClawRepository {
  Future<OperatorSnapshot> fetchOverview(ConnectionProfile profile);
  Future<ConnectionCheckResult> testConnection(ConnectionProfile profile);
  Future<void> approveDevice(ConnectionProfile profile, String requestId);
  Future<void> rejectDevice(ConnectionProfile profile, String requestId);
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation,
  );
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
  Future<OperatorSnapshot> fetchOverview(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchOverview(profile);
    }
    try {
      return await _network!.fetchOverview(profile);
    } catch (_) {
      return _fallback.fetchOverview(profile);
    }
  }

  @override
  Future<void> rejectDevice(ConnectionProfile profile, String requestId) async {
    if (_shouldUseFallback(profile)) {
      return;
    }
    return _network!.rejectDevice(profile, requestId);
  }

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation,
  ) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.sendMessage(profile, message, conversation);
    }
    try {
      return await _network!.sendMessage(profile, message, conversation);
    } catch (_) {
      return _fallback.sendMessage(profile, message, conversation);
    }
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
        name: 'inventory-sync',
        schedule: '*/15 * * * *',
        nextRun: '12m',
        lastRun: '3m ago',
        health: JobHealth.healthy,
      ),
      CronJob(
        name: 'tailnet-prune',
        schedule: '0 */6 * * *',
        nextRun: '2h',
        lastRun: '4h ago',
        health: JobHealth.warning,
      ),
      CronJob(
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
        sessions: const <SessionInfo>[
          SessionInfo(
            title: 'Deploy staging rollback',
            updatedAgo: 'Updated 3m ago',
            state: 'Running',
          ),
          SessionInfo(
            title: 'Investigate GPU node drift',
            updatedAgo: 'Updated 14m ago',
            state: 'Needs review',
          ),
          SessionInfo(
            title: 'Nightly summary',
            updatedAgo: 'Updated 48m ago',
            state: 'Idle',
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
      ),
      devices: devices,
      cronJobs: cronJobs,
    );
  }

  @override
  Future<void> rejectDevice(
    ConnectionProfile profile,
    String requestId,
  ) async {}

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation,
  ) async {
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
  NetworkOpenClawRepository(this._client);

  final OpenClawApiClient _client;

  @override
  Future<void> approveDevice(
    ConnectionProfile profile,
    String requestId,
  ) async {
    await _client.invokeTool(profile, 'nodes', <String, dynamic>{
      'action': 'approve',
      'requestId': requestId,
    });
  }

  @override
  Future<OperatorSnapshot> fetchOverview(ConnectionProfile profile) async {
    final ConnectionCheckResult connection = await testConnection(profile);
    final Map<String, dynamic> sessionsPayload = await _client.invokeTool(
      profile,
      'sessions_list',
      <String, dynamic>{'limit': 6, 'messageLimit': 0},
    );
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

    final List<DeviceInfo> devices = _parseDevices(
      nodesPayload,
      pendingPayload,
    );
    final List<CronJob> cronJobs = _parseCronJobs(cronListPayload);
    final List<SessionInfo> sessions = _parseSessions(sessionsPayload);
    final int pendingApprovals = devices
        .where((DeviceInfo item) => item.pendingApproval)
        .length;
    final int overdueJobs = cronJobs
        .where((CronJob job) => job.health != JobHealth.healthy)
        .length;

    return OperatorSnapshot(
      connectionCheck: connection,
      dashboard: DashboardSnapshot(
        gatewayStatus: GatewayStatus(
          online: connection.reachable,
          authenticated: connection.authenticated,
          version: 'OpenClaw Gateway',
          latencyMs: connection.latencyMs,
          activeSessions: sessions.length,
          connectedDevices: devices
              .where((DeviceInfo item) => !item.pendingApproval)
              .length,
          pendingApprovals: pendingApprovals,
          runningJobs:
              _readInt(cronStatusPayload['totalJobs']) ?? cronJobs.length,
        ),
        sessions: sessions,
        connectedDevices: devices
            .where((DeviceInfo item) => !item.pendingApproval)
            .toList(),
        cronSummary: CronSummary(
          totalJobs:
              _readInt(cronStatusPayload['totalJobs']) ?? cronJobs.length,
          overdueJobs: overdueJobs,
          nextRunLabel: _resolveNextRunLabel(cronJobs),
        ),
      ),
      devices: devices,
      cronJobs: cronJobs,
    );
  }

  @override
  Future<void> rejectDevice(ConnectionProfile profile, String requestId) async {
    await _client.invokeTool(profile, 'nodes', <String, dynamic>{
      'action': 'reject',
      'requestId': requestId,
    });
  }

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation,
  ) async {
    final Map<String, dynamic> response = await _client.postChatCompletions(
      profile,
      <String, dynamic>{
        'model': 'openclaw',
        'stream': false,
        'messages': conversation
            .map(
              (ChatMessage item) => <String, dynamic>{
                'role': item.role.name,
                'content': item.content,
              },
            )
            .toList(),
      },
    );

    final List<dynamic> choices =
        response['choices'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> first = choices.isEmpty
        ? <String, dynamic>{}
        : choices.first as Map<String, dynamic>;
    final Map<String, dynamic> messagePayload =
        first['message'] as Map<String, dynamic>? ?? <String, dynamic>{};
    return ChatMessage(
      role: MessageRole.assistant,
      content: _extractChatContent(messagePayload['content']),
      timestampLabel: 'now',
    );
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
    final List<dynamic> rawJobs =
        payload['jobs'] as List<dynamic>? ?? <dynamic>[];
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

  List<DeviceInfo> _parseDevices(
    Map<String, dynamic> nodesPayload,
    Map<String, dynamic> pendingPayload,
  ) {
    final List<DeviceInfo> devices = <DeviceInfo>[];
    final List<dynamic> rawNodes =
        nodesPayload['nodes'] as List<dynamic>? ?? <dynamic>[];
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

    final List<dynamic> pending =
        pendingPayload['pending'] as List<dynamic>? ?? <dynamic>[];
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

  List<SessionInfo> _parseSessions(Map<String, dynamic> payload) {
    final List<dynamic> rawSessions =
        payload['sessions'] as List<dynamic>? ?? <dynamic>[];
    return rawSessions.map((dynamic item) {
      final Map<String, dynamic> session = item as Map<String, dynamic>;
      final String label =
          (session['label'] as String? ??
                  session['displayName'] as String? ??
                  session['key'] as String? ??
                  'Session')
              .trim();
      final String kind = (session['kind'] as String? ?? 'session').trim();
      return SessionInfo(
        title: label,
        updatedAgo: _formatTimestamp(_readInt(session['updatedAt'])),
        state: kind,
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

String _extractChatContent(dynamic content) {
  if (content is String && content.trim().isNotEmpty) {
    return content.trim();
  }
  if (content is List<dynamic>) {
    final Iterable<String> parts = content
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> item) => item['text'] as String? ?? '')
        .where((String value) => value.trim().isNotEmpty);
    final String joined = parts.join('\n\n').trim();
    if (joined.isNotEmpty) {
      return joined;
    }
  }
  return 'No response from gateway.';
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
    return 'No cron jobs';
  }
  return '${cronJobs.first.name} ${cronJobs.first.nextRun}';
}
