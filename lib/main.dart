import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'src/app/claw_ui_app.dart';
import 'src/core/background_notification_service.dart';
import 'src/core/background_service_manager.dart';

void main() {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await BackgroundNotificationService.instance.initialize();
      await BackgroundServiceManager.instance.initialize();
      ErrorWidget.builder = (FlutterErrorDetails details) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'ClawUI hit a rendering error',
                        style: ThemeData.light().textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'The app stayed open instead of terminating. Restart the current screen or reconnect if needed.',
                      ),
                      const SizedBox(height: 16),
                      SelectableText(details.exceptionAsString()),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      };
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details);
      };
      PlatformDispatcher.instance.onError = (
        Object error,
        StackTrace stackTrace,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stackTrace),
        );
        return true;
      };
      runApp(const ClawUiBootstrap());
    },
    (Object error, StackTrace stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
    },
  );
}
