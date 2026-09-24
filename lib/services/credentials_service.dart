import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda las API keys de Alpaca cifradas en el almacenamiento seguro del
/// sistema (Android Keystore / iOS Keychain). Nunca se registran en logs.
class CredentialsService {
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  );

  static const _keyId = 'alpaca_key_id';
  static const _keySecret = 'alpaca_secret_key';
  static const _keyIsLive = 'alpaca_is_live';

  Future<void> save({
    required String keyId,
    required String secretKey,
    required bool isLive,
  }) async {
    await _storage.write(key: _keyId, value: keyId);
    await _storage.write(key: _keySecret, value: secretKey);
    await _storage.write(key: _keyIsLive, value: isLive.toString());
  }

  Future<void> clear() async {
    await _storage.delete(key: _keyId);
    await _storage.delete(key: _keySecret);
    await _storage.delete(key: _keyIsLive);
  }

  Future<AlpacaCredentials?> load() async {
    final keyId = await _storage.read(key: _keyId);
    final secretKey = await _storage.read(key: _keySecret);
    final isLive = await _storage.read(key: _keyIsLive);
    if (keyId == null || secretKey == null || keyId.isEmpty || secretKey.isEmpty) {
      return null;
    }
    return AlpacaCredentials(
      keyId: keyId,
      secretKey: secretKey,
      isLive: isLive == 'true',
    );
  }
}

class AlpacaCredentials {
  final String keyId;
  final String secretKey;
  final bool isLive;

  const AlpacaCredentials({
    required this.keyId,
    required this.secretKey,
    required this.isLive,
  });
}
