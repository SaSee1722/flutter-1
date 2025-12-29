import 'dart:async';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:gossip/core/notifications/notification_service.dart';
import 'package:gossip/features/chat/presentation/pages/search/user_profile_preview_screen.dart';

class DeepLinkService {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void initialize() {
    _appLinks = AppLinks();

    // Handle links when app is in foreground or background
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleUri(uri);
    });

    // Handle link that opened the app from terminated state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        _handleUri(uri);
      }
    });
  }

  void _handleUri(Uri uri) {
    debugPrint('Received Deep Link: $uri');

    // gossip://profile/[username]
    if (uri.scheme == 'gossip' && uri.host == 'profile') {
      final username =
          uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      if (username != null) {
        _navigateToProfile(username);
      }
    }
  }

  void _navigateToProfile(String username) {
    NotificationService.navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => UserProfilePreviewScreen(username: username),
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
