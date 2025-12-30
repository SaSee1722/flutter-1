import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:gossip/core/notifications/notification_sound_helper.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Top-level background handler required by FCM
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background handler,
  // make sure you call `Firebase.initializeApp()` first.
  debugPrint("Handling a background message: ${message.messageId}");

  // Create an instance and pass data
  final service = NotificationService();
  await service.handleDataMessage(message.data);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  Future<void> initialize() async {
    // 1. Initial Notification Permissions
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 2. Initialize Local Notifications
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings =
        InitializationSettings(android: androidInit, iOS: iosInit);
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channels for Android
    await _createNotificationChannels();

    // 3. Setup FCM Handlers
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground message: ${message.data}');
      handleDataMessage(message.data);
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background: ${message.data}');
      _handleDeepLink(message.data);
    });

    // 4. Token Refresh Listener
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      uploadTokenToSupabase();
    });

    // 4. CallKit Event Listener
    FlutterCallkitIncoming.onEvent.listen((CallEvent? event) {
      if (event == null) return;
      switch (event.event) {
        case Event.actionCallAccept:
          debugPrint('Call Accepted: ${event.body}');
          _handleDeepLink({
            'type': 'call',
            'callId': event.body['id'],
            'callerName': event.body['nameCaller'],
            'callType': event.body['type'] == 1 ? 'video' : 'audio',
            'autoAnswer': true,
          });
          break;
        case Event.actionCallDecline:
          debugPrint('Call Declined');
          break;
        default:
          break;
      }
    });

    // Handle Terminated State
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state: ${initialMessage.data}');
      _handleDeepLink(initialMessage.data);
    }

    // Initial token upload if already logged in
    uploadTokenToSupabase();
  }

  /// Creates Android notification channels
  Future<void> _createNotificationChannels() async {
    // Channel for chat messages
    const chatChannel = AndroidNotificationChannel(
      'chat_messages',
      'Chat Messages',
      description: 'Notifications for new gossip messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Channel for incoming calls
    const callChannel = AndroidNotificationChannel(
      'incoming_calls',
      'Incoming Calls',
      description: 'Notifications for incoming calls',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    // Channel for friend requests
    const friendRequestChannel = AndroidNotificationChannel(
      'friend_requests',
      'Friend Requests',
      description: 'Notifications for new friend requests',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    // Create channels
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(chatChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(callChannel);

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(friendRequestChannel);

    debugPrint('Notification channels created');
  }

  /// Uploads the current FCM token to Supabase profiles table
  Future<void> uploadTokenToSupabase() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      String? token;
      if (kIsWeb) {
        debugPrint(
            '[NotificationService] Web environment detected, attempting to get FCM token safely...');
        try {
          // On Web, Firebase might throw special errors if not supported or configured
          token = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          debugPrint('[NotificationService] Failed to get Web FCM token: $e');
          return;
        }
      } else {
        token = await FirebaseMessaging.instance.getToken();
      }

      if (token != null) {
        await Supabase.instance.client
            .from('profiles')
            .update({'fcm_token': token}).eq('id', user.id);
        debugPrint("FCM Token successfully linked to user: ${user.id}");
      }
    } catch (e) {
      debugPrint("Error uploading FCM token: $e");
    }
  }

  /// Processes "data" messages from FCM (Privacy Safe)
  Future<void> handleDataMessage(Map<String, dynamic> data) async {
    final type = data['type'] as String?;
    if (type == 'chat') {
      await _showChatMessageNotification(data);
    } else if (type == 'call') {
      await _handleIncomingCallNotification(data);
    } else if (type == 'friend_request') {
      await _showFriendRequestNotification(data);
    }
  }

  Future<void> _showChatMessageNotification(Map<String, dynamic> data) async {
    final chatId = data['chatId'] as String;
    final senderName = data['senderName'] as String? ?? 'Gossip';

    // Get unread count for this chat
    final prefs = await SharedPreferences.getInstance();
    final unreadKey = 'unread_$chatId';
    final currentCount = prefs.getInt(unreadKey) ?? 0;
    final newCount = currentCount + 1;
    await prefs.setInt(unreadKey, newCount);

    // CUSTOM SOUND LOGIC
    final String? customSoundPath =
        await NotificationSoundHelper.getSoundPath(chatId: chatId);

    final androidDetails = AndroidNotificationDetails(
      'chat_messages',
      'Chat Messages',
      channelDescription: 'Notifications for new gossip messages',
      importance: Importance.max,
      priority: Priority.high,
      sound: customSoundPath != null
          ? UriAndroidNotificationSound(customSoundPath)
          : null,
      playSound: true,
      enableVibration: true,
    );

    final iosDetails = DarwinNotificationDetails(
      sound: customSoundPath?.split('/').last,
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      badgeNumber: newCount,
    );

    final details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      chatId.hashCode,
      senderName,
      newCount == 1 ? '1 new message' : '$newCount new messages',
      details,
      payload: chatId,
    );
  }

  Future<void> _showFriendRequestNotification(Map<String, dynamic> data) async {
    final senderName = data['senderName'] as String? ?? 'Someone';

    const androidDetails = AndroidNotificationDetails(
      'friend_requests',
      'Friend Requests',
      channelDescription: 'Notifications for new friend requests',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details =
        NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      DateTime.now().millisecond,
      'New Friend Request',
      '$senderName wants to be your friend',
      details,
      payload: 'friend_request',
    );
  }

  Future<void> _handleIncomingCallNotification(
      Map<String, dynamic> data) async {
    final callId = data['callId'] as String? ?? const Uuid().v4();
    final callerName = data['callerName'] as String? ?? 'Unknown Gossip';
    final callerAvatar = data['callerAvatar'] as String?;
    final isVideo = data['callType'] == 'video';

    final params = CallKitParams(
      id: callId,
      nameCaller: callerName,
      appName: 'Gossip',
      avatar: callerAvatar,
      handle: 'gossip_call',
      type: isVideo ? 1 : 0, // 0: audio, 1: video
      duration: 30000,
      textAccept: 'Accept',
      textDecline: 'Decline',
      missedCallNotification: const NotificationParams(
        showNotification: true,
        isShowCallback: true,
        subtitle: 'Missed call',
        callbackText: 'Call back',
      ),
      android: const AndroidParams(
        isCustomNotification: true,
        isShowLogo: false,
        ringtonePath: null, // Use default
        backgroundColor: '#075E54',
        backgroundUrl: 'https://i.pravatar.cc/500',
        actionColor: '#4CAF50',
      ),
      ios: IOSParams(
        iconName: 'Gossip',
        handleType: 'generic',
        supportsVideo: true,
        maximumCallGroups: 2,
        maximumCallsPerCallGroup: 1,
        audioSessionMode: isVideo ? 'videoChat' : 'voiceChat',
        audioSessionActive: true,
        supportsDTMF: true,
        supportsHolding: true,
        supportsGrouping: false,
        supportsUngrouping: false,
        ringtonePath: null, // Use default
      ),
    );

    await FlutterCallkitIncoming.showCallkitIncoming(params);
  }

  void _onNotificationTapped(NotificationResponse response) {
    if (response.payload != null) {
      _handleDeepLink({'type': 'chat', 'chatId': response.payload});
    }
  }

  void _handleDeepLink(Map<String, dynamic> data) {
    final type = data['type'];
    if (type == 'chat') {
      final chatId = data['chatId'];
      final senderName = data['senderName'];
      final senderAvatar = data['senderAvatar'];
      navigatorKey.currentState?.pushNamed('/chat_detail', arguments: {
        'chatId': chatId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
      });
    } else if (type == 'call') {
      final callId = data['callId'];
      final callerName = data['callerName'];
      final callerAvatar = data['callerAvatar'];
      final callType = data['callType'];
      final autoAnswer = data['autoAnswer'] == true;
      navigatorKey.currentState?.pushNamed('/incoming_call', arguments: {
        'callId': callId,
        'callerName': callerName,
        'callerAvatar': callerAvatar,
        'callType': callType,
        'autoAnswer': autoAnswer,
      });
    }
  }

  /// Clear unread count for a chat (call when user opens the chat)
  static Future<void> clearUnreadCount(String chatId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('unread_$chatId');
  }
}
