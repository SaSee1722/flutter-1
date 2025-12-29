import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../features/auth/domain/repositories/auth_repository.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/domain/repositories/security_repository.dart';
import '../../features/auth/data/repositories/security_repository_impl.dart';
import '../../features/chat/domain/repositories/chat_repository.dart';
import '../../features/chat/data/repositories/chat_repository_impl.dart';
import '../../features/vibes/domain/repositories/status_repository.dart';
import '../../features/vibes/data/repositories/status_repository_impl.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../../features/chat/presentation/bloc/chat_bloc.dart';
import '../../features/vibes/presentation/bloc/vibe_bloc.dart';
import '../../features/call/domain/repositories/call_repository.dart';
import '../../features/call/data/webrtc_service.dart';
import '../../features/call/presentation/bloc/call_bloc.dart';
import '../notifications/notification_service.dart';
import '../services/deep_link_service.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // External
  const secureStorage = FlutterSecureStorage(
    webOptions: WebOptions(
      dbName: 'gossip_storage',
      publicKey: 'gossip_key',
    ),
  );
  sl.registerLazySingleton<FlutterSecureStorage>(() => secureStorage);

  // Supabase
  final supabase = Supabase.instance.client;
  sl.registerLazySingleton<SupabaseClient>(() => supabase);

  // Repositories
  sl.registerLazySingleton<AuthRepository>(() => SupabaseAuthRepository(sl()));
  sl.registerLazySingleton<SecurityRepository>(
      () => SecureStorageSecurityRepository(sl()));
  sl.registerLazySingleton<ChatRepository>(() => SupabaseChatRepository(sl()));
  sl.registerLazySingleton<StatusRepository>(
      () => SupabaseStatusRepository(sl()));
  sl.registerLazySingleton<CallRepository>(() => SupabaseCallRepository(sl()));
  sl.registerLazySingleton<WebRTCService>(() => WebRTCService(sl()));
  sl.registerLazySingleton<NotificationService>(() => NotificationService());
  sl.registerLazySingleton<DeepLinkService>(() => DeepLinkService());

  // Blocs
  sl.registerFactory(() => AuthBloc(sl()));
  sl.registerFactory(() => ChatBloc(sl()));
  sl.registerFactory(() => VibeBloc(sl()));
  sl.registerLazySingleton(() => CallBloc(
        webRTCService: sl(),
        callRepository: sl(),
        chatRepository: sl(),
      ));
}
