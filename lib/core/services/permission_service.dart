import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  Future<void> requestAllPermissions() async {
    if (kIsWeb) return;

    if (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      debugPrint('[PermissionService] Requesting all startup permissions...');

      final statuses = await [
        Permission.notification,
        Permission.microphone,
        Permission.camera,
        Permission.bluetoothConnect,
      ].request();

      statuses.forEach((permission, status) {
        debugPrint('[PermissionService] $permission: $status');
      });
    }
  }
}
