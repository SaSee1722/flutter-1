class Message {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final MessageStatus status;
  final DateTime createdAt;
  final String? attachmentUrl;
  final String? attachmentType; // 'image', 'video', 'audio'
  final Map<String, String>? reactions; // { userId: emoji }

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.status,
    required this.createdAt,
    this.attachmentUrl,
    this.attachmentType,
    this.reactions,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'],
      roomId: json['room_id'],
      userId: json['user_id'],
      content: json['content'],
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.sent,
      ),
      createdAt: DateTime.parse(json['created_at']),
      attachmentUrl: json['attachment_url'],
      attachmentType: json['attachment_type'],
      reactions: json['reactions'] != null
          ? Map<String, String>.from(json['reactions'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    final statusToSave =
        status == MessageStatus.sending ? MessageStatus.sent : status;

    return {
      'room_id': roomId,
      'user_id': userId,
      'content': content,
      'status': statusToSave.name,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (reactions != null) 'reactions': reactions,
    };
  }
}

enum MessageStatus { sent, delivered, read, sending }
