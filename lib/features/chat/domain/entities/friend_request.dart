class FriendRequest {
  final String id;
  final String senderName;
  final String senderId;
  final String? senderAvatar;
  final DateTime timestamp;

  FriendRequest({
    required this.id,
    required this.senderName,
    required this.senderId,
    this.senderAvatar,
    required this.timestamp,
  });
}
