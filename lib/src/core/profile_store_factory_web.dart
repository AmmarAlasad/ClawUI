import 'dart:html' as html;

import 'models.dart';
import 'profile_store.dart';

const String _profileStorageKey = 'clawui.connection_profile';

ConnectionProfileStore createConnectionProfileStore() {
  return _BrowserConnectionProfileStore();
}

class _BrowserConnectionProfileStore implements ConnectionProfileStore {
  @override
  Future<void> clear() async {
    html.window.localStorage.remove(_profileStorageKey);
  }

  @override
  Future<ConnectionProfile?> load() async {
    final String? raw = html.window.localStorage[_profileStorageKey];
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return decodeConnectionProfile(raw);
  }

  @override
  Future<void> save(ConnectionProfile profile) async {
    html.window.localStorage[_profileStorageKey] = profile.encode();
  }
}
