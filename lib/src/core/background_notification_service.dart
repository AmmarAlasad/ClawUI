import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'models.dart';

/// Persistent WebSocket listener that runs even when the app is in the
/// background. When the gateway pushes a `chat.stream` or `event` frame
/// containing a new assistant message, it fires a local notification.
class BackgroundNotificationService {
  BackgroundNotificationService._();
  static final BackgroundNotificationService instance =
      BackgroundNotificationService._();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  WebSocket? _socket;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;
  bool _running = false;
  ConnectionProfile? _profile;
  String? _authSecret;

  // Last known assistant message content hash to detect new messages.
  int _lastMessageHash = 0;

  /// Initialize the notification plugin. Call once from `main()`.
  Future<void> initialize() async {
    const AndroidInitializationSettings android =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings settings = InitializationSettings(
      android: android,
      iOS: ios,
    );
    await _notifications.initialize(settings: settings);

    // Request notification permissions on Android 13+
    _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  /// Start listening for gateway events on an open WebSocket.
  /// Reconnects automatically if the connection drops.
  void start(ConnectionProfile profile, String authSecret) {
    _profile = profile;
    _authSecret = authSecret;
    if (_running) return;
    _running = true;
    _connect();
  }

  /// Stop the background listener.
  void stop() {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _socket?.close().catchError((_) {});
    _socket = null;
  }

  void _connect() async {
    if (!_running || _profile == null) return;

    try {
      final Uri wsUri = _profile!.websocketUri;
      _socket = await WebSocket.connect(wsUri.toString())
          .timeout(const Duration(seconds: 10));

      // Send authentication/connect frame using the current protocol format.
      final Map<String, dynamic> auth = <String, dynamic>{};
      final String secret = _authSecret ?? _profile!.secret;
      if (_profile!.authMode == AuthMode.token) {
        auth['token'] = secret;
      } else {
        auth['password'] = secret;
      }
      _socket!.add(jsonEncode(<String, dynamic>{
        'type': 'req',
        'id': 'req-bg-connect',
        'method': 'connect',
        'params': <String, dynamic>{
          'minProtocol': 3,
          'maxProtocol': 3,
          'client': <String, dynamic>{
            'id': 'openclaw-android-bg',
            'version': '0.1.0',
            'platform': 'android',
          },
          'role': 'operator',
          'scopes': <String>['operator.read'],
          'auth': auth,
          'locale': 'en-US',
        },
      }));

      _subscription = _socket!.listen(
        _handleMessage,
        onError: (_) => _scheduleReconnect(),
        onDone: _scheduleReconnect,
        cancelOnError: false,
      );
    } catch (e) {
      debugPrint('[BackgroundNotificationService] connect failed: $e');
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (!_running) return;
    _subscription?.cancel();
    _subscription = null;
    _socket?.close().catchError((_) {});
    _socket = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), _connect);
  }

  void _handleMessage(dynamic event) {
    try {
      final Map<String, dynamic> frame =
          jsonDecode(event as String) as Map<String, dynamic>;
      final String type = (frame['type'] as String? ?? '').trim();

      // Look for event frames that indicate a new assistant message
      if (type == 'event') {
        final String eventName = (frame['event'] as String? ?? '').trim();
        final Map<String, dynamic> payload =
            frame['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};

        if (eventName == 'chat.message' ||
            eventName == 'chat.reply' ||
            eventName == 'chat.stream') {
          final String role = (payload['role'] as String? ?? '').trim();
          final String content = _extractContent(payload);

          if (role == 'assistant' && content.isNotEmpty) {
            final int hash = content.hashCode;
            if (hash != _lastMessageHash) {
              _lastMessageHash = hash;
              _showNotification(content);
            }
          }
        }
      }

      // Also look for push-style notifications from the gateway
      if (type == 'push' || type == 'notification') {
        final Map<String, dynamic> payload =
            frame['payload'] as Map<String, dynamic>? ?? <String, dynamic>{};
        final String title = (payload['title'] as String? ?? 'OpenClaw').trim();
        final String body = (payload['body'] as String? ?? payload['message'] as String? ?? '').trim();
        if (body.isNotEmpty) {
          _showNotification(body, title: title);
        }
      }
    } catch (_) {
      // Malformed frame — ignore
    }
  }

  String _extractContent(Map<String, dynamic> payload) {
    if (payload['text'] is String) {
      return (payload['text'] as String).trim();
    }
    final dynamic content = payload['content'];
    if (content is String) return content.trim();
    if (content is List) {
      return content
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) => item['text'] as String? ?? '')
          .where((String v) => v.trim().isNotEmpty)
          .join('\n')
          .trim();
    }
    return '';
  }

  Future<void> _showNotification(String body, {String title = 'Ivy replied'}) async {
    // Truncate very long messages for the notification
    final String displayBody = body.length > 200 ? '${body.substring(0, 197)}…' : body;

    const AndroidNotificationDetails android = AndroidNotificationDetails(
      'openclaw_chat',
      'Chat Messages',
      channelDescription: 'Notifications for new messages from your AI agent',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );
    const DarwinNotificationDetails ios = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    const NotificationDetails details = NotificationDetails(
      android: android,
      iOS: ios,
    );

    await _notifications.show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: displayBody,
      notificationDetails: details,
    );
  }
}
