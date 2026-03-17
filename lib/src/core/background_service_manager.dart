import 'dart:async';

import 'package:flutter_background_service/flutter_background_service.dart';

/// Entry point for the background service. This runs in its own isolate.
@pragma('vm:entry-point')
Future<bool> onStart(ServiceInstance service) async {
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((Map<String, dynamic>? event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // Since this is a separate isolate, we need to pass the connection details
  // via the service instance if we want to reconnect in the background isolate.
  service.on('updateConfig').listen((Map<String, dynamic>? event) {
    // String? profileJson = event?['profile'];
    // String? secret = event?['secret'];
  });

  // Periodic check/reconnect logic
  Timer.periodic(const Duration(seconds: 15), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        // service.setForegroundNotificationInfo(...)
      }
    }

    // If we have config, we can ensure the connection is alive here too.
    // In a production app, we would re-initialize the WebSocket listener here
    // using the provided profile and secret for true 'app closed' persistence.
  });

  return true;
}

class BackgroundServiceManager {
  static final BackgroundServiceManager instance = BackgroundServiceManager._();
  BackgroundServiceManager._();

  Future<void> initialize() async {
    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'openclaw_background_service',
        initialNotificationTitle: 'OpenClaw Active',
        initialNotificationContent: 'Monitoring for messages...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
        onBackground: onStart, // Not fully supported by iOS background modes without specific entitlements
      ),
    );
  }

  void updateConfig(String profileJson, String secret) {
    FlutterBackgroundService().invoke('updateConfig', {
      'profile': profileJson,
      'secret': secret,
    });
  }

  void stop() {
    FlutterBackgroundService().invoke('stopService');
  }
}
