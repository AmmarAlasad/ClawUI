import 'models.dart';
import 'profile_store.dart';

ConnectionProfileStore createConnectionProfileStore() {
  return _InMemoryConnectionProfileStore();
}

class _InMemoryConnectionProfileStore implements ConnectionProfileStore {
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
