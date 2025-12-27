class ChatRoom {
  final String id;
  final String name;
  final String? lastMessage;
  final String? time;
  final String? avatarUrl;
  final int unreadCount;
  final String? gender;
  final bool isGroup;
  final DateTime? lastMessageTime;

  ChatRoom({
    required this.id,
    required this.name,
    this.lastMessage,
    this.time,
    this.avatarUrl,
    this.unreadCount = 0,
    this.gender,
    this.isGroup = false,
    this.lastMessageTime,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'] ?? 'Unknown',
      lastMessage: json['last_message'],
      time: json['time'],
      avatarUrl: json['avatar_url'],
      unreadCount: json['unread_count'] ?? 0,
      gender: json['gender'],
      isGroup: json['is_group'] ?? false,
      lastMessageTime: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
