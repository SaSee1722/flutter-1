import '../entities/message.dart';
import '../entities/chat_room.dart';
import '../entities/friend_request.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class ChatRepository {
  User? get currentUser;
  Future<void> sendMessage(Message message);
  Stream<List<Message>> getMessages(String roomId);
  Stream<List<ChatRoom>> getRooms();
  Future<void> markAsRead(String roomId);
  Future<void> markAsDelivered(String messageId);
  Future<void> updateMessageReaction(String messageId, String? reaction);

  // Typing & Presence
  Future<void> setTypingStatus(String roomId, bool isTyping);
  Stream<String?> watchTypingStatus(String roomId);
  Future<void> setOnlineStatus(bool isOnline);
  Stream<bool> watchUserOnlineStatus(String userId);
  Stream<int> watchGroupPresence(String roomId);

  // Privacy & Account
  Future<void> blockUser(String userId);
  Future<void> unblockUser(String userId);
  Future<List<Map<String, dynamic>>> getBlockedUsers();
  Future<void> deleteAccount();

  // Friend Requests
  Stream<List<FriendRequest>> getFriendRequests();
  Future<void> acceptFriendRequest(String requestId);
  Future<void> rejectFriendRequest(String requestId);
  Future<void> sendFriendRequest(String receiverId);
  Future<List<Map<String, dynamic>>> searchUsers(String query);

  // Contacts/Friends
  Future<List<Map<String, dynamic>>> getContacts();

  // Groups
  Future<ChatRoom> createGroup({
    required String name,
    required List<String> memberIds,
    String? bio,
    String? avatarUrl,
  });
  Future<void> updateGroupInfo(String roomId,
      {String? name, String? bio, String? avatarUrl});
  Future<void> removeMember(String roomId, String userId);
}
