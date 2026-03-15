import 'dart:convert';
import 'dart:io';

import 'models.dart';

abstract class OpenClawRepository {
  Future<DashboardSnapshot> fetchDashboard(ConnectionProfile profile);
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile);
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile);
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
  Future<DashboardSnapshot> fetchDashboard(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchDashboard(profile);
    }
    try {
      return await _network!.fetchDashboard(profile);
    } catch (_) {
      return _fallback.fetchDashboard(profile);
    }
  }

  @override
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchCronJobs(profile);
    }
    try {
      return await _network!.fetchCronJobs(profile);
    } catch (_) {
      return _fallback.fetchCronJobs(profile);
    }
  }

  @override
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile) async {
    if (_shouldUseFallback(profile)) {
      return _fallback.fetchDevices(profile);
    }
    try {
      return await _network!.fetchDevices(profile);
    } catch (_) {
      return _fallback.fetchDevices(profile);
    }
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

  bool _shouldUseFallback(ConnectionProfile profile) {
    return profile.demoMode || _network == null;
  }
}

class DemoOpenClawRepository implements OpenClawRepository {
  @override
  Future<DashboardSnapshot> fetchDashboard(ConnectionProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 240));
    return DashboardSnapshot(
      gatewayStatus: const GatewayStatus(
        online: true,
        version: 'OpenClaw Gateway 0.9.4',
        latencyMs: 42,
        activeSessions: 7,
        connectedDevices: 5,
        pendingApprovals: 2,
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
      connectedDevices: const <DeviceInfo>[
        DeviceInfo(
          name: 'Pixel 9 Pro',
          platform: 'Android',
          status: 'Paired',
          lastSeen: 'Just now',
        ),
        DeviceInfo(
          name: 'iPad Mini Ops',
          platform: 'iOS',
          status: 'Streaming',
          lastSeen: '2m ago',
        ),
      ],
      cronSummary: const CronSummary(
        totalJobs: 9,
        overdueJobs: 1,
        nextRunLabel: 'Inventory sync in 12m',
      ),
    );
  }

  @override
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const <CronJob>[
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
  }

  @override
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile) async {
    await Future<void>.delayed(const Duration(milliseconds: 180));
    return const <DeviceInfo>[
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
      ),
      DeviceInfo(
        name: 'Galaxy Tab Relay',
        platform: 'Android',
        status: 'Trusted',
        lastSeen: '18m ago',
      ),
    ];
  }

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation,
  ) async {
    await Future<void>.delayed(const Duration(milliseconds: 320));
    final String response = message.toLowerCase().contains('status')
        ? 'Gateway healthy. 7 active sessions, 5 connected devices, and one cron warning.'
        : message.toLowerCase().contains('approve')
        ? 'I can queue a device approval action once the live API contract is wired. The UI path is in place.'
        : 'Demo assistant routed your message through the repository abstraction. Swap in the live client when the OpenClaw API contract is finalized.';
    return ChatMessage(
      role: MessageRole.assistant,
      content: response,
      timestampLabel: 'now',
    );
  }
}

class NetworkOpenClawRepository implements OpenClawRepository {
  NetworkOpenClawRepository(this._client);

  final OpenClawApiClient _client;

  @override
  Future<DashboardSnapshot> fetchDashboard(ConnectionProfile profile) async {
    final Map<String, dynamic>? json = await _client.getJson(
      profile,
      '/api/mobile/dashboard',
    );
    if (json == null) {
      throw const HttpException('No dashboard payload');
    }
    final Map<String, dynamic> gateway =
        json['gateway'] as Map<String, dynamic>? ?? <String, dynamic>{};
    final List<dynamic> sessions =
        json['sessions'] as List<dynamic>? ?? <dynamic>[];
    final List<dynamic> devices =
        json['devices'] as List<dynamic>? ?? <dynamic>[];
    final Map<String, dynamic> cron =
        json['cron'] as Map<String, dynamic>? ?? <String, dynamic>{};

    return DashboardSnapshot(
      gatewayStatus: GatewayStatus(
        online: gateway['online'] as bool? ?? true,
        version: gateway['version'] as String? ?? 'OpenClaw Gateway',
        latencyMs: gateway['latencyMs'] as int? ?? 0,
        activeSessions: gateway['activeSessions'] as int? ?? sessions.length,
        connectedDevices: gateway['connectedDevices'] as int? ?? devices.length,
        pendingApprovals: gateway['pendingApprovals'] as int? ?? 0,
        runningJobs: gateway['runningJobs'] as int? ?? 0,
      ),
      sessions: sessions
          .map(
            (dynamic item) => SessionInfo(
              title:
                  (item as Map<String, dynamic>)['title'] as String? ??
                  'Session',
              updatedAgo:
                  item['updatedAgo'] as String? ??
                  item['updated_at'] as String? ??
                  'now',
              state: item['state'] as String? ?? 'Unknown',
            ),
          )
          .toList(),
      connectedDevices: devices
          .map(
            (dynamic item) => DeviceInfo(
              name:
                  (item as Map<String, dynamic>)['name'] as String? ?? 'Device',
              platform: item['platform'] as String? ?? 'Unknown',
              status: item['status'] as String? ?? 'Unknown',
              lastSeen: item['lastSeen'] as String? ?? 'recently',
              pendingApproval: item['pendingApproval'] as bool? ?? false,
            ),
          )
          .toList(),
      cronSummary: CronSummary(
        totalJobs: cron['totalJobs'] as int? ?? 0,
        overdueJobs: cron['overdueJobs'] as int? ?? 0,
        nextRunLabel: cron['nextRunLabel'] as String? ?? 'Unavailable',
      ),
    );
  }

