import 'package:claw_ui/src/app/claw_ui_app.dart';
import 'package:claw_ui/src/app/app_controller.dart';
import 'package:claw_ui/src/core/connection_secret_store.dart';
import 'package:claw_ui/src/core/models.dart';
import 'package:claw_ui/src/core/openclaw_repository.dart';
import 'package:claw_ui/src/core/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('bootstrap renders', (WidgetTester tester) async {
    final AppController controller = AppController(
      profileStore: _MemoryProfileStore(),
      secretStore: _MemorySecretStore(),
      repository: DemoOpenClawRepository(),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(ClawUiBootstrap(controller: controller));
    await tester.pump();

    expect(find.text('Connect ClawUI'), findsOneWidget);
    expect(find.text('Direct URL'), findsOneWidget);
  });
}

class _MemoryProfileStore implements ConnectionProfileStore {
  ConnectionProfile? _profile;

  @override
  Future<void> clear() async {
    _profile = null;
  }

  @override
  Future<ConnectionProfile?> load() async => _profile;

  @override
  Future<void> save(ConnectionProfile profile) async {
    _profile = profile;
  }
}

class _MemorySecretStore implements ConnectionSecretStore {
  @override
  Future<void> clear() async {}

  @override
  Future<ConnectionProfile> hydrate(ConnectionProfile profile) async => profile;

  @override
  Future<void> save(ConnectionProfile profile) async {}
}
