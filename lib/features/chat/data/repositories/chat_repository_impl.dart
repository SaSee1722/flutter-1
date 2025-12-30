import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/chat/domain/entities/message.dart';
import 'package:gossip/features/chat/domain/entities/chat_room.dart';
import 'package:gossip/features/chat/domain/entities/friend_request.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _supabase;
  RealtimeChannel? _presenceChannel;
  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, bool> _typingCache = {};

  // For centralized stream management to avoid memory leaks/log spam
  final Map<String, StreamController<bool>> _onlineControllers = {};
  final Map<String, StreamController<String?>> _typingControllers = {};
  final Map<String, StreamController<int>> _groupPresenceControllers = {};

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

      final roomIds = friendsData.map((item) => item['id'] as String).toList();

      // Groups
      List<dynamic> groupsData = [];
      try {
        final groupMemberships = await _supabase
            .from('group_members')
            .select('room_id')
            .eq('user_id', user.id);

        final groupRoomIds = (groupMemberships as List)
            .map((m) => m['room_id'] as String)
            .toList();

        if (groupRoomIds.isNotEmpty) {
          groupsData = await _supabase
              .from('chat_rooms')
              .select()
              .inFilter('id', groupRoomIds);
          roomIds.addAll(groupRoomIds);
        }
      } catch (_) {}

      if (roomIds.isEmpty) {
        if (!controller.isClosed) controller.add([]);
        return;
      }

      // 1. BATCH FETCH UNREAD COUNTS
      final unreadMessages = await _supabase
          .from('messages')
          .select('room_id')
          .inFilter('room_id', roomIds)
          .neq('user_id', user.id)
          .inFilter('status', ['sent', 'delivered']);

      final Map<String, int> unreadCountsMap = {};
      for (var msg in (unreadMessages as List)) {
        final rId = msg['room_id'] as String;
        unreadCountsMap[rId] = (unreadCountsMap[rId] ?? 0) + 1;
      }

      // 2. BULK FETCH PROFILES
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

      // 3. PARALLEL FETCH LAST MESSAGES
      final friendFutures = friendsData.map((item) async {
        final friendId = item['sender_id'] == user.id
            ? item['receiver_id']
            : item['sender_id'];
        final profile = profilesMap[friendId];

        final lastMsgData = await _supabase
            .from('messages')
            .select('id, content, created_at, status, user_id')
            .eq('room_id', item['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        return ChatRoom(
          id: item['id'],
          name: profile?['username'] ?? 'Unknown',
          avatarUrl: profile?['avatar_url'],
          gender: profile?['gender'],
          lastMessage: lastMsgData?['content'] ?? 'Tap to gossip',
          time: null,
          unreadCount: unreadCountsMap[item['id']] ?? 0,
          isGroup: false,
          lastMessageTime: lastMsgData != null
              ? DateTime.parse(lastMsgData['created_at'])
              : DateTime.parse(item['created_at']),
          otherUserId: friendId,
        );
      });

      final groupFutures = groupsData.map((group) async {
        final lastMsgData = await _supabase
            .from('messages')
            .select('id, content, created_at, status, user_id')
            .eq('room_id', group['id'])
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        return ChatRoom(
          id: group['id'],
          name: group['name'] ?? 'Unnamed Group',
          avatarUrl: group['avatar_url'],
          lastMessage: lastMsgData?['content'] ?? 'No messages yet',
          time: null,
          unreadCount: unreadCountsMap[group['id']] ?? 0,
          isGroup: true,
          lastMessageTime: lastMsgData != null
              ? DateTime.parse(lastMsgData['created_at'])
              : DateTime.parse(group['created_at']),
          otherUserId: null,
        );
      });

      rooms.addAll(await Future.wait([...friendFutures, ...groupFutures]));

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

    // Avoid redundant calls
    if (_typingCache[roomId] == isTyping) return;
    _typingCache[roomId] = isTyping;

    try {
      if (!_typingChannels.containsKey(roomId)) {
        final channel = _supabase.channel('typing_$roomId');
        channel.subscribe();
        _typingChannels[roomId] = channel;
      }

      final channel = _typingChannels[roomId]!;
      if (isTyping) {
        await channel.track({
          'user_id': user.id,
          'typing': true,
        });
      } else {
        await channel.untrack();
      }
    } catch (e) {
      debugPrint('Error setting typing status: $e');
      _typingCache.remove(roomId); // Reset cache on error
    }
  }

  @override
  Stream<String?> watchTypingStatus(String roomId) {
    if (_typingControllers.containsKey(roomId)) {
      return _typingControllers[roomId]!.stream;
    }

    final controller = StreamController<String?>.broadcast();
    _typingControllers[roomId] = controller;

    final myId = _supabase.auth.currentUser?.id;
    final channel = _supabase.channel('typing_$roomId');

    channel.onPresenceSync((payload) {
      final dynamic state = channel.presenceState();
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
        Map<String, dynamic>? pMap;
        try {
          if (presence is Map) {
            pMap = Map<String, dynamic>.from(presence);
          } else if (presence is Presence) {
            pMap = presence.payload;
          } else {
            pMap = (presence as dynamic).payload as Map<String, dynamic>?;
          }
        } catch (_) {
          try {
            pMap = (presence as dynamic) as Map<String, dynamic>?;
          } catch (_) {}
        }

        if (pMap != null && pMap['user_id'] != myId && pMap['typing'] == true) {
          typingUserId = pMap['user_id'] as String?;
          break;
        }
      }

      if (typingUserId != null) {
        debugPrint('[Typing] Detected typing user: $typingUserId');
      }

      if (!controller.isClosed) {
        controller.add(typingUserId);
      }
    });

    channel.subscribe();

    // Trigger initial check
    Timer.run(() {
      if (!controller.isClosed) {
        final dynamic state = channel.presenceState();
        final presences = <dynamic>[];
        if (state is Map) {
          for (var v in state.values) {
            if (v is List) presences.addAll(v);
          }
        } else if (state is List) {
          presences.addAll(state);
        }

        String? typingId;
        for (final p in presences) {
          final data = _parsePresenceData(p);
          if (data != null &&
              data['user_id'] != myId &&
              data['typing'] == true) {
            typingId = data['user_id']?.toString();
            break;
          }
        }
        controller.add(typingId);
      }
    });

    controller.onCancel = () {
      _typingControllers.remove(roomId);
      if (controller.hasListener == false) {
        controller.close();
      }
    };

    return controller.stream;
  }

  @override
  Future<void> setOnlineStatus(bool isOnline) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      if (_presenceChannel == null) {
        _presenceChannel = _supabase.channel('global_presence');

        final completer = Completer<void>();
        _presenceChannel!.subscribe((status, [error]) {
          debugPrint('Presence channel status: $status');
          if (status == RealtimeSubscribeStatus.subscribed) {
            if (!completer.isCompleted) completer.complete();
          } else if (error != null) {
            if (!completer.isCompleted) completer.completeError(error);
          }
        });

        await completer.future
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => debugPrint('Presence channel timeout'),
            )
            .catchError((e) => debugPrint('Presence subscription error: $e'));
      }

      if (isOnline) {
        await _presenceChannel!.track({
          'user_id': user.id,
          'online': true,
          'last_seen': DateTime.now().toIso8601String(),
        });
        debugPrint('Online status set to true for user: ${user.id}');
      } else {
        await _presenceChannel!.untrack();
        debugPrint('Online status set to false for user: ${user.id}');
      }
    } catch (e) {
      debugPrint('Error setting online status: $e');
      _presenceChannel = null;
    }
  }

  @override
  Stream<bool> watchUserOnlineStatus(String userId) {
    if (_onlineControllers.containsKey(userId)) {
      return _onlineControllers[userId]!.stream;
    }

    final controller = StreamController<bool>.broadcast();
    _onlineControllers[userId] = controller;

    if (_presenceChannel == null) {
      _presenceChannel = _supabase.channel('global_presence');

      _presenceChannel!.onPresenceSync((payload) {
        final dynamic state = _presenceChannel!.presenceState();

        final allPresences = <dynamic>[];
        if (state is Map) {
          for (var v in state.values) {
            if (v is List) allPresences.addAll(v);
          }
        } else if (state is List) {
          allPresences.addAll(state);
        }

        // Notify all active watchers
        _onlineControllers.forEach((id, ctrl) {
          bool isUserOnline = false;
          for (final presence in allPresences) {
            Map<String, dynamic>? data;
            try {
              if (presence is Map) {
                data = Map<String, dynamic>.from(presence);
              } else if (presence is Presence) {
                data = presence.payload;
              } else {
                data = (presence as dynamic).payload as Map<String, dynamic>?;
              }
            } catch (_) {
              try {
                data = (presence as dynamic) as Map<String, dynamic>?;
              } catch (_) {}
            }

            if (data != null &&
                data['user_id']?.toString() == id &&
                data['online'] == true) {
              isUserOnline = true;
              break;
            }
          }
          if (!ctrl.isClosed) ctrl.add(isUserOnline);
        });
      });

      _presenceChannel!.subscribe();
    }

    // Initial check for this user
    Timer.run(() {
      if (!controller.isClosed) {
        final dynamic state = _presenceChannel!.presenceState();
        final allPresences = <dynamic>[];
        if (state is Map) {
          for (var v in state.values) {
            if (v is List) allPresences.addAll(v);
          }
        } else if (state is List) {
          allPresences.addAll(state);
        }

        bool isOnline = false;
        for (final p in allPresences) {
          final data = _parsePresenceData(p);
          if (data != null &&
              data['user_id']?.toString() == userId &&
              data['online'] == true) {
            isOnline = true;
            break;
          }
        }
        controller.add(isOnline);
      }
    });

    controller.onCancel = () {
      _onlineControllers.remove(userId);
      if (controller.hasListener == false) {
        controller.close();
      }
    };

    return controller.stream;
  }

  @override
  Stream<int> watchGroupPresence(String roomId) {
    if (_groupPresenceControllers.containsKey(roomId)) {
      return _groupPresenceControllers[roomId]!.stream;
    }

    final controller = StreamController<int>.broadcast();
    _groupPresenceControllers[roomId] = controller;

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
        } catch (_) {}

        if (data != null && data['online'] == true) {
          count++;
        }
      }

      if (!controller.isClosed) controller.add(count);
    });

    final user = _supabase.auth.currentUser;
    channel.subscribe((status, [error]) {
      if (status == RealtimeSubscribeStatus.subscribed && user != null) {
        channel.track({'user_id': user.id, 'online': true});
      }
    });

    controller.onCancel = () {
      _groupPresenceControllers.remove(roomId);
      if (controller.hasListener == false) {
        controller.close();
      }
    };

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
    // Search for users, but filter out current user
    final response = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%$query%')
        .eq('is_public', true)
        .neq('id', user?.id ?? '')
        .limit(20);

    final results = List<Map<String, dynamic>>.from(response);

    if (user != null && results.isNotEmpty) {
      // Get all friend requests involving the current user and these search results
      final userIds = results.map((u) => u['id']).toList();
      final requests = await _supabase
          .from('friend_requests')
          .select()
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .inFilter('sender_id', userIds.followedBy([user.id]).toList())
          .inFilter('receiver_id', userIds.followedBy([user.id]).toList());

      for (var result in results) {
        final request =
            (requests as List).cast<Map<String, dynamic>?>().firstWhere(
                  (r) =>
                      r != null &&
                      ((r['sender_id'] == user.id &&
                              r['receiver_id'] == result['id']) ||
                          (r['receiver_id'] == user.id &&
                              r['sender_id'] == result['id'])),
                  orElse: () => null,
                );

        if (request != null) {
          result['friendship_status'] = request['status'];
        } else {
          result['friendship_status'] = 'none';
        }
      }
    }

    return results;
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
    await _supabase.from('blocked_users').upsert({
      'blocker_id': user.id,
      'blocked_id': userId,
    }, onConflict: 'blocker_id, blocked_id');
  }

  @override
  Future<bool> isUserBlocked(String userId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final response = await _supabase
        .from('blocked_users')
        .select()
        .eq('blocker_id', user.id)
        .eq('blocked_id', userId)
        .maybeSingle();

    return response != null;
  }

  @override
  Future<bool> amIBlockedBy(String userId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final response = await _supabase
        .from('blocked_users')
        .select()
        .eq('blocker_id', userId)
        .eq('blocked_id', user.id)
        .maybeSingle();

    return response != null;
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

    final userId = user.id;

    // 1. Clean up Storage Buckets
    final buckets = [
      'avatars',
      'vibe-media',
      'chat-media',
      'chat-documents',
      'chat-audio',
      'group_avatars'
    ];

    for (final bucket in buckets) {
      try {
        // List all files in the user's folder
        final files = await _supabase.storage.from(bucket).list(path: userId);
        if (files.isNotEmpty) {
          final pathsToDelete =
              files.map((file) => '$userId/${file.name}').toList();
          await _supabase.storage.from(bucket).remove(pathsToDelete);
        }
      } catch (e) {
        debugPrint('Error cleaning up bucket $bucket: $e');
      }
    }

    // 2. Delete data from tables (most should be handled by CASCADE, but for safety)
    try {
      // Delete statuses/vibes
      await _supabase.from('statuses').delete().eq('user_id', userId);
      // Delete friend requests
      await _supabase
          .from('friend_requests')
          .delete()
          .or('sender_id.eq.$userId,receiver_id.eq.$userId');
      // Delete messages
      await _supabase.from('messages').delete().eq('user_id', userId);
    } catch (e) {
      debugPrint('Error cleaning up tables: $e');
    }

    // 3. Call RPC function to delete auth record (which should delete profile via trigger/cascade)
    try {
      await _supabase.rpc('delete_user');
      await _supabase.auth.signOut();
    } catch (e) {
      // Fallback: delete profile if RPC fails or is missing
      try {
        await _supabase.from('profiles').delete().eq('id', userId);
      } catch (_) {}
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

  Map<String, dynamic>? _parsePresenceData(dynamic presence) {
    try {
      if (presence is Map) return Map<String, dynamic>.from(presence);
      if (presence is Presence) return presence.payload;
      return (presence as dynamic).payload as Map<String, dynamic>?;
    } catch (_) {
      try {
        return (presence as dynamic) as Map<String, dynamic>?;
      } catch (_) {
        return null;
      }
    }
  }
}