  @override
  Future<List<CronJob>> fetchCronJobs(ConnectionProfile profile) async {
    final List<dynamic>? items = await _client.getJsonList(
      profile,
      '/api/mobile/cron',
    );
    if (items == null) {
      throw const HttpException('No cron payload');
    }
    return items
        .map(
          (dynamic item) => CronJob(
            name: (item as Map<String, dynamic>)['name'] as String? ?? 'job',
            schedule: item['schedule'] as String? ?? '* * * * *',
            nextRun: item['nextRun'] as String? ?? 'soon',
            lastRun: item['lastRun'] as String? ?? 'unknown',
            health: JobHealth.values.firstWhere(
              (value) => value.name == item['health'],
              orElse: () => JobHealth.warning,
            ),
          ),
        )
        .toList();
  }

  @override
  Future<List<DeviceInfo>> fetchDevices(ConnectionProfile profile) async {
    final List<dynamic>? items = await _client.getJsonList(
      profile,
      '/api/mobile/devices',
    );
    if (items == null) {
      throw const HttpException('No devices payload');
    }
    return items
        .map(
          (dynamic item) => DeviceInfo(
            name: (item as Map<String, dynamic>)['name'] as String? ?? 'Device',
            platform: item['platform'] as String? ?? 'Unknown',
            status: item['status'] as String? ?? 'Unknown',
            lastSeen: item['lastSeen'] as String? ?? 'recently',
            pendingApproval: item['pendingApproval'] as bool? ?? false,
          ),
        )
        .toList();
  }

  @override
  Future<ChatMessage> sendMessage(
    ConnectionProfile profile,
    String message,
    List<ChatMessage> conversation,
  ) async {
    final Map<String, dynamic>? response = await _client.postJson(
      profile,
      '/api/mobile/chat',
      <String, dynamic>{
        'message': message,
        'conversation': conversation
            .map(
              (ChatMessage item) => <String, dynamic>{
                'role': item.role.name,
                'content': item.content,
              },
            )
            .toList(),
      },
    );
    if (response == null) {
      throw const HttpException('No chat payload');
    }
    return ChatMessage(
      role: MessageRole.assistant,
      content: response['message'] as String? ?? 'No response from gateway.',
      timestampLabel: 'now',
    );
  }
}

class OpenClawApiClient {
  Future<Map<String, dynamic>?> getJson(
    ConnectionProfile profile,
    String path,
  ) async {
    final HttpClientRequest request = await _openRequest(profile, 'GET', path);
    final HttpClientResponse response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final String body = await utf8.decodeStream(response);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<List<dynamic>?> getJsonList(
    ConnectionProfile profile,
    String path,
  ) async {
    final HttpClientRequest request = await _openRequest(profile, 'GET', path);
    final HttpClientResponse response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final String body = await utf8.decodeStream(response);
    return jsonDecode(body) as List<dynamic>;
  }

  Future<Map<String, dynamic>?> postJson(
    ConnectionProfile profile,
    String path,
    Map<String, dynamic> payload,
  ) async {
    final HttpClientRequest request = await _openRequest(profile, 'POST', path);
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(payload));
    final HttpClientResponse response = await request.close();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      return null;
    }
    final String body = await utf8.decodeStream(response);
    return jsonDecode(body) as Map<String, dynamic>;
  }

  Future<HttpClientRequest> _openRequest(
    ConnectionProfile profile,
    String method,
    String path,
  ) async {
    final Uri uri = Uri.parse(profile.serverUrl).resolve(path);
    final HttpClient client = HttpClient();
    final HttpClientRequest request = await client.openUrl(method, uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    switch (profile.authMode) {
      case AuthMode.none:
        break;
      case AuthMode.token:
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer ${profile.token}',
        );
      case AuthMode.password:
        final String raw = 'mobile:${profile.password}';
        request.headers.set(
          HttpHeaders.authorizationHeader,
          'Basic ${base64Encode(utf8.encode(raw))}',
        );
    }
    return request;
  }
}
