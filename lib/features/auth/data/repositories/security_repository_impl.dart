import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gossip/features/auth/domain/repositories/security_repository.dart';

class SecureStorageSecurityRepository implements SecurityRepository {
  final FlutterSecureStorage _storage;
  static const String _pinKey = 'app_lock_pin';
  static const String _appLockKey = 'app_lock_enabled';

  SecureStorageSecurityRepository(this._storage);

  @override
  Future<void> setPIN(String pin) async {
    await _storage.write(key: _pinKey, value: pin);
  }

  @override
  Future<String?> getPIN() async {
    return await _storage.read(key: _pinKey);
  }

  @override
  Future<bool> hasPIN() async {
    final pin = await getPIN();
    return pin != null && pin.isNotEmpty;
  }

  @override
  Future<void> clearPIN() async {
    await _storage.delete(key: _pinKey);
  }

  @override
  Future<void> setAppLock(bool enabled) async {
    await _storage.write(key: _appLockKey, value: enabled.toString());
  }

  @override
  Future<bool> isAppLockEnabled() async {
    final value = await _storage.read(key: _appLockKey);
    return value == 'true'; // Default to false if not set
  }
}
