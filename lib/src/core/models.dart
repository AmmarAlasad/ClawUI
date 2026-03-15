import 'dart:convert';

enum AuthMode { none, token, password }

enum MessageRole { assistant, user, system }

enum JobHealth { healthy, warning, stalled }

class ConnectionProfile {
  const ConnectionProfile({
    required this.serverUrl,
    required this.authMode,
    this.name = 'Primary Gateway',
    this.token = '',
    this.password = '',
    this.demoMode = false,
  });

  final String name;
  final String serverUrl;
  final AuthMode authMode;
  final String token;
  final String password;
  final bool demoMode;

  bool get hasSecret => token.isNotEmpty || password.isNotEmpty;

  ConnectionProfile copyWith({
    String? name,
    String? serverUrl,
    AuthMode? authMode,
    String? token,
    String? password,
    bool? demoMode,
  }) {
    return ConnectionProfile(
      name: name ?? this.name,
      serverUrl: serverUrl ?? this.serverUrl,
      authMode: authMode ?? this.authMode,
      token: token ?? this.token,
      password: password ?? this.password,
      demoMode: demoMode ?? this.demoMode,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'serverUrl': serverUrl,
      'authMode': authMode.name,
      'token': token,
      'password': password,
      'demoMode': demoMode,
    };
  }

  String encode() => jsonEncode(toJson());

  static ConnectionProfile fromJson(Map<String, dynamic> json) {
    return ConnectionProfile(
      name: json['name'] as String? ?? 'Primary Gateway',
      serverUrl: json['serverUrl'] as String? ?? '',
      authMode: AuthMode.values.firstWhere(
        (mode) => mode.name == json['authMode'],
        orElse: () => AuthMode.token,
      ),
      token: json['token'] as String? ?? '',
      password: json['password'] as String? ?? '',
      demoMode: json['demoMode'] as bool? ?? false,
    );
  }
}

class GatewayStatus {
  const GatewayStatus({
    required this.online,
    required this.version,
    required this.latencyMs,
    required this.activeSessions,
    required this.connectedDevices,
    required this.pendingApprovals,
    required this.runningJobs,
  });

  final bool online;
  final String version;
  final int latencyMs;
  final int activeSessions;
  final int connectedDevices;
  final int pendingApprovals;
  final int runningJobs;
}

class SessionInfo {
  const SessionInfo({
    required this.title,
    required this.updatedAgo,
    required this.state,
  });

  final String title;
  final String updatedAgo;
  final String state;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.gatewayStatus,
    required this.sessions,
    required this.connectedDevices,
    required this.cronSummary,
  });

  final GatewayStatus gatewayStatus;
  final List<SessionInfo> sessions;
  final List<DeviceInfo> connectedDevices;
  final CronSummary cronSummary;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestampLabel,
  });

  final MessageRole role;
  final String content;
  final String timestampLabel;
}

class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.platform,
    required this.status,
    required this.lastSeen,
    this.pendingApproval = false,
  });

  final String name;
  final String platform;
  final String status;
  final String lastSeen;
  final bool pendingApproval;
}

class CronSummary {
  const CronSummary({
    required this.totalJobs,
    required this.overdueJobs,
    required this.nextRunLabel,
  });

  final int totalJobs;
  final int overdueJobs;
  final String nextRunLabel;
}

class CronJob {
  const CronJob({
    required this.name,
    required this.schedule,
    required this.nextRun,
    required this.lastRun,
    required this.health,
  });

  final String name;
  final String schedule;
  final String nextRun;
  final String lastRun;
  final JobHealth health;
}
