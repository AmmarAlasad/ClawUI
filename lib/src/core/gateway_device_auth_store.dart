import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GatewayDeviceIdentity {
  const GatewayDeviceIdentity({
    required this.deviceId,
    required this.publicKey,
    required this.privateKey,
  });

  final String deviceId;
  final Uint8List publicKey;
  final Uint8List privateKey;
}

class GatewayDeviceToken {
  const GatewayDeviceToken({
    required this.token,
    required this.role,
    required this.scopes,
  });

  final String token;
  final String role;
  final List<String> scopes;
}

class GatewayDeviceAuthStore {
  GatewayDeviceAuthStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _buildGatewayDeviceStorage();

  static final Ed25519 _algorithm = Ed25519();

  final FlutterSecureStorage _storage;
  final Map<String, GatewayDeviceIdentity> _identityCache =
      <String, GatewayDeviceIdentity>{};
  final Map<String, GatewayDeviceToken?> _tokenCache =
      <String, GatewayDeviceToken?>{};

  Future<GatewayDeviceIdentity> loadOrCreateIdentity(String scopeKey) async {
    final GatewayDeviceIdentity? cachedIdentity = _identityCache[scopeKey];
    if (cachedIdentity != null) {
      return cachedIdentity;
    }
    final String deviceKey = 'clawui.device.$scopeKey.id';
    final String publicKeyKey = 'clawui.device.$scopeKey.public';
    final String privateKeyKey = 'clawui.device.$scopeKey.private';

    final String? existingId = await _storage.read(key: deviceKey);
    final String? existingPublicKey = await _storage.read(key: publicKeyKey);
    final String? existingPrivateKey = await _storage.read(key: privateKeyKey);
    if (existingId != null &&
        existingPublicKey != null &&
        existingPrivateKey != null) {
      final GatewayDeviceIdentity identity = GatewayDeviceIdentity(
        deviceId: existingId,
        publicKey: base64Decode(existingPublicKey),
        privateKey: base64Decode(existingPrivateKey),
      );
      _identityCache[scopeKey] = identity;
      return identity;
    }

    final KeyPair keyPair = await _algorithm.newKeyPair();
    final SimpleKeyPairData keyPairData =
        await keyPair.extract() as SimpleKeyPairData;
    final List<int> publicKeyBytes = keyPairData.publicKey.bytes;
    final List<int> digest = await Sha256()
        .hash(publicKeyBytes)
        .then((Hash hash) => hash.bytes);
    final String deviceId = _hexEncode(digest);

    await _storage.write(key: deviceKey, value: deviceId);
    await _storage.write(
      key: publicKeyKey,
      value: base64Encode(publicKeyBytes),
    );
    await _storage.write(
      key: privateKeyKey,
      value: base64Encode(keyPairData.bytes),
    );

    final GatewayDeviceIdentity identity = GatewayDeviceIdentity(
      deviceId: deviceId,
      publicKey: Uint8List.fromList(publicKeyBytes),
      privateKey: Uint8List.fromList(keyPairData.bytes),
    );
    _identityCache[scopeKey] = identity;
    return identity;
  }

  Future<GatewayDeviceToken?> loadDeviceToken(String scopeKey) async {
    if (_tokenCache.containsKey(scopeKey)) {
      return _tokenCache[scopeKey];
    }
    final String? token = await _storage.read(
      key: 'clawui.device.$scopeKey.token',
    );
    if (token == null || token.trim().isEmpty) {
      _tokenCache[scopeKey] = null;
      return null;
    }
    final String role =
        await _storage.read(key: 'clawui.device.$scopeKey.role') ?? 'operator';
    final String rawScopes =
        await _storage.read(key: 'clawui.device.$scopeKey.scopes') ?? '';
    final GatewayDeviceToken deviceToken = GatewayDeviceToken(
      token: token,
      role: role,
      scopes: rawScopes
          .split(',')
          .map((String item) => item.trim())
          .where((String item) => item.isNotEmpty)
          .toList(),
    );
    _tokenCache[scopeKey] = deviceToken;
    return deviceToken;
  }

  Future<void> saveDeviceToken(
    String scopeKey,
    GatewayDeviceToken deviceToken,
  ) async {
    _tokenCache[scopeKey] = deviceToken;
    await _storage.write(
      key: 'clawui.device.$scopeKey.token',
      value: deviceToken.token,
    );
    await _storage.write(
      key: 'clawui.device.$scopeKey.role',
      value: deviceToken.role,
    );
    await _storage.write(
      key: 'clawui.device.$scopeKey.scopes',
      value: deviceToken.scopes.join(','),
    );
  }

  Future<void> clearDeviceToken(String scopeKey) async {
    _tokenCache.remove(scopeKey);
    await _storage.delete(key: 'clawui.device.$scopeKey.token');
    await _storage.delete(key: 'clawui.device.$scopeKey.role');
    await _storage.delete(key: 'clawui.device.$scopeKey.scopes');
  }

  Future<String> sign(GatewayDeviceIdentity identity, String payload) async {
    final SimpleKeyPair keyPair = SimpleKeyPairData(
      identity.privateKey,
      publicKey: SimplePublicKey(identity.publicKey, type: KeyPairType.ed25519),
      type: KeyPairType.ed25519,
    );
    final Signature signature = await _algorithm.sign(
      utf8.encode(payload),
      keyPair: keyPair,
    );
    return _base64UrlEncode(signature.bytes);
  }

  String encodePublicKeyForWire(Uint8List publicKey) {
    return _base64UrlEncode(publicKey);
  }
}

FlutterSecureStorage _buildGatewayDeviceStorage() {
  const AndroidOptions androidOptions = AndroidOptions(
    encryptedSharedPreferences: true,
  );
  const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );
  return const FlutterSecureStorage(
    aOptions: androidOptions,
    iOptions: iosOptions,
    webOptions: WebOptions(
      dbName: 'clawui_device_auth',
      publicKey: 'clawui-device-auth-storage',
    ),
  );
}

String _hexEncode(List<int> bytes) {
  final StringBuffer buffer = StringBuffer();
  for (final int byte in bytes) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

String _base64UrlEncode(List<int> bytes) {
  return base64UrlEncode(bytes).replaceAll('=', '');
}
