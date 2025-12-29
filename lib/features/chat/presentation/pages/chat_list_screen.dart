import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/chat/domain/entities/chat_room.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import 'chat_detail_screen.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_event.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_state.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_bloc.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_event.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_state.dart';
import 'package:gossip/features/vibes/presentation/pages/vibe_view_screen.dart';
import 'package:gossip/features/vibes/presentation/pages/create_vibe_screen.dart';
import 'package:gossip/features/auth/presentation/pages/pin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/vibes/domain/entities/user_status.dart';
import 'package:gossip/core/di/injection_container.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:gossip/features/chat/domain/entities/friend_request.dart';
import 'package:gossip/core/utils/date_formatter.dart';
import 'search/search_users_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _myAvatarUrl;
  String? _myGender;

  @override
  void initState() {
    super.initState();
    context.read<ChatBloc>().add(LoadRooms());
    context.read<VibeBloc>().add(LoadVibes());
    _fetchMyProfile();
  }

  Future<void> _fetchMyProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final res = await Supabase.instance.client
            .from('profiles')
            .select('avatar_url, gender')
            .eq('id', user.id)
            .maybeSingle();
        if (res != null && mounted) {
          setState(() {
            _myAvatarUrl = res['avatar_url'];
            _myGender = res['gender'];
          });
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader()
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: -0.2, end: 0),
            _buildSearchBar().animate().fadeIn(delay: 200.ms, duration: 600.ms),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildVibesSection()
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms),
                    const SizedBox(height: 8),
                    _buildChatSection(context),
                    const SizedBox(height: 100), // Space for floating nav
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GradientText(
                    'GOSSIP.',
                    gradient: GossipColors.primaryGradient,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  _HeaderDoodle(),
                ],
              ),
              BlocBuilder<ChatBloc, ChatState>(
                builder: (context, state) {
                  return StreamBuilder<List<FriendRequest>>(
                    stream: sl<ChatRepository>().getFriendRequests(),
                    builder: (context, requestSnapshot) {
                      final pendingRequests =
                          (requestSnapshot.data ?? []).length;

                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined,
                                color: Colors.white, size: 28),
                            onPressed: () => _showNotifications(context),
                          ),
                          if (pendingRequests > 0)
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.redAccent,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 16,
                                  minHeight: 16,
                                ),
                                child: Text(
                                  '$pendingRequests',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Connect, share, and whisper in style.',
            style: TextStyle(color: GossipColors.textDim, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _NotificationSheet(),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SearchUsersScreen()),
          );
        },
        child: Container(
          height: 50,
          decoration: BoxDecoration(
            color: GossipColors.searchBar,
            borderRadius: BorderRadius.circular(25),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              Icon(Icons.search_rounded, color: GossipColors.textDim, size: 20),
              SizedBox(width: 12),
              Text(
                'Search friends or gossip...',
                style: TextStyle(color: GossipColors.textDim, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVibesSection() {
    return BlocBuilder<VibeBloc, VibeState>(
      builder: (context, state) {
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(vertical: 16),
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: GossipColors.cardBackground.withValues(alpha: 0.5),
            border: Border.symmetric(
              horizontal:
                  BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GradientText(
                      'VIBES.',
                      gradient: GossipColors.primaryGradient,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                      ),
                    ),
                    if (state is VibeLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Builder(builder: (context) {
                      UserStatus? myVibe;
                      final currentUserId =
                          Supabase.instance.client.auth.currentUser?.id;
                      List<UserStatus> rawVibes = [];

                      if (state is VibesLoaded) {
                        rawVibes = state.vibes;
                        try {
                          myVibe = rawVibes
                              .firstWhere((v) => v.userId == currentUserId);
                        } catch (_) {}
                      }

                      // Group other vibes by user
                      final Map<String, List<UserStatus>> groupedVibes = {};
                      for (var v in rawVibes) {
                        if (v.userId == currentUserId) continue;
                        groupedVibes.putIfAbsent(v.userId, () => []).add(v);
                      }

                      final otherUserIds = groupedVibes.keys.toList();

                      return Row(
                        children: [
                          _VibeItem(
                            label: 'Your Vibe',
                            isYours: true,
                            imageUrl: myVibe?.mediaUrl ?? _myAvatarUrl,
                            onAddTap: _openVibeCreation,
                            onTap: myVibe != null
                                ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => VibeViewScreen(
                                            vibes: [myVibe!], initialIndex: 0),
                                      ),
                                    )
                                : _openVibeCreation,
                          ),
                          const SizedBox(width: 24),
                          ...List.generate(otherUserIds.length, (index) {
                            final userId = otherUserIds[index];
                            final userVibes = groupedVibes[userId]!;
                            final firstVibe = userVibes.first;

                            // Check if ANY vibe in this user's group is unseen
                            final hasUnseen = userVibes.any((v) => !v.isViewed);

                            // Find the first unviewed vibe to start viewing from
                            final startIdx =
                                userVibes.indexWhere((v) => !v.isViewed);
                            final initialIndex = startIdx == -1 ? 0 : startIdx;

                            return Row(
                              children: [
                                _VibeItem(
                                  label: firstVibe.username ?? 'User',
                                  imageUrl: firstVibe.mediaUrl,
                                  isViewed: !hasUnseen, // Red if ALL viewed
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => VibeViewScreen(
                                        vibes: userVibes,
                                        initialIndex: initialIndex,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 24),
                              ],
                            );
                          }),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openVibeCreation() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CreateVibeScreen()),
    );
  }

  Widget _buildChatSection(BuildContext context) {
    return BlocBuilder<ChatBloc, ChatState>(
      builder: (context, state) {
        final dms = state.rooms.where((r) => !r.isGroup).toList();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: GossipColors.cardBackground.withValues(alpha: 0.3),
            border: Border.symmetric(
              horizontal:
                  BorderSide(color: Colors.white.withValues(alpha: 0.05)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GradientText(
                'GOSSIP.',
                gradient: GossipColors.primaryGradient,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              if (state.isLoadingRooms && dms.isEmpty)
                const Center(child: CircularProgressIndicator())
              else if (dms.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'No gossips yet. Start a conversation!',
                      style: TextStyle(color: GossipColors.textDim),
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: dms.length,
                  separatorBuilder: (context, index) => Divider(
                      color: Colors.white.withValues(alpha: 0.05), height: 32),
                  itemBuilder: (context, index) {
                    final room = dms[index];
                    return InkWell(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        if (!context.mounted) return;
                        final lockedChats =
                            prefs.getStringList('locked_chats') ?? [];
                        final hasPin = prefs.containsKey('app_pin');
                        final isLocked = lockedChats.contains(room.id);

                        if (isLocked && hasPin) {
                          if (!context.mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PinScreen(
                                onComplete: (ctx, pin) async {
                                  final storedPin = prefs.getString('app_pin');
                                  if (pin == storedPin) {
                                    Navigator.pop(ctx); // Close pin screen
                                    // Allow navigation
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatDetailScreen(
                                          roomId: room.id,
                                          chatName: room.name,
                                          currentUserGender: _myGender,
                                        ),
                                      ),
                                    );
                                    return true;
                                  }
                                  return false;
                                },
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatDetailScreen(
                                roomId: room.id,
                                chatName: room.name,
                                avatarUrl: room.avatarUrl,
                                currentUserGender: _myGender,
                              ),
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: _ChatListItem(room: room),
                    );
                  },
                ),
            ],
          ),
        )
            .animate()
            .fadeIn(delay: 600.ms, duration: 600.ms)
            .slideY(begin: 0.1, end: 0);
      },
    );
  }
}

class _NotificationSheet extends StatefulWidget {
  @override
  State<_NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<_NotificationSheet> {
  final Map<String, bool> _processingIds = {};

  Future<void> _handleAction(String id, bool accept) async {
    setState(() => _processingIds[id] = true);
    try {
      if (accept) {
        await sl<ChatRepository>().acceptFriendRequest(id);
      } else {
        await sl<ChatRepository>().rejectFriendRequest(id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(accept ? 'Request accepted!' : 'Request rejected.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingIds[id] = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      decoration: BoxDecoration(
        color: GossipColors.cardBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GradientText(
                'REQUESTS.',
                gradient: GossipColors.primaryGradient,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: StreamBuilder<List<FriendRequest>>(
              stream: sl<ChatRepository>().getFriendRequests(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final requests = snapshot.data ?? [];
                if (requests.isEmpty) {
                  return const Center(
                    child: Text('No pending requests',
                        style: TextStyle(color: GossipColors.textDim)),
                  );
                }
                return ListView.separated(
                  itemCount: requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final req = requests[index];
                    final isProcessing = _processingIds[req.id] ?? false;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.03),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.white12,
                            backgroundImage: req.senderAvatar != null
                                ? CachedNetworkImageProvider(req.senderAvatar!)
                                : null,
                            child: req.senderAvatar == null
                                ? Text(req.senderName[0].toUpperCase())
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(req.senderName,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold)),
                                Text('Sent you a request',
                                    style: const TextStyle(
                                        color: GossipColors.textDim,
                                        fontSize: 12)),
                              ],
                            ),
                          ),
                          if (isProcessing)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                            )
                          else
                            Row(
                              children: [
                                IconButton(
                                  onPressed: () => _handleAction(req.id, true),
                                  icon: const Icon(Icons.check_circle_rounded,
                                      color: Colors.green),
                                ),
                                IconButton(
                                  onPressed: () => _handleAction(req.id, false),
                                  icon: const Icon(Icons.cancel_rounded,
                                      color: Colors.red),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderDoodle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/gossip_header.png',
      height: 40,
      fit: BoxFit.contain,
    );
  }
}

class _VibeItem extends StatelessWidget {
  final String label;
  final bool isYours;
  final bool isViewed;
  final String? imageUrl;
  final VoidCallback? onTap;
  final VoidCallback? onAddTap;

  const _VibeItem({
    required this.label,
    this.isYours = false,
    this.isViewed = false,
    this.imageUrl,
    this.onTap,
    this.onAddTap,
  });

  @override
  Widget build(BuildContext context) {
    // Determine ring color
    final Color ringColor;
    if (isYours) {
      ringColor = GossipColors.primary;
    } else {
      ringColor = isViewed ? Colors.red : Colors.greenAccent;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          children: [
            Stack(
              children: [
                // Main Avatar Tap
                GestureDetector(
                  onTap: onTap,
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: ringColor,
                        width: 2.5,
                      ),
                      image: imageUrl != null
                          ? DecorationImage(
                              image: CachedNetworkImageProvider(imageUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                      boxShadow: [
                        BoxShadow(
                          color: ringColor.withValues(alpha: 0.2),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: imageUrl == null
                        ? Center(
                            child: Text(
                              label[0].toUpperCase(),
                              style: TextStyle(
                                color: ringColor,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                if (isYours)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: onAddTap,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: GossipColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatListItem extends StatelessWidget {
  final ChatRoom room;

  const _ChatListItem({required this.room});

  @override
  Widget build(BuildContext context) {
    final Color nameColor;
    if (room.gender?.toLowerCase() == 'male') {
      nameColor = const Color(0xFF87CEEB); // Sky Blue
    } else if (room.gender?.toLowerCase() == 'female') {
      nameColor = const Color(0xFFF4C2C2); // Baby Pink
    } else {
      nameColor = GossipColors.primary; // Default
    }

    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: GossipColors.primary.withValues(alpha: 0.1),
              backgroundImage: room.avatarUrl != null
                  ? CachedNetworkImageProvider(room.avatarUrl!)
                  : null,
              child: room.avatarUrl == null
                  ? Text(room.name[0].toUpperCase(),
                      style: const TextStyle(
                          color: GossipColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16))
                  : null,
            ),
            if (!room.isGroup && room.otherUserId != null)
              StreamBuilder<bool>(
                stream: sl<ChatRepository>()
                    .watchUserOnlineStatus(room.otherUserId!),
                builder: (context, snapshot) {
                  final isOnline = snapshot.data ?? false;
                  if (!isOnline) return const SizedBox();
                  return Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: GossipColors.background,
                          width: 2.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withValues(alpha: 0.3),
                            blurRadius: 4,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    room.name,
                    style: TextStyle(
                      color: nameColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    DateFormatter.formatRelativeTime(room.lastMessageTime),
                    style: const TextStyle(
                        color: GossipColors.textDim, fontSize: 11),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                room.lastMessage ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style:
                    const TextStyle(color: GossipColors.textDim, fontSize: 13),
              ),
            ],
          ),
        ),
        if (room.unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: GossipColors.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${room.unreadCount}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ).animate().scale(duration: 300.ms),
      ],
    );
  }
}
