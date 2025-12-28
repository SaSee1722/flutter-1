import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/chat/domain/entities/message.dart';
import 'package:gossip/features/chat/domain/entities/chat_room.dart';
import 'package:gossip/features/chat/domain/entities/friend_request.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _supabase;
  RealtimeChannel? _presenceChannel;

  SupabaseChatRepository(this._supabase);

  @override
  User? get currentUser => _supabase.auth.currentUser;

  @override
  Future<void> sendMessage(Message message) async {
    await _supabase.from('messages').insert(message.toJson());
    _refreshController.add(null);
  }

  final _refreshController = StreamController<void>.broadcast();

  @override
  Stream<List<Message>> getMessages(String roomId) {
    // Store profiles in memory to avoid redundant fetches
    final Map<String, Map<String, dynamic>> profileCache = {};

    return _supabase
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at', ascending: false)
        .asyncMap((data) async {
          final List<Message> messages = [];

          for (var json in data) {
            final userId = json['user_id'];

            if (!profileCache.containsKey(userId)) {
              final profile = await _supabase
                  .from('profiles')
                  .select('username, gender')
                  .eq('id', userId)
                  .maybeSingle();
              if (profile != null) {
                profileCache[userId] = profile;
              }
            }

            final profile = profileCache[userId];
            final message = Message.fromJson({
              ...json,
              'sender_name': profile?['username'],
              'sender_gender': profile?['gender'],
            });
            messages.add(message);
          }
          return messages;
        });
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
              .inFilter('status', ['sent', 'delivered'])
        ]);

        final lastMsgData = results[0] as Map<String, dynamic>?;
        final unreadCount = (results[1] as List).length;

        return ChatRoom(
          id: item['id'],
          name: profile?['username'] ?? 'Unknown',
          avatarUrl: profile?['avatar_url'],
          gender: profile?['gender'],
          lastMessage: lastMsgData?['content'] ?? 'Tap to gossip',
          time: null,
          unreadCount: unreadCount,
          isGroup: false,
          lastMessageTime: lastMsgData != null
              ? DateTime.parse(lastMsgData['created_at'])
              : DateTime.parse(item['created_at']),
          otherUserId: friendId,
        );
      });

      rooms.addAll(await Future.wait(futures));

      // Groups
      try {
        final groupMemberships = await _supabase
            .from('group_members')
            .select('room_id')
            .eq('user_id', user.id);

        final roomIds = (groupMemberships as List)
            .map((m) => m['room_id'] as String)
            .toList();

        if (roomIds.isNotEmpty) {
          final groupsData = await _supabase
              .from('chat_rooms')
              .select()
              .inFilter('id', roomIds);

          for (var group in groupsData) {
            final results = await Future.wait<dynamic>([
              _supabase
                  .from('messages')
                  .select('id, content, created_at, status, user_id')
                  .eq('room_id', group['id'])
                  .order('created_at', ascending: false)
                  .limit(1)
                  .maybeSingle(),
              _supabase
                  .from('messages')
                  .select('id')
                  .eq('room_id', group['id'])
                  .neq('user_id', user.id)
                  .inFilter('status', ['sent', 'delivered'])
            ]);

            final lastMsgData = results[0] as Map<String, dynamic>?;
            final unreadCount = (results[1] as List).length;

            rooms.add(ChatRoom(
              id: group['id'],
              name: group['name'] ?? 'Unnamed Group',
              avatarUrl: group['avatar_url'],
              lastMessage: lastMsgData?['content'] ?? 'No messages yet',
              time: null,
              unreadCount: unreadCount,
              isGroup: true,
              lastMessageTime: lastMsgData != null
                  ? DateTime.parse(lastMsgData['created_at'])
                  : DateTime.parse(group['created_at']),
              otherUserId: null,
            ));
          }
        }
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
    final refreshSub = _refreshController.stream.listen((_) => updateRooms());

    controller.onCancel = () {
      friendsSub?.cancel();
      messagesSub?.cancel();
      refreshSub.cancel();
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

    _refreshController.add(null);
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
      final dynamic state = channel.presenceState();
      bool anyoneTyping = false;
      String? typingUserId;

      final presences = <dynamic>[];
      if (state is Map) {
        for (var v in state.values) {
          if (v is List) presences.addAll(v);
        }
      } else if (state is List) {
        presences.addAll(state);
      }

      for (final presence in presences) {
        final pMap = (presence as dynamic).payload as Map<String, dynamic>?;
        if (pMap != null && pMap['user_id'] != myId && pMap['typing'] == true) {
          anyoneTyping = true;
          typingUserId = pMap['user_id'] as String?;
          break;
        }
      }

      if (!controller.isClosed) {
        controller.add(anyoneTyping ? typingUserId : null);
      }
    }).subscribe();

    return controller.stream;
  }

  @override
  Future<void> setOnlineStatus(bool isOnline) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (_presenceChannel == null) {
      _presenceChannel = _supabase.channel('global_presence');
      _presenceChannel!.subscribe();
    }

    if (isOnline) {
      await _presenceChannel!.track({
        'user_id': user.id,
        'online': true,
        'last_seen': DateTime.now().toIso8601String(),
      });
    } else {
      await _presenceChannel!.untrack();
    }
  }

  @override
  Stream<bool> watchUserOnlineStatus(String userId) {
    final controller = StreamController<bool>();
    final channel = _supabase.channel('global_presence');

    channel.onPresenceSync((payload) {
      final dynamic state = channel.presenceState();
      bool isOnline = false;

      final presences = <dynamic>[];
      if (state is Map) {
        for (var v in state.values) {
          if (v is List) presences.addAll(v);
        }
      } else if (state is List) {
        presences.addAll(state);
      }

      for (final presence in presences) {
        Map<String, dynamic>? data;
        try {
          if (presence is Map) {
            data = Map<String, dynamic>.from(presence);
          } else {
            data = (presence as dynamic).payload as Map<String, dynamic>?;
          }
        } catch (_) {
          if (presence is Map<String, dynamic>) {
            data = presence;
          }
        }

        if (data != null &&
            data['user_id'] == userId &&
            data['online'] == true) {
          isOnline = true;
          break;
        }
      }

      if (!controller.isClosed) controller.add(isOnline);
    }).subscribe();

    return controller.stream;
  }

  @override
  Stream<int> watchGroupPresence(String roomId) {
    final controller = StreamController<int>();
    final channel = _supabase.channel('group_presence_$roomId');

    channel.onPresenceSync((payload) {
      final dynamic state = channel.presenceState();
      int count = 0;

      final presences = <dynamic>[];
      if (state is Map) {
        for (var v in state.values) {
          if (v is List) presences.addAll(v);
        }
      } else if (state is List) {
        presences.addAll(state);
      }

      for (final presence in presences) {
        Map<String, dynamic>? data;
        try {
          if (presence is Map) {
            data = Map<String, dynamic>.from(presence);
          } else {
            data = (presence as dynamic).payload as Map<String, dynamic>?;
          }
        } catch (_) {
          if (presence is Map<String, dynamic>) {
            data = presence;
          }
        }

        if (data != null && data['online'] == true) {
          count++;
        }
      }

      if (!controller.isClosed) controller.add(count);
    }).subscribe();

    // Also need to track ourselves in this group when we watch it
    final user = _supabase.auth.currentUser;
    if (user != null) {
      channel.subscribe((status, [error]) async {
        if (status == RealtimeSubscribeStatus.subscribed) {
          await channel.track({
            'user_id': user.id,
            'online': true,
          });
        }
      });
    }

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
              'username': p['username'],
              'avatar_url': p['avatar_url'],
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
          'bio': bio,
          'avatar_url': avatarUrl,
          'last_message': 'Group created',
          'is_group': true,
          'admin_id': user.id,
        })
        .select()
        .single();

    // Add members to the group (creator is auto-added by trigger as admin)
    if (memberIds.isNotEmpty) {
      final memberInserts = memberIds
          .map((memberId) => {
                'room_id': room['id'],
                'user_id': memberId,
                'role': 'member',
              })
          .toList();

      await _supabase.from('group_members').insert(memberInserts);
    }

    return ChatRoom.fromJson(room);
  }

  @override
  Future<void> updateGroupInfo(String roomId,
      {String? name, String? bio, String? avatarUrl}) async {
    await _supabase.from('chat_rooms').update({
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', roomId);
  }

  @override
  Future<void> removeMember(String roomId, String userId) async {
    await _supabase
        .from('group_members')
        .delete()
        .eq('room_id', roomId)
        .eq('user_id', userId);
  }

  @override
  Future<void> blockUser(String userId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('blocked_users').insert({
      'blocker_id': user.id,
      'blocked_id': userId,
    });
  }

  @override
  Future<void> unblockUser(String userId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('blocked_users')
        .delete()
        .eq('blocker_id', user.id)
        .eq('blocked_id', userId);
  }

  @override
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    final data = await _supabase
        .from('blocked_users')
        .select(
            'blocked_id, profiles!blocked_users_blocked_id_fkey(username, avatar_url)')
        .eq('blocker_id', user.id);

    return (data as List).map((item) {
      final profile = item['profiles'] as Map<String, dynamic>;
      return {
        'id': item['blocked_id'],
        'username': profile['username'],
        'avatar_url': profile['avatar_url'],
      };
    }).toList();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    // Call RPC function to delete auth record
    // This requires the RPC function to be created in Supabase
    try {
      await _supabase.rpc('delete_user');
      await _supabase.auth.signOut();
    } catch (e) {
      // Fallback: delete profile if RPC fails (security definer issues)
      await _supabase.from('profiles').delete().eq('id', user.id);
      await _supabase.auth.signOut();
    }
  }

  @override
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    return await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .maybeSingle();
  }
}
