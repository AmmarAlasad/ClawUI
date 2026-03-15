import 'dart:io';

import 'models.dart';
import 'profile_store.dart';

ConnectionProfileStore createConnectionProfileStore() {
  return _FileConnectionProfileStore();
}

class _FileConnectionProfileStore implements ConnectionProfileStore {
  Future<File> _resolveFile() async {
    final String home = Platform.environment['HOME'] ?? Directory.current.path;
    final Directory directory = Directory('$home/.clawui');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/connection_profile.json');
  }

  @override
  Future<void> clear() async {
    final File file = await _resolveFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  @override
  Future<ConnectionProfile?> load() async {
    try {
      final File file = await _resolveFile();
      if (!await file.exists()) {
        return null;
      }
      return decodeConnectionProfile(await file.readAsString());
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> save(ConnectionProfile profile) async {
    final File file = await _resolveFile();
    await file.writeAsString(profile.encode());
  }
}
