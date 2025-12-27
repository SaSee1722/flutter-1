import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:intl/intl.dart';
import 'package:gossip/features/chat/domain/entities/message.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_event.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_state.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/core/di/injection_container.dart';
import 'package:gossip/shared/widgets/glass_card.dart';
import 'package:gossip/features/auth/presentation/pages/pin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ChatDetailScreen extends StatefulWidget {
  final String roomId;
  final String chatName;
  final String? avatarUrl;
  final String? currentUserGender;
  final bool isGroup;

  const ChatDetailScreen({
    super.key,
    required this.roomId,
    required this.chatName,
    this.avatarUrl,
    this.currentUserGender,
    this.isGroup = false,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with WidgetsBindingObserver {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Message? _replyMessage;
  String? _typingUserName;
  StreamSubscription? _typingSubscription;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    context.read<ChatBloc>().add(LoadMessages(widget.roomId));

    // Mark as read initially
    sl<ChatRepository>().markAsRead(widget.roomId);

    _typingSubscription = sl<ChatRepository>()
        .watchTypingStatus(widget.roomId)
        .listen((userId) async {
      if (userId != null && mounted) {
        try {
          final res = await Supabase.instance.client
              .from('profiles')
              .select('username')
              .eq('id', userId)
              .maybeSingle();
          if (res != null && mounted) {
            setState(() => _typingUserName = res['username']);
          } else {
            setState(() => _typingUserName = "Someone");
          }
        } catch (_) {
          if (mounted) setState(() => _typingUserName = "Someone");
        }
      } else {
        if (mounted) setState(() => _typingUserName = null);
      }
    });

    // Mark as read whenever the messages are updated and not loading
    context.read<ChatBloc>().stream.listen((state) {
      if (!state.isLoadingMessages && state.messages.isNotEmpty && mounted) {
        sl<ChatRepository>().markAsRead(widget.roomId);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Explicitly untrack presence on exit
    _typingTimer?.cancel();
    sl<ChatRepository>().setTypingStatus(widget.roomId, false);
    _typingSubscription?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App moving to background, hide typing indicator
      sl<ChatRepository>().setTypingStatus(widget.roomId, false);
    } else if (state == AppLifecycleState.resumed) {
      // App back in foreground, resume typing status if controller is not empty
      if (_messageController.text.trim().isNotEmpty) {
        sl<ChatRepository>().setTypingStatus(widget.roomId, true);
      }
    }
  }

  void _onType(String value) {
    _typingTimer?.cancel();

    if (value.isNotEmpty) {
      sl<ChatRepository>().setTypingStatus(widget.roomId, true);

      _typingTimer = Timer(const Duration(seconds: 3), () {
        if (mounted) {
          sl<ChatRepository>().setTypingStatus(widget.roomId, false);
        }
      });
    } else {
      sl<ChatRepository>().setTypingStatus(widget.roomId, false);
    }
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final message = Message(
      id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      roomId: widget.roomId,
      userId: user.id,
      content: _messageController.text.trim(),
      createdAt: DateTime.now(),
      status: MessageStatus.sending,
    );

    context.read<ChatBloc>().add(SendMessageRequested(message));
    _messageController.clear();
    setState(() => _replyMessage = null); // Clear reply

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.5),
        elevation: 0,
        title: GestureDetector(
          onTap: _showGossipActions,
          child: Row(
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'avatar_${widget.roomId}',
                    child: CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          GossipColors.primary.withValues(alpha: 0.2),
                      backgroundImage: NetworkImage(widget.avatarUrl ??
                          'https://i.pravatar.cc/150?u=${widget.roomId}'), // Placeholder fallback
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chatName.toUpperCase(),
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.0)),
                  const Text('ONLINE',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.greenAccent,
                          letterSpacing: 1.5)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white54),
              onPressed: () {}),
          IconButton(
              icon: const Icon(Icons.call, color: Colors.white54),
              onPressed: () {}),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white54),
            onPressed: _showGossipActions,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                if (state.isLoadingMessages && state.messages.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                final messages = state.messages;

                if (state.error != null && messages.isEmpty) {
                  return Center(
                      child: Text(state.error!,
                          style: const TextStyle(color: Colors.red)));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      messages.length + (_typingUserName != null ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (_typingUserName != null && index == 0) {
                      return _TypingIndicator(userName: _typingUserName!);
                    }

                    final messageIndex =
                        _typingUserName != null ? index - 1 : index;
                    final message = messages[messageIndex];
                    final isMe = message.userId ==
                        Supabase.instance.client.auth.currentUser?.id;
                    return _MessageBubble(
                      message: message,
                      isMe: isMe,
                      userGender: widget.currentUserGender,
                      onReply: (msg) {
                        setState(() => _replyMessage = msg);
                      },
                      onReact: (reaction) {
                        sl<ChatRepository>()
                            .updateMessageReaction(message.id, reaction);
                      },
                    );
                  },
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      decoration: const BoxDecoration(
        color: Colors.black,
      ),
      child: Column(
        children: [
          if (_replyMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border(
                    left: BorderSide(color: GossipColors.primary, width: 4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply,
                      color: GossipColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Replying to ${_replyMessage!.userId == Supabase.instance.client.auth.currentUser?.id ? 'You' : 'User'}',
                          style: const TextStyle(
                            color: GossipColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          _replyMessage!.content,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _replyMessage = null),
                    child: const Icon(Icons.close,
                        color: Colors.white54, size: 20),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: 0.2, end: 0),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined,
                            color: Color(0xFF666666), size: 22),
                        onPressed: () {
                          // TODO: Show emoji picker
                        },
                      ),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                          ),
                          decoration: const InputDecoration(
                            hintText: 'Type a gossip...',
                            hintStyle: TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: _onType,
                          maxLines: 5,
                          minLines: 1,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file,
                            color: Color(0xFF666666), size: 22),
                        onPressed: () {
                          // TODO: Show attachment options
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A2A),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.mic, color: Color(0xFF666666), size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showGossipActions() {
    if (widget.isGroup) {
      _showGroupInfo();
    } else {
      _showUserActions();
    }
  }

  void _showGroupInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GROUP INFO',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: GossipColors.primary.withValues(alpha: 0.2),
                backgroundImage: widget.avatarUrl != null
                    ? NetworkImage(widget.avatarUrl!)
                    : null,
                child: widget.avatarUrl == null
                    ? const Icon(Icons.group,
                        size: 50, color: GossipColors.primary)
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                widget.chatName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'MEMBERS',
              style: TextStyle(
                color: GossipColors.textDim,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<dynamic>>(
                future: Supabase.instance.client
                    .from('group_members')
                    .select('user_id, role')
                    .eq('room_id', widget.roomId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final members = snapshot.data!;
                  return ListView.builder(
                    itemCount: members.length,
                    itemBuilder: (context, index) {
                      final member = members[index];
                      final isAdmin = member['role'] == 'admin';
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              GossipColors.primary.withValues(alpha: 0.2),
                          child: const Icon(Icons.person,
                              color: GossipColors.primary),
                        ),
                        title: Text(
                          member['user_id'],
                          style: const TextStyle(color: Colors.white),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: isAdmin
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: GossipColors.primary
                                      .withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'ADMIN',
                                  style: TextStyle(
                                    color: GossipColors.primary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showUserActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A0A0A),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('GOSSIP ACTIONS',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _buildActionItem(
                icon: Icons.call, label: 'Voice Call', onTap: () {}),
            _buildActionItem(
                icon: Icons.videocam, label: 'Video Call', onTap: () {}),
            _buildActionItem(
              icon: Icons.lock_outline,
              label: 'Lock Chat',
              color: GossipColors.secondary,
              onTap: _handleLockChat,
            ),
            const Divider(color: Colors.white10, height: 32),
            _buildActionItem(
                icon: Icons.block,
                label: 'Block User',
                color: Colors.redAccent,
                onTap: () {}),
            _buildActionItem(
                icon: Icons.report_gmailerrorred,
                label: 'Report User',
                color: Colors.redAccent,
                onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (color ?? Colors.blueAccent).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color ?? Colors.blueAccent, size: 20),
            ),
            const SizedBox(width: 16),
            Text(label,
                style: TextStyle(
                    color: color ?? Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLockChat() async {
    Navigator.pop(context); // Close sheet
    final prefs = await SharedPreferences.getInstance();
    final hasPin = prefs.containsKey('app_pin');

    if (!mounted) return;

    if (!hasPin) {
      // Set new PIN
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PinScreen(
            isSettingUp: true,
            onComplete: (ctx, pin) async {
              await prefs.setString('app_pin', pin);
              await _toggleChatLock(prefs);
              if (ctx.mounted) Navigator.pop(ctx); // Close pin screen
              return true;
            },
          ),
        ),
      );
    } else {
      await _toggleChatLock(prefs);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat Status Updated')),
        );
      }
    }
  }

  Future<void> _toggleChatLock(SharedPreferences prefs) async {
    final List<String> lockedChats = prefs.getStringList('locked_chats') ?? [];
    if (lockedChats.contains(widget.roomId)) {
      lockedChats.remove(widget.roomId);
    } else {
      lockedChats.add(widget.roomId);
    }
    await prefs.setStringList('locked_chats', lockedChats);
  }
}

class _MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String? userGender;
  final Function(Message) onReply;
  final Function(String?) onReact;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.userGender,
    required this.onReply,
    required this.onReact,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  String? _selectedReaction;

  @override
  Widget build(BuildContext context) {
    Color bubbleColor;
    if (widget.isMe) {
      if (widget.userGender?.toLowerCase() == 'male') {
        bubbleColor = const Color(0xFF87CEEB); // Sky Blue
      } else if (widget.userGender?.toLowerCase() == 'female') {
        bubbleColor = const Color(0xFFF4C2C2); // Baby Pink
      } else {
        bubbleColor = GossipColors.primary.withValues(alpha: 0.2); // Default
      }
    } else {
      bubbleColor = GossipColors.cardBackground;
    }

    // Determine text color based on bubble color contrast if needed
    // Usually white is fine, but for very light pink/blue, maybe black?
    // User requested "cloud message should in the baby pink color".
    // Assuming white text is still desired unless unreadable.
    // Sky Blue (135, 206, 235) -> Lum ~ 0.7. White might be hard to read.
    // Baby Pink (244, 194, 194) -> Lum ~ 0.8. White definitely hard.
    // Let's use Black text for these light colors if isMe.

    final textColor = (widget.isMe &&
            (widget.userGender?.toLowerCase() == 'male' ||
                widget.userGender?.toLowerCase() == 'female'))
        ? Colors.black
        : Colors.white;

    return Dismissible(
      key: ValueKey(widget.message.id),
      direction: widget.isMe
          ? DismissDirection.endToStart
          : DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
        widget.onReply(widget.message);
        return false; // Don't actually dismiss
      },
      background: Container(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Icon(Icons.reply, color: Colors.white, size: 24),
      ),
      child: GestureDetector(
        onLongPress: _showReactionMenu,
        child: Align(
          alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Column(
            crossAxisAlignment:
                widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width > 600
                      ? 450
                      : MediaQuery.of(context).size.width * 0.75,
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: bubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(16),
                    topRight: const Radius.circular(16),
                    bottomLeft: Radius.circular(widget.isMe ? 16 : 0),
                    bottomRight: Radius.circular(widget.isMe ? 0 : 16),
                  ),
                  border:
                      Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MarkdownBody(
                        data: widget.message.content,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(color: textColor, fontSize: 15),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            DateFormat('HH:mm')
                                .format(widget.message.createdAt),
                            style: TextStyle(
                                color: textColor.withValues(alpha: 0.6),
                                fontSize: 10,
                                fontWeight: FontWeight.w500),
                          ),
                          if (widget.isMe) ...[
                            const SizedBox(width: 4),
                            _buildStatusIcon(),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedReaction != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: GossipColors.cardBackground,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Text(_selectedReaction!,
                      style: const TextStyle(fontSize: 12)),
                ).animate().scale(duration: 200.ms),
            ],
          ),
        ),
      ),
    );
  }

  void _showReactionMenu() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 40),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: GossipColors.cardBackground,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: ['❤️', '😂', '😮', '😢', '🔥', '👍']
                .map((e) => GestureDetector(
                      onTap: () {
                        setState(() => _selectedReaction = e);
                        widget.onReact(e);
                        Navigator.pop(context);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(e, style: const TextStyle(fontSize: 28))
                            .animate()
                            .scale(
                                duration: 200.ms,
                                begin: const Offset(0.8, 0.8)),
                      ),
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon() {
    // User requested: "single tick for sent, double tick for read"
    const tickColor = Colors.black;

    switch (widget.message.status) {
      case MessageStatus.sending:
        return const Icon(Icons.access_time, size: 12, color: tickColor);
      case MessageStatus.sent:
        return const Icon(Icons.check, size: 12, color: tickColor);
      case MessageStatus.delivered:
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: tickColor);
    }
  }
}

class _TypingIndicator extends StatelessWidget {
  final String userName;
  const _TypingIndicator({required this.userName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: GossipColors.cardBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$userName is typing',
                    style:
                        const TextStyle(color: Colors.white54, fontSize: 12)),
                const SizedBox(width: 8),
                Row(
                  children: List.generate(
                      3,
                      (i) => Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            width: 5,
                            height: 5,
                            decoration: const BoxDecoration(
                                color: Colors.white, shape: BoxShape.circle),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .moveY(
                                  duration: 300.ms,
                                  delay: (i * 150).ms,
                                  begin: 0,
                                  end: -5,
                                  curve: Curves.easeInOut)
                              .then()
                              .moveY(
                                  duration: 300.ms,
                                  begin: -5,
                                  end: 0,
                                  curve: Curves.easeInOut)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Import added at top
