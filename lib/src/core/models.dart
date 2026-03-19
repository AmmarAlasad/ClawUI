import 'dart:convert';

enum ConnectionTargetKind { directUrl, hostPort, tailscale }

enum TransportSecurity { tls, insecure }

enum AuthMode { token, password }

enum MessageRole { assistant, user, system }

enum JobHealth { healthy, warning, stalled }

class ConnectionProfile {
  const ConnectionProfile({
    required this.targetKind,
    required this.authMode,
    this.name = 'Primary Gateway',
    this.transportSecurity = TransportSecurity.tls,
    this.directUrl = '',
    this.host = '',
    this.port = 18789,
    this.token = '',
    this.password = '',
    this.demoMode = false,
  });

  final String name;
  final ConnectionTargetKind targetKind;
  final TransportSecurity transportSecurity;
  final String directUrl;
  final String host;
  final int port;
  final AuthMode authMode;
  final String token;
  final String password;
  final bool demoMode;

  bool get usesTls => transportSecurity == TransportSecurity.tls;
  bool get hasSecret => secret.isNotEmpty;
  String get secret => authMode == AuthMode.token ? token : password;

  String get targetLabel => switch (targetKind) {
    ConnectionTargetKind.directUrl => 'Direct URL',
    ConnectionTargetKind.hostPort => 'Host and port',
    ConnectionTargetKind.tailscale => 'Tailscale / MagicDNS',
  };

  String get authLabel => authMode == AuthMode.token ? 'Token' : 'Password';

  String get transportLabel => usesTls ? 'HTTPS / WSS' : 'HTTP / WS';

  String get endpointLabel => switch (targetKind) {
    ConnectionTargetKind.directUrl => httpBaseUri.toString(),
    ConnectionTargetKind.hostPort =>
      port == 80 || port == 443 ? normalizedHost : '$normalizedHost:$port',
    ConnectionTargetKind.tailscale =>
      port == 80 || port == 443 ? normalizedHost : '$normalizedHost:$port',
  };

  String get normalizedHost {
    final String trimmed = host.trim();
    if (trimmed.startsWith('[') && trimmed.endsWith(']')) {
      return trimmed.substring(1, trimmed.length - 1);
    }
    return trimmed;
  }

  Uri get httpBaseUri {
    switch (targetKind) {
      case ConnectionTargetKind.directUrl:
        final Uri uri = Uri.parse(directUrl.trim());
        return _buildUri(
          scheme: uri.scheme,
          host: uri.host,
          port: uri.hasPort ? uri.port : null,
        );
      case ConnectionTargetKind.hostPort:
      case ConnectionTargetKind.tailscale:
        return _buildUri(
          scheme: usesTls ? 'https' : 'http',
          host: normalizedHost,
          port: port,
        );
    }
  }

