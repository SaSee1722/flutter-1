class UserStatus {
  final String id;
  final String userId;
  final String mediaUrl;
  final bool isVideo;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? caption;
  final String? username;
  final String? avatarUrl;
  final int viewCount;
  final bool isViewed; // NEW: Whether current user saw this
  final List<Map<String, String>> viewers; // Mock list of viewer profiles

  UserStatus({
    required this.id,
    required this.userId,
    required this.mediaUrl,
    required this.isVideo,
    required this.createdAt,
    required this.expiresAt,
    this.caption,
    this.username,
    this.avatarUrl,
    this.viewCount = 0,
    this.isViewed = false,
    this.viewers = const [],
  });

  factory UserStatus.fromJson(Map<String, dynamic> json) {
    // Check if status_views has any entries (meaning current user viewed it)
    final views = json['status_views'] as List?;
    final isViewed = views != null && views.isNotEmpty;

    return UserStatus(
      id: json['id'],
      userId: json['user_id'],
      mediaUrl: json['media_url'],
      caption: json['caption'],
      isVideo: json['is_video'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
      username: json['profiles']?['username'],
      avatarUrl: json['profiles']?['avatar_url'],
      viewCount: json['view_count'] ?? 0,
      isViewed: isViewed,
    );
  }
}
