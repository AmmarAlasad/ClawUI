import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'models.dart';
import 'profile_store.dart';

ConnectionProfileStore createConnectionProfileStore() {
  return _FileConnectionProfileStore();
}

class _FileConnectionProfileStore implements ConnectionProfileStore {
  Future<File> _resolveFile() async {
    final Directory directory = await _resolveStorageDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return File('${directory.path}/connection_profile.json');
  }

  Future<Directory> _resolveStorageDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final Directory baseDirectory = await getApplicationSupportDirectory();
      return Directory('${baseDirectory.path}/clawui');
    }

    final String? home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null && home.trim().isNotEmpty) {
      return Directory('$home/.clawui');
    }

    final Directory baseDirectory = await getApplicationSupportDirectory();
    return Directory('${baseDirectory.path}/clawui');
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
