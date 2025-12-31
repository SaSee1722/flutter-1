import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/chat/domain/entities/message.dart';
import 'package:gossip/features/chat/domain/entities/chat_room.dart';
import 'package:gossip/features/chat/domain/entities/friend_request.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';

class SupabaseChatRepository implements ChatRepository {
  final SupabaseClient _supabase;
  final Map<String, RealtimeChannel> _typingChannels = {};
  final Map<String, bool> _typingCache = {};

  final Map<String, StreamController<bool>> _onlineControllers = {};
  final Map<String, StreamController<String?>> _typingControllers = {};
  final Map<String, StreamController<int>> _groupPresenceControllers = {};

  RealtimeChannel? _globalPresenceChannel;
  bool _isGlobalPresenceSubscribed = false;

  SupabaseChatRepository(this._supabase);

  @override
  User? get currentUser => _supabase.auth.currentUser;

  final _refreshController = StreamController<void>.broadcast();

  @override
  Future<void> sendMessage(Message message) async {
    await _supabase.from('messages').insert(message.toJson());
    _refreshController.add(null);
  }

  @override
  Stream<List<Message>> getMessages(String roomId) {
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
            messages.add(Message.fromJson({
              ...json,
              'sender_name': profile?['username'],
              'sender_gender': profile?['gender'],
            }));
          }
          return messages;
        });
  }

  @override
  Stream<List<ChatRoom>> getRooms() {
    final user = _supabase.auth.currentUser;
    if (user == null) return Stream.value([]);
    final controller = StreamController<List<ChatRoom>>();

    final friendsStream = _supabase
        .from('friend_requests')
        .stream(primaryKey: ['id']).map((data) => data
            .where((item) =>
                (item['sender_id'] == user.id ||
                    item['receiver_id'] == user.id) &&
                item['status'] == 'accepted')
            .toList());

    final messagesTrigger =
        _supabase.from('messages').stream(primaryKey: ['id']);

    void updateRooms() async {
      if (controller.isClosed) return;
      final friendsData = await _supabase
          .from('friend_requests')
          .select()
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .eq('status', 'accepted');

      final List<String> friendIds = friendsData.map((item) {
        return item['sender_id'] == user.id
            ? item['receiver_id'] as String
            : item['sender_id'] as String;
      }).toList();

      final roomIds = friendsData.map((item) => item['id'] as String).toList();
      List<dynamic> groupsData = [];
      try {
        final memberships = await _supabase
            .from('group_members')
            .select('room_id')
            .eq('user_id', user.id);
        final groupRoomIds =
            (memberships as List).map((m) => m['room_id'] as String).toList();
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

      final friendFutures = friendsData.map((item) async {
        final friendId = item['sender_id'] == user.id
            ? item['receiver_id']
            : item['sender_id'];
        final profile = profilesMap[friendId];
        final lastMsgData = await _supabase
            .from('messages')
            .select()
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
            .select()
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

      final results = await Future.wait([...friendFutures, ...groupFutures]);
      results.sort((a, b) => (b.lastMessageTime ?? DateTime(2000))
          .compareTo(a.lastMessageTime ?? DateTime(2000)));
      if (!controller.isClosed) controller.add(results);
    }

    final friendsSub = friendsStream.listen((_) => updateRooms());
    final messagesSub = messagesTrigger.listen((_) => updateRooms());
    final refreshSub = _refreshController.stream.listen((_) => updateRooms());

    controller.onCancel = () {
      friendsSub.cancel();
      messagesSub.cancel();
      refreshSub.cancel();
      controller.close();
    };

    updateRooms();
    return controller.stream;
  }

  @override
  Future<void> markAsRead(String roomId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
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
    if (_typingCache[roomId] == isTyping) return;
    _typingCache[roomId] = isTyping;
    try {
      if (!_typingChannels.containsKey(roomId)) {
        _typingChannels[roomId] = _supabase.channel('typing_$roomId')
          ..subscribe();
      }
      final channel = _typingChannels[roomId]!;
      if (isTyping) {
        await channel.track({'user_id': user.id, 'typing': true});
      } else {
        await channel.untrack();
      }
    } catch (_) {
      _typingCache.remove(roomId);
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
      String? typingId;
      final List presences = _extractPresenceList(channel.presenceState());

      for (final v in presences) {
        final d = _parsePresenceData(v);
        if (d != null && d['user_id'] != myId && d['typing'] == true) {
          typingId = d['user_id']?.toString();
          break;
        }
        if (typingId != null) break;
      }
      if (!controller.isClosed) controller.add(typingId);
    });
    channel.subscribe();
    controller.onCancel = () {
      _typingControllers.remove(roomId);
      if (!controller.hasListener) controller.close();
    };
    return controller.stream;
  }

  @override
  Future<void> setOnlineStatus(bool isOnline) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) {
      debugPrint('[Presence] Cannot set online status - no user ID');
      return;
    }
    debugPrint('[Presence] Setting online status to $isOnline for user $myId');
    _ensureGlobalPresenceChannel();
    if (_isGlobalPresenceSubscribed) {
      if (isOnline) {
        await _globalPresenceChannel!.track({
          'user_id': myId,
          'online': true,
          'last_seen': DateTime.now().toIso8601String()
        });
        debugPrint('[Presence] Tracked online status for $myId');
      } else {
        await _globalPresenceChannel!.untrack();
        debugPrint('[Presence] Untracked presence for $myId');
      }
    } else {
      debugPrint(
          '[Presence] Channel not yet subscribed, status will be set after subscription');
    }
  }

  @override
  Stream<bool> watchUserOnlineStatus(String userId) {
    debugPrint('[Presence] Starting to watch online status for user: $userId');
    if (_onlineControllers.containsKey(userId)) {
      debugPrint('[Presence] Returning existing stream for $userId');
      return _onlineControllers[userId]!.stream;
    }
    final controller = StreamController<bool>.broadcast();
    _onlineControllers[userId] = controller;
    _ensureGlobalPresenceChannel();
    void update() {
      if (controller.isClosed) return;
      final dynamic state = _globalPresenceChannel?.presenceState();
      if (state == null) {
        debugPrint('[Presence] State is null for $userId');
        return;
      }
      bool isOnline = false;
      final List presences = _extractPresenceList(state);
      debugPrint(
          '[Presence] Checking ${presences.length} presences for user $userId');

      for (final v in presences) {
        debugPrint('[Presence] Raw presence item: $v (type: ${v.runtimeType})');
        final d = _parsePresenceData(v);
        if (d != null) {
          debugPrint('[Presence] Parsed presence data: $d');
          debugPrint(
              '[Presence] Found presence data: user_id=${d['user_id']}, online=${d['online']}');
          if (d['user_id']?.toString() == userId && d['online'] == true) {
            isOnline = true;
            break;
          }
        } else {
          debugPrint('[Presence] Failed to parse presence data from: $v');
        }
        if (isOnline) break;
      }
      debugPrint('[Presence] User $userId online status: $isOnline');
      if (!controller.isClosed) controller.add(isOnline);
    }

    // Notify immediately on sync
    _globalPresenceChannel!.onPresenceSync((payload) {
      debugPrint('[Presence] Presence sync triggered for $userId');
      update();
    });

    // Trigger initial check after a short delay to allow subscription to settle
    Timer(const Duration(milliseconds: 500), update);
    controller.onCancel = () {
      _onlineControllers.remove(userId);
      if (!controller.hasListener) controller.close();
    };
    return controller.stream;
  }

  void _ensureGlobalPresenceChannel() {
    if (_globalPresenceChannel != null) {
      if (!_isGlobalPresenceSubscribed) {
        debugPrint(
            '[Presence] Subscribing to existing global presence channel');
        _globalPresenceChannel!.subscribe();
      }
      return;
    }
    debugPrint('[Presence] Creating new global presence channel');
    _globalPresenceChannel = _supabase.channel('global_presence',
        opts: const RealtimeChannelConfig(self: true));
    _globalPresenceChannel!.onPresenceSync((payload) {
      debugPrint('[Presence] Global presence sync event received');
      for (var entry in _onlineControllers.entries) {
        final userId = entry.key;
        final controller = entry.value;
        bool isOnline = false;
        final List presences =
            _extractPresenceList(_globalPresenceChannel!.presenceState());
        debugPrint(
            '[Presence] Syncing ${presences.length} presences for tracked user $userId');

        for (final v in presences) {
          final d = _parsePresenceData(v);
          if (d != null &&
              d['user_id']?.toString() == userId &&
              d['online'] == true) {
            isOnline = true;
            break;
          }
          if (isOnline) break;
        }
        if (!controller.isClosed) controller.add(isOnline);
      }
    });
    _globalPresenceChannel!.subscribe((status, [error]) {
      debugPrint('[Presence] Subscription status: $status, error: $error');
      if (status == RealtimeSubscribeStatus.subscribed) {
        _isGlobalPresenceSubscribed = true;
        debugPrint('[Presence] Successfully subscribed to global presence');
        setOnlineStatus(true);
      }
    });
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
      int count = 0;
      final List presences = _extractPresenceList(channel.presenceState());

      for (final v in presences) {
        final d = _parsePresenceData(v);
        if (d != null && d['online'] == true) {
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
      if (!controller.hasListener) controller.close();
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
            final profile = await _supabase
                .from('profiles')
                .select()
                .eq('id', item['sender_id'])
                .maybeSingle();
            requests.add(FriendRequest(
                id: item['id'],
                senderId: item['sender_id'],
                senderName: profile?['username'] ?? 'Unknown',
                senderAvatar: profile?['avatar_url'],
                timestamp: DateTime.parse(item['created_at'])));
          }
          return requests;
        });
  }

  @override
  Future<void> acceptFriendRequest(String requestId) async => await _supabase
      .from('friend_requests')
      .update({'status': 'accepted'}).eq('id', requestId);
  @override
  Future<void> rejectFriendRequest(String requestId) async => await _supabase
      .from('friend_requests')
      .update({'status': 'rejected'}).eq('id', requestId);
  @override
  Future<void> sendFriendRequest(String receiverId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    final existing = await _supabase
        .from('friend_requests')
        .select()
        .or('and(sender_id.eq.${user.id},receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.${user.id})')
        .maybeSingle();
    if (existing != null) {
      if (existing['status'] == 'rejected') {
        await _supabase.from('friend_requests').update({
          'status': 'pending',
          'sender_id': user.id,
          'receiver_id': receiverId
        }).eq('id', existing['id']);
      }
      return;
    }
    await _supabase.from('friend_requests').insert(
        {'sender_id': user.id, 'receiver_id': receiverId, 'status': 'pending'});
  }

  @override
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final user = _supabase.auth.currentUser;
    final response = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .ilike('username', '%$query%')
        .eq('is_public', true)
        .neq('id', user?.id ?? '')
        .limit(20);
    final results = List<Map<String, dynamic>>.from(response);
    if (user != null && results.isNotEmpty) {
      final userIds = results.map((u) => u['id']).toList();
      final requests = await _supabase
          .from('friend_requests')
          .select()
          .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
          .inFilter('sender_id', userIds.followedBy([user.id]).toList())
          .inFilter('receiver_id', userIds.followedBy([user.id]).toList());
      for (var result in results) {
        final request = (requests as List)
            .cast<Map<String, dynamic>?>()
            .firstWhere(
                (r) =>
                    r != null &&
                    ((r['sender_id'] == user.id &&
                            r['receiver_id'] == result['id']) ||
                        (r['receiver_id'] == user.id &&
                            r['sender_id'] == result['id'])),
                orElse: () => null);
        result['friendship_status'] = request?['status'] ?? 'none';
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
        .select('sender_id, receiver_id')
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}')
        .eq('status', 'accepted');
    final ids = response
        .map((i) =>
            i['sender_id'] == user.id ? i['receiver_id'] : i['sender_id'])
        .toList();
    if (ids.isEmpty) return [];
    final profiles = await _supabase
        .from('profiles')
        .select('id, username, avatar_url')
        .inFilter('id', ids);
    return (profiles as List)
        .map((p) => {
              'id': p['id'],
              'username': p['username'],
              'avatar_url': p['avatar_url']
            })
        .toList();
  }

  @override
  Future<ChatRoom> createGroup(
      {required String name,
      required List<String> memberIds,
      String? bio,
      String? avatarUrl}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('No user');
    final room = await _supabase
        .from('chat_rooms')
        .insert({
          'name': name,
          'bio': bio,
          'avatar_url': avatarUrl,
          'last_message': 'Group created',
          'is_group': true,
          'admin_id': user.id
        })
        .select()
        .single();
    final members = memberIds
        .map((id) => {'room_id': room['id'], 'user_id': id, 'role': 'member'})
        .toList();
    members.add({'room_id': room['id'], 'user_id': user.id, 'role': 'admin'});
    await _supabase.from('group_members').insert(members);
    _refreshController.add(null);
    return ChatRoom(
        id: room['id'],
        name: room['name'],
        avatarUrl: room['avatar_url'],
        lastMessage: 'Group created',
        unreadCount: 0,
        isGroup: true,
        lastMessageTime: DateTime.parse(room['created_at']));
  }

  @override
  Future<void> updateGroupInfo(String roomId,
      {String? name, String? bio, String? avatarUrl}) async {
    await _supabase.from('chat_rooms').update({
      if (name != null) 'name': name,
      if (bio != null) 'bio': bio,
      if (avatarUrl != null) 'avatar_url': avatarUrl
    }).eq('id', roomId);
    _refreshController.add(null);
  }

  @override
  Future<void> blockUser(String userId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    await _supabase
        .from('blocked_users')
        .insert({'blocker_id': myId, 'blocked_id': userId});
  }

  @override
  Future<void> unblockUser(String userId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;
    await _supabase
        .from('blocked_users')
        .delete()
        .eq('blocker_id', myId)
        .eq('blocked_id', userId);
  }

  @override
  Future<bool> isUserBlocked(String userId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return false;
    final res = await _supabase
        .from('blocked_users')
        .select()
        .eq('blocker_id', myId)
        .eq('blocked_id', userId)
        .maybeSingle();
    return res != null;
  }

  @override
  Future<bool> amIBlockedBy(String userId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return false;
    final res = await _supabase
        .from('blocked_users')
        .select()
        .eq('blocker_id', userId)
        .eq('blocked_id', myId)
        .maybeSingle();
    return res != null;
  }

  @override
  Future<List<Map<String, dynamic>>> getBlockedUsers() async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return [];
    final res = await _supabase
        .from('blocked_users')
        .select('blocked_id, profiles(username, avatar_url)')
        .eq('blocker_id', myId);
    return (res as List)
        .map((i) => {
              'id': i['blocked_id'],
              'username': i['profiles']['username'],
              'avatar_url': i['profiles']['avatar_url']
            })
        .toList();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase.from('profiles').delete().eq('id', user.id);
    await _supabase.auth.signOut();
  }

  @override
  Future<void> removeMember(String roomId, String userId) async =>
      await _supabase
          .from('group_members')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);

  @override
  Future<Map<String, dynamic>?> getProfile(String userId) async =>
      await _supabase.from('profiles').select().eq('id', userId).maybeSingle();

  // Helper to extract presence list from various return types
  List _extractPresenceList(dynamic state) {
    if (state == null) {
      debugPrint('[Presence] State is null in _extractPresenceList');
      return [];
    }

    try {
      final List allPresences = [];

      // On Web, presenceState() might return a List directly
      if (state is List) {
        debugPrint('[Presence] State is List with ${state.length} items');
        // Each item in the list is a PresenceState object
        for (final item in state) {
          try {
            // Try to access the 'presences' property
            final dynamic presences = (item as dynamic).presences;
            if (presences is List) {
              allPresences.addAll(presences);
            } else if (presences != null) {
              allPresences.add(presences);
            }
          } catch (e) {
            debugPrint('[Presence] Could not extract presences from item: $e');
            // Fallback: treat the item itself as a presence
            allPresences.add(item);
          }
        }
        return allPresences;
      }

      // On native platforms, it returns a Map
      if (state is Map) {
        final values = state.values.toList();
        debugPrint('[Presence] State is Map with ${values.length} values');
        for (final item in values) {
          try {
            final dynamic presences = (item as dynamic).presences;
            if (presences is List) {
              allPresences.addAll(presences);
            } else if (presences != null) {
              allPresences.add(presences);
            }
          } catch (e) {
            allPresences.add(item);
          }
        }
        return allPresences;
      }

      // Try to convert as Iterable
      if (state is Iterable) {
        final list = state.toList();
        debugPrint('[Presence] State is Iterable with ${list.length} items');
        for (final item in list) {
          try {
            final dynamic presences = (item as dynamic).presences;
            if (presences is List) {
              allPresences.addAll(presences);
            } else if (presences != null) {
              allPresences.add(presences);
            }
          } catch (e) {
            allPresences.add(item);
          }
        }
        return allPresences;
      }

      debugPrint(
          '[Presence] Could not extract list from state type: ${state.runtimeType}');
      return [];
    } catch (e) {
      debugPrint('[Presence] Error in _extractPresenceList: $e');
      return [];
    }
  }

  // Helper
  Map<String, dynamic>? _parsePresenceData(dynamic p) {
    if (p == null) return null;
    try {
      if (p is Map) {
        return Map<String, dynamic>.from(p);
      }

      // Handle Supabase Presence object safely
      dynamic payload;
      try {
        payload = (p as dynamic).payload;
      } catch (_) {
        payload = p;
      }

      if (payload == null) return null;

      if (payload is Map) {
        return Map<String, dynamic>.from(payload);
      }

      // On Web, JSObject might not match 'Map' but can be converted
      try {
        return Map<String, dynamic>.from(payload as dynamic);
      } catch (_) {
        return null;
      }
    } catch (_) {
      return null;
    }
  }

  // Not in interface but used internally
  Future<void> uploadFcmToken(String token) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;
    await _supabase
        .from('profiles')
        .update({'fcm_token': token}).eq('id', user.id);
  }

  Future<void> deleteMessage(String messageId) async {
    await _supabase.from('messages').delete().eq('id', messageId);
    _refreshController.add(null);
  }
}