  Uri get websocketUri {
    final Uri base = httpBaseUri;
    return _buildUri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
    );
  }

  Uri get chatCompletionsUri => _resolveSurface('/v1/chat/completions');

  Uri get toolsInvokeUri => _resolveSurface('/tools/invoke');

  Uri get readyUri => _resolveSurface('/readyz');

  Uri get healthUri => _resolveSurface('/healthz');

  Uri _resolveSurface(String path) {
    final Uri base = httpBaseUri;
    return _buildUri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: path,
    );
  }

  List<String> validate() {
    final List<String> errors = <String>[];
    if (name.trim().isEmpty) {
      errors.add('Profile name is required.');
    }
    switch (targetKind) {
      case ConnectionTargetKind.directUrl:
        final String input = directUrl.trim();
        if (input.isEmpty) {
          errors.add('Enter a gateway URL.');
          break;
        }
        final Uri? uri = Uri.tryParse(input);
        if (uri == null) {
          errors.add('Enter a valid gateway URL.');
          break;
        }
        if (uri.scheme != 'http' && uri.scheme != 'https') {
          errors.add('Gateway URL must use http:// or https://.');
        }
        if (uri.host.isEmpty) {
          errors.add('Gateway URL must include a host.');
        }
        if (uri.userInfo.isNotEmpty) {
          errors.add('Gateway URL must not embed credentials.');
        }
        if (uri.hasQuery || uri.fragment.isNotEmpty) {
          errors.add('Gateway URL must not include query or fragment values.');
        }
        if (uri.path.isNotEmpty && uri.path != '/') {
          errors.add('Gateway URL must point to the gateway origin only.');
        }
        break;
      case ConnectionTargetKind.hostPort:
      case ConnectionTargetKind.tailscale:
        if (normalizedHost.isEmpty) {
          errors.add('Enter a host, IP, or MagicDNS name.');
        }
        if (normalizedHost.contains('://') ||
            normalizedHost.contains('/') ||
            normalizedHost.contains('?') ||
            normalizedHost.contains('#')) {
          errors.add('Host field must contain only the host or IP.');
        }
        if (port < 1 || port > 65535) {
          errors.add('Port must be between 1 and 65535.');
        }
    }
    if (!hasSecret) {
      errors.add(
        authMode == AuthMode.token
            ? 'Token is required.'
            : 'Password is required.',
      );
    }
    return errors;
  }

  List<String> securityNotes() {
    final List<String> notes = <String>[];
    if (!usesTls) {
      notes.add(
        'Insecure HTTP/WS should only be used on loopback or inside a trusted tunnel.',
      );
    }
    if (targetKind == ConnectionTargetKind.tailscale && !usesTls) {
      notes.add(
        'Tailscale and MagicDNS are safest when exposed through HTTPS.',
      );
    }
    return notes;
  }

  ConnectionProfile copyWith({
    String? name,
    ConnectionTargetKind? targetKind,
    TransportSecurity? transportSecurity,
    String? directUrl,
    String? host,
    int? port,
    AuthMode? authMode,
    String? token,
    String? password,
    bool? demoMode,
  }) {
    return ConnectionProfile(
      name: name ?? this.name,
      targetKind: targetKind ?? this.targetKind,
      transportSecurity: transportSecurity ?? this.transportSecurity,
      directUrl: directUrl ?? this.directUrl,
      host: host ?? this.host,
      port: port ?? this.port,
      authMode: authMode ?? this.authMode,
      token: token ?? this.token,
      password: password ?? this.password,
      demoMode: demoMode ?? this.demoMode,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'targetKind': targetKind.name,
      'transportSecurity': transportSecurity.name,
      'directUrl': directUrl,
      'host': host,
      'port': port,
      'authMode': authMode.name,
      'demoMode': demoMode,
    };
  }

  String encode() => jsonEncode(toJson());

  static ConnectionProfile fromJson(Map<String, dynamic> json) {
    final String? legacyServerUrl = json['serverUrl'] as String?;
    final ConnectionTargetKind targetKind =
        _readEnumValue(
          ConnectionTargetKind.values,
          json['targetKind'] as String?,
        ) ??
        (legacyServerUrl?.isNotEmpty == true
            ? ConnectionTargetKind.directUrl
            : ConnectionTargetKind.hostPort);
    final String authModeRaw = json['authMode'] as String? ?? 'token';
    final AuthMode authMode =
        _readEnumValue(AuthMode.values, authModeRaw) ?? AuthMode.token;
    final Uri? legacyUri = legacyServerUrl == null || legacyServerUrl.isEmpty
        ? null
        : Uri.tryParse(legacyServerUrl);
    final TransportSecurity transportSecurity =
        _readEnumValue(
          TransportSecurity.values,
          json['transportSecurity'] as String?,
        ) ??
        ((legacyUri?.scheme == 'http')
            ? TransportSecurity.insecure
            : TransportSecurity.tls);

    return ConnectionProfile(
      name: json['name'] as String? ?? 'Primary Gateway',
      targetKind: targetKind,
      transportSecurity: transportSecurity,
      directUrl: json['directUrl'] as String? ?? legacyServerUrl ?? '',
      host: json['host'] as String? ?? legacyUri?.host ?? '',
      port:
          json['port'] as int? ??
          (legacyUri?.hasPort == true ? legacyUri?.port : null) ??
          18789,
      authMode: authMode,
      token: json['token'] as String? ?? '',
      password: json['password'] as String? ?? '',
      demoMode: json['demoMode'] as bool? ?? false,
    );
  }
}

T? _readEnumValue<T extends Enum>(List<T> values, String? raw) {
  if (raw == null || raw.isEmpty) {
    return null;
  }
  for (final T value in values) {
    if (value.name == raw) {
      return value;
    }
  }
  return null;
}

class ConnectionCheckResult {
  const ConnectionCheckResult({
    required this.reachable,
    required this.authenticated,
    required this.ready,
    required this.latencyMs,
    required this.message,
    this.httpStatusCode,
    this.checkedAt,
  });

  final bool reachable;
  final bool authenticated;
  final bool ready;
  final int latencyMs;
  final int? httpStatusCode;
  final String message;
  final DateTime? checkedAt;

  bool get ok => reachable && authenticated && ready;
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
    required this.authenticated,
  });

  final bool online;
  final bool authenticated;
  final String version;
  final int latencyMs;
  final int activeSessions;
  final int connectedDevices;
  final int pendingApprovals;
  final int runningJobs;
}

class SessionInfo {
  const SessionInfo({
    required this.key,
    required this.title,
    required this.updatedAgo,
    required this.state,
    this.updatedAtMs,
  });

