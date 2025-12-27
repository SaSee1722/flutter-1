class SupabaseConstants {
  static const String supabaseUrl = 'https://vnicmdiuqcexguvpijhb.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZuaWNtZGl1cWNleGd1dnBpamhiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY2MTEzOTIsImV4cCI6MjA4MjE4NzM5Mn0.VJSTWVsJ9JlFdJbqkObN6Db6DCXve9O-yA2FUtWx5SY';

  // Table Names
  static const String profilesTable = 'profiles';
  static const String messagesTable = 'messages';
  static const String callsTable = 'calls';
  static const String statusesTable = 'statuses';
  static const String iceCandidatesTable = 'ice_candidates';

  // Storage Buckets
  static const String statusMediaBucket = 'vibe-media';
  static const String avatarsBucket = 'avatars';
}
