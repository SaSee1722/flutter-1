import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/constants/supabase_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/gossip_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'features/vibes/presentation/bloc/vibe_bloc.dart';
import 'features/call/presentation/bloc/call_bloc.dart';
import 'features/call/presentation/bloc/call_state.dart';
import 'core/notifications/notification_service.dart';
import 'features/call/presentation/widgets/call_overlay.dart';
import 'features/chat/presentation/pages/chat_detail_screen.dart';
import 'features/call/presentation/pages/incoming_call_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  await di.init();

  // Initialize Deep Linking

  // Initialize Firebase & Notifications (Mobile Only)
  if (!kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    await Firebase.initializeApp();
    await di.sl<NotificationService>().initialize();
  }

  runApp(const GossipApp());
}

class GossipApp extends StatelessWidget {
  const GossipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<AuthBloc>()),
        BlocProvider(create: (_) => di.sl<ChatBloc>()),
        BlocProvider(create: (_) => di.sl<VibeBloc>()),
        BlocProvider(create: (_) => di.sl<CallBloc>()),
      ],
      child: MaterialApp(
        title: 'GOSSIP',
        navigatorKey: NotificationService.navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: GossipTheme.darkTheme,
        home: const SplashScreen(),
        onGenerateRoute: (settings) {
          if (settings.name == '/chat_detail') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                roomId: args['chatId'],
                chatName: args['senderName'] ?? 'Gossip',
                avatarUrl: args['senderAvatar'],
              ),
            );
          }
          if (settings.name == '/incoming_call') {
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (context) => IncomingCallScreen(
                state: CallRinging(
                  callId: args['callId'],
                  callerName: args['callerName'],
                  callerAvatar: args['callerAvatar'],
                  isVideo: args['callType'] == 'video',
                  isIncoming: true,
                ),
              ),
            );
          }
          return null;
        },
        builder: (context, child) => CallOverlay(child: child!),
      ),
    );
  }
}
