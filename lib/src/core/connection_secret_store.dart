import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'models.dart';

abstract class ConnectionSecretStore {
  Future<ConnectionProfile> hydrate(ConnectionProfile profile);
  Future<void> save(ConnectionProfile profile);
  Future<void> clear();
}

class SecureConnectionSecretStore implements ConnectionSecretStore {
  SecureConnectionSecretStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _buildStorage();

  static const String _tokenKey = 'clawui.connection.token';
  static const String _passwordKey = 'clawui.connection.password';

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _passwordKey);
  }

  @override
  Future<ConnectionProfile> hydrate(ConnectionProfile profile) async {
    final String token = profile.token.isNotEmpty
        ? profile.token
        : await _storage.read(key: _tokenKey) ?? '';
    final String password = profile.password.isNotEmpty
        ? profile.password
        : await _storage.read(key: _passwordKey) ?? '';
    return profile.copyWith(token: token, password: password);
  }

  @override
  Future<void> save(ConnectionProfile profile) async {
    if (profile.token.isNotEmpty) {
      await _storage.write(key: _tokenKey, value: profile.token);
    } else {
      await _storage.delete(key: _tokenKey);
    }
    if (profile.password.isNotEmpty) {
      await _storage.write(key: _passwordKey, value: profile.password);
    } else {
      await _storage.delete(key: _passwordKey);
    }
  }
}

FlutterSecureStorage _buildStorage() {
  const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  return FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: iosOptions,
    webOptions: _buildWebOptions(),
  );
}

WebOptions _buildWebOptions() {
  return const WebOptions(
    dbName: 'clawui_secure',
    publicKey: 'clawui-secure-storage',
  );
}
