import 'dart:convert';

import 'models.dart';
import 'profile_store_factory_stub.dart'
    if (dart.library.io) 'profile_store_factory_io.dart'
    if (dart.library.html) 'profile_store_factory_web.dart'
    as profile_store;

abstract class ConnectionProfileStore {
  Future<ConnectionProfile?> load();
  Future<void> save(ConnectionProfile profile);
  Future<void> clear();
}

ConnectionProfileStore createConnectionProfileStore() {
  return profile_store.createConnectionProfileStore();
}

ConnectionProfile? decodeConnectionProfile(String raw) {
  try {
    final Map<String, dynamic> json = jsonDecode(raw) as Map<String, dynamic>;
    return ConnectionProfile.fromJson(json);
  } catch (_) {
    return null;
  }
}
