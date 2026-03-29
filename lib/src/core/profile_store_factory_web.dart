import 'package:web/web.dart' as web;

import 'models.dart';
import 'profile_store.dart';

const String _profileStorageKey = 'clawui.connection_profile';

ConnectionProfileStore createConnectionProfileStore() {
  return _BrowserConnectionProfileStore();
}

class _BrowserConnectionProfileStore implements ConnectionProfileStore {
  @override
  Future<void> clear() async {
    web.window.localStorage.removeItem(_profileStorageKey);
  }

  @override
  Future<ConnectionProfile?> load() async {
    final String? raw = web.window.localStorage.getItem(_profileStorageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return decodeConnectionProfile(raw);
  }

  @override
  Future<void> save(ConnectionProfile profile) async {
    web.window.localStorage.setItem(_profileStorageKey, profile.encode());
  }
}
