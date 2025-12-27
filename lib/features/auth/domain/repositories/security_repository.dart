abstract class SecurityRepository {
  Future<void> setPIN(String pin);
  Future<String?> getPIN();
  Future<bool> hasPIN();
  Future<void> clearPIN();
  Future<void> setAppLock(bool enabled);
  Future<bool> isAppLockEnabled();
}