  final String key;
  final String title;
  final String updatedAgo;
  final String state;
  final int? updatedAtMs;
}

class DashboardSnapshot {
  const DashboardSnapshot({
    required this.gatewayStatus,
    required this.sessions,
    required this.connectedDevices,
    required this.cronSummary,
    required this.skills,
  });

  final GatewayStatus gatewayStatus;
  final List<SessionInfo> sessions;
  final List<DeviceInfo> connectedDevices;
  final CronSummary cronSummary;
  final List<SkillInfo> skills;
}

class OperatorSnapshot {
  const OperatorSnapshot({
    required this.dashboard,
    required this.devices,
    required this.cronJobs,
    required this.skills,
    required this.connectionCheck,
    this.approvalRequired = false,
    this.approvalMessage,
  });

  final DashboardSnapshot dashboard;
  final List<DeviceInfo> devices;
  final List<CronJob> cronJobs;
  final List<SkillInfo> skills;
  final ConnectionCheckResult connectionCheck;
  final bool approvalRequired;
  final String? approvalMessage;
}

class ChatMessage {
  const ChatMessage({
    required this.role,
    required this.content,
    required this.timestampLabel,
    this.summary,
    this.toolCalls = const <ChatToolCall>[],
    this.attachments = const <ChatAttachment>[],
    this.isStreaming = false,
  });

  final MessageRole role;
  final String content;
  final String timestampLabel;
  final String? summary;
  final List<ChatToolCall> toolCalls;
  final List<ChatAttachment> attachments;
  /// True while the assistant reply is being streamed token-by-token.
  final bool isStreaming;

  ChatMessage copyWith({
    MessageRole? role,
    String? content,
    String? timestampLabel,
    String? summary,
    List<ChatToolCall>? toolCalls,
    List<ChatAttachment>? attachments,
    bool? isStreaming,
  }) {
    return ChatMessage(
      role: role ?? this.role,
      content: content ?? this.content,
      timestampLabel: timestampLabel ?? this.timestampLabel,
      summary: summary ?? this.summary,
      toolCalls: toolCalls ?? this.toolCalls,
      attachments: attachments ?? this.attachments,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }
}

class ChatAttachment {
  const ChatAttachment({
    required this.name,
    required this.mimeType,
    required this.media,
  });

  final String name;
  final String mimeType;
  final String media;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': name,
      'mimeType': mimeType,
      'media': media,
    };
  }
}

class ChatToolCall {
  const ChatToolCall({
    required this.name,
    this.summary,
    this.output,
  });

  final String name;
  final String? summary;
  final String? output;
}

class DeviceInfo {
  const DeviceInfo({
    required this.name,
    required this.platform,
    required this.status,
    required this.lastSeen,
    this.deviceId,
    this.role = 'operator',
    this.pendingApproval = false,
    this.requestId,
  });

  final String name;
  final String platform;
  final String status;
  final String lastSeen;
  final String? deviceId;
  final String role;
  final bool pendingApproval;
  final String? requestId;
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

class SkillInfo {
  const SkillInfo({
    required this.name,
    required this.status,
    required this.detail,
    this.group = 'Installed',
    this.inputPath,
  });

  final String name;
  final String status;
  final String detail;
  final String group;
  final String? inputPath;

  String get displayName => _formatSkillDisplayName(name);

  String get normalizedGroup {
    final String value = group.trim();
    if (value.isEmpty) {
      return 'Installed';
    }
    return value;
  }

  bool get canConfigureInput => inputPath != null && inputPath!.trim().isNotEmpty;
}

Uri _buildUri({
  required String scheme,
  required String host,
  int? port,
  String path = '',
}) {
  if (port == null) {
    return Uri(scheme: scheme, host: host, path: path);
  }
  return Uri(scheme: scheme, host: host, port: port, path: path);
}

String _formatSkillDisplayName(String raw) {
  final String normalized = raw.trim();
  if (normalized.isEmpty) {
    return 'Skill';
  }
  const Map<String, String> overrides = <String, String>{
    '1password': '1Password',
    'github': 'GitHub',
    'gitlab': 'GitLab',
    'postgres': 'Postgres',
    'sqlite': 'SQLite',
    'icloud': 'iCloud',
  };
  final String override = overrides[normalized.toLowerCase()] ?? '';
  if (override.isNotEmpty) {
    return override;
  }
  return normalized
      .split(RegExp(r'[-_]+'))
      .where((String part) => part.trim().isNotEmpty)
      .map((String part) {
        final String lower = part.toLowerCase();
        final String override = overrides[lower] ?? '';
        if (override.isNotEmpty) {
          return override;
        }
        if (part.length == 1) {
          return part.toUpperCase();
        }
        return '${part[0].toUpperCase()}${part.substring(1)}';
      })
      .join(' ');
}
