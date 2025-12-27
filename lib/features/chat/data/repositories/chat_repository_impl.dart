import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/chat/domain/entities/message.dart';
import 'package:gossip/features/chat/domain/entities/chat_room.dart';
import 'package:gossip/features/chat/domain/entities/friend_request.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:intl/intl.dart';

class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _supabase;

  SupabaseChatRepository(this._supabase);

  @override
  User? get currentUser => _supabase.auth.currentUser;

  @override
  Future<void> sendMessage(Message message) async {
    await _supabase.from('messages').insert(message.toJson());
  }

  @override
  Stream<List<Message>> getMessages(String roomId) {
    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .map((data) => data.map((json) => Message.fromJson(json)).toList());
  }

  @override
  Stream<List<ChatRoom>> getRooms() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value([]);

    final controller = StreamController<List<ChatRoom>>();

    // Combine friend_requests and messages triggers
    final friendsStream = _supabase
        .from('friend_requests')
        .stream(primaryKey: ['id']).map((data) => data
            .where((item) =>
                (item['sender_id'] == user.id ||
                    item['receiver_id'] == user.id) &&
                item['status'] == 'accepted')
            .toList());

    final messagesTrigger = _supabase
        .from('messages')
        .stream(primaryKey: ['id']); // Trigger on any message change

    StreamSubscription? friendsSub;
    StreamSubscription? messagesSub;

    void updateRooms() async {
      if (controller.isClosed) return;

      final friendsData = await _supabase
          .from('friend_requests')
          .select()
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .eq('status', 'accepted');

      final List<ChatRoom> rooms = [];

      // DMs from friends
      final List<String> friendIds = friendsData.map((item) {
        return item['sender_id'] == user.id
            ? item['receiver_id'] as String
            : item['sender_id'] as String;
      }).toList();

      // Bulk fetch profiles
      Map<String, dynamic> profilesMap = {};
      if (friendIds.isNotEmpty) {
        final profilesData = await _supabase
            .from('profiles')
            .select('id, username, avatar_url, gender')
            .inFilter('id', friendIds);
        for (var p in profilesData) {
          profilesMap[p['id']] = p;
        }
      }

      // Parallel fetch last messages and unread counts
      final futures = friendsData.map((item) async {
        final friendId = item['sender_id'] == user.id
            ? item['receiver_id']
            : item['sender_id'];
        final profile = profilesMap[friendId];

        final results = await Future.wait<dynamic>([
          _supabase
              .from('messages')
              .select('id, content, created_at, status, user_id')
              .eq('room_id', item['id'])
              .order('created_at', ascending: false)
              .limit(1)
              .maybeSingle(),
          _supabase
              .from('messages')
              .select('id')
              .eq('room_id', item['id'])
              .neq('user_id', user.id)
              .neq('status', 'read')
        ]);

        final lastMsgData = results[0] as Map<String, dynamic>?;
        final unreadResponse = results[1] as List<dynamic>;

        // Mark last message as delivered if we just received it in the room list
        if (lastMsgData != null &&
            lastMsgData['id'] != null &&
            lastMsgData['status'] == 'sent' &&
            lastMsgData['user_id'] != user.id) {
          markAsDelivered(lastMsgData['id']);
        }

        return ChatRoom(
          id: item['id'],
          name: profile?['username'] ?? 'Unknown',
          avatarUrl: profile?['avatar_url'],
          gender: profile?['gender'],
          lastMessage: lastMsgData?['content'] ?? 'Tap to gossip',
          time: lastMsgData != null
              ? DateFormat('HH:mm')
                  .format(DateTime.parse(lastMsgData['created_at']).toLocal())
              : null,
          unreadCount: unreadResponse.length,
          isGroup: false,
          lastMessageTime: lastMsgData != null
              ? DateTime.parse(lastMsgData['created_at'])
              : DateTime.parse(item['created_at']),
        );
      });

      rooms.addAll(await Future.wait(futures));

      // Groups (could also be parallelized if needed, but keeping it simple for now)
      try {
        final groupData =
            await _supabase.from('chat_rooms').select().eq('is_group', true);
        rooms.addAll((groupData as List).map((j) => ChatRoom.fromJson(j)));
      } catch (_) {}

      rooms.sort((a, b) {
        final timeA = a.lastMessageTime ?? DateTime(2000);
        final timeB = b.lastMessageTime ?? DateTime(2000);
        return timeB.compareTo(timeA);
      });

      if (!controller.isClosed) {
        controller.add(rooms);
      }
    }

    friendsSub = friendsStream.listen((_) => updateRooms());
    messagesSub = messagesTrigger.listen((_) => updateRooms());

    controller.onCancel = () {
      friendsSub?.cancel();
      messagesSub?.cancel();
      controller.close();
    };

    // Initial load
    updateRooms();

    return controller.stream;
  }

  @override
  Future<void> markAsRead(String roomId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Update messages to 'read' if they are not already and were sent by someone else
    await _supabase
        .from('messages')
        .update({'status': 'read'})
        .eq('room_id', roomId)
        .neq('user_id', user.id)
        .neq('status', 'read');
  }

  @override
  Future<void> markAsDelivered(String messageId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase
        .from('messages')
        .update({'status': 'delivered'})
        .eq('id', messageId)
        .neq('user_id', user.id)
        .neq('status', 'read')
        .neq('status', 'delivered');
  }

  @override
  Future<void> updateMessageReaction(String messageId, String? reaction) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final response = await _supabase
        .from('messages')
        .select('reactions')
        .eq('id', messageId)
        .single();
    final Map<String, dynamic> reactions =
        Map<String, dynamic>.from(response['reactions'] ?? {});

    if (reaction == null) {
      reactions.remove(user.id);
    } else {
      reactions[user.id] = reaction;
    }

    await _supabase
        .from('messages')
        .update({'reactions': reactions}).eq('id', messageId);
  }

  @override
  Future<void> setTypingStatus(String roomId, bool isTyping) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    final channel = _supabase.channel('typing_$roomId');

    // Always call subscribe, Supabase handles idempotent subscriptions
    channel.subscribe((status, [error]) async {
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (isTyping) {
          await channel.track({
            'user_id': user.id,
            'typing': true,
          });
        } else {
          await channel.untrack();
        }
      }
    });

    // If already subscribed, we still want to track/untrack immediately
    if (isTyping) {
      await channel.track({
        'user_id': user.id,
        'typing': true,
      });
    } else {
      await channel.untrack();
    }
  }

  @override
  Stream<String?> watchTypingStatus(String roomId) {
    final channel = _supabase.channel('typing_$roomId');
    final controller = StreamController<String?>();
    final myId = _supabase.auth.currentUser?.id;

    channel.onPresenceSync((payload) {
      final presenceState = channel.presenceState();
      bool anyoneTyping = false;
      String? typingUserId;

      for (final presence in presenceState) {
        final metas = (presence as dynamic).metas as List<dynamic>;
        if (metas.isNotEmpty) {
          final pMap = metas.first as Map<String, dynamic>;
          if (pMap['user_id'] != myId && pMap['typing'] == true) {
            anyoneTyping = true;
            typingUserId = pMap['user_id'] as String?;
            break;
          }
        }
      }

      controller.add(anyoneTyping ? typingUserId : null);
    }).subscribe();

    return controller.stream;
  }

  @override
  Stream<List<FriendRequest>> getFriendRequests() {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return Stream.value([]);

    return _supabase
        .from('friend_requests')
        .stream(primaryKey: ['id'])
        .order('created_at')
        .map((data) => data
            .where((item) =>
                item['receiver_id'] == myId && item['status'] == 'pending')
            .toList())
        .asyncMap((data) async {
          final List<FriendRequest> requests = [];
          for (var item in data) {
            final senderId = item['sender_id'];
            final profile = await _supabase
                .from('profiles')
                .select()
                .eq('id', senderId)
                .maybeSingle();
            requests.add(FriendRequest(
              id: item['id'],
              senderId: senderId,
              senderName: profile?['username'] ?? 'Unknown',
              senderAvatar: profile?['avatar_url'],
              timestamp: DateTime.parse(item['created_at']),
            ));
          }
          return requests;
        });
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'accepted'}).eq('id', requestId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> rejectFriendRequest(String requestId) async {
    try {
      await _supabase
          .from('friend_requests')
          .update({'status': 'rejected'}).eq('id', requestId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> sendFriendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Check if request already exists
    final existing = await _supabase
        .from('friend_requests')
        .select()
        .or('and(sender_id.eq.${user.id},receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.${user.id})')
        .maybeSingle();

    if (existing != null) {
      // If it was rejected, we can update it to pending again
      if (existing['status'] == 'rejected') {
        await _supabase.from('friend_requests').update({
          'status': 'pending',
          'sender_id': user.id,
          'receiver_id': receiverId,
        }).eq('id', existing['id']);
      }
      return;
    }

    await _supabase.from('friend_requests').insert({
      'sender_id': user.id,
      'receiver_id': receiverId,
      'status': 'pending',
    });
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];

    final user = _supabase.auth.currentUser;
    // Search for users, but filter out current user and existing friends
    final response = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%$query%')
        .neq('id', user?.id ?? '')
        .limit(20);

    return List<Map<String, dynamic>>.from(response);
  }

  @override
  Future<List<Map<String, dynamic>>> getContacts() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final response = await _supabase
        .from('friend_requests')
        .select('sender_id, receiver_id, status')
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'accepted');

    final List<String> friendIds = [];
    for (var item in response) {
      if (item['sender_id'] == user.id) {
        friendIds.add(item['receiver_id']);
      } else {
        friendIds.add(item['sender_id']);
      }
    }

    if (friendIds.isEmpty) return [];

    final profiles = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', friendIds);

    return (profiles as List)
        .map((p) => {
              'id': p['id'],
              'name': p['username'] ?? 'Unknown',
              'avatar': p['avatar_url'],
            })
        .toList();
  }

  @override
  Future<ChatRoom> createGroup({
    required String name,
    required List<String> memberIds,
    String? bio,
    String? avatarUrl,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not logged in');

    // Create a real record in chat_rooms table
    final room = await _supabase
        .from('chat_rooms')
        .insert({
          'name': name,
          'last_message': 'Group created',
          'is_group': true,
          'admin_id': user.id,
          // You would likely have a chat_participants table for the member IDs
        })
        .select()
        .single();

    return ChatRoom.fromJson(room);
  }

  @override
  Future<void> updateGroupInfo(String roomId,
      {String? name, String? bio, String? avatarUrl}) async {
    await _supabase.from('chat_rooms').update({
      if (name != null) 'name': name,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', roomId);
  }

  @override
  Future<void> removeMember(String roomId, String userId) async {
    // Logic for chat_participants if implemented
  }
}
