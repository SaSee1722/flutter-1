import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/constants/supabase_constants.dart';
import 'core/di/injection_container.dart' as di;
import 'core/theme/gossip_theme.dart';
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/chat/presentation/bloc/chat_bloc.dart';
import 'features/auth/presentation/pages/splash_screen.dart';
import 'features/vibes/presentation/bloc/vibe_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: SupabaseConstants.supabaseUrl,
    anonKey: SupabaseConstants.supabaseAnonKey,
  );

  await di.init();

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
      ],
      child: MaterialApp(
        title: 'GOSSIP',
        debugShowCheckedModeBanner: false,
        theme: GossipTheme.darkTheme,
        home: const SplashScreen(),
      ),
    );
  }
}
