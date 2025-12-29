import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:gossip/features/chat/domain/entities/message.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_event.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_state.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/core/di/injection_container.dart';
import 'package:gossip/features/auth/presentation/pages/pin_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gossip/features/call/presentation/bloc/call_bloc.dart';
import 'package:gossip/features/call/presentation/bloc/call_event.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:gossip/features/chat/presentation/widgets/group_settings_sheet.dart';
import 'package:gossip/core/utils/date_formatter.dart';
import '../../../../shared/utils/toast_utils.dart';

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
  StreamSubscription? _presenceSubscription;
  Timer? _typingTimer;
  bool _isOtherUserOnline = false;
  int _onlineCount = 0;
  String? _otherUserId;

  // Media & Emoji features
  bool _showEmojiPicker = false;
  final ImagePicker _imagePicker = ImagePicker();
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;

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

    // Mark as read immediately on entry
    sl<ChatRepository>().markAsRead(widget.roomId);

    // Mark as read whenever the messages are updated and not loading
    context.read<ChatBloc>().stream.listen((state) {
      if (!state.isLoadingMessages && mounted) {
        sl<ChatRepository>().markAsRead(widget.roomId);
      }
    });

    _setupPresence();
  }

  Future<void> _setupPresence() async {
    if (widget.isGroup) {
      _presenceSubscription = sl<ChatRepository>()
          .watchGroupPresence(widget.roomId)
          .listen((count) {
        if (mounted) setState(() => _onlineCount = count);
      });
    } else {
      // For DMs, we need the other user's ID
      try {
        final res = await Supabase.instance.client
            .from('friend_requests')
            .select('sender_id, receiver_id')
            .eq('id', widget.roomId)
            .maybeSingle();

        if (res != null) {
          final myId = Supabase.instance.client.auth.currentUser?.id;
          final otherId =
              res['sender_id'] == myId ? res['receiver_id'] : res['sender_id'];

          if (mounted) setState(() => _otherUserId = otherId);

          if (otherId != null) {
            _presenceSubscription = sl<ChatRepository>()
                .watchUserOnlineStatus(otherId)
                .listen((isOnline) {
              if (mounted) setState(() => _isOtherUserOnline = isOnline);
            });
          }
        }
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Explicitly untrack presence on exit
    _typingTimer?.cancel();
    sl<ChatRepository>().setTypingStatus(widget.roomId, false);
    _typingSubscription?.cancel();
    _presenceSubscription?.cancel();
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
    setState(() {}); // Trigger rebuild to update mic/send icon
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
      senderGender: widget.currentUserGender,
      senderName: 'You',
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
                      backgroundImage: widget.avatarUrl != null
                          ? CachedNetworkImageProvider(widget.avatarUrl!)
                          : null,
                      child: widget.avatarUrl == null
                          ? Text(widget.chatName[0].toUpperCase(),
                              style: const TextStyle(
                                  color: GossipColors.primary,
                                  fontWeight: FontWeight.bold))
                          : null,
                    ),
                  ),
                  if (!widget.isGroup)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _isOtherUserOnline
                              ? Colors.greenAccent
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: _isOtherUserOnline
                                ? Colors.black
                                : Colors.transparent,
                            width: 2,
                          ),
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
                  if (_typingUserName != null)
                    Text(
                      '${_typingUserName!.toUpperCase()} TYPING...',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: GossipColors.primary,
                        letterSpacing: 1.5,
                      ),
                    )
                  else if (widget.isGroup)
                    Text(
                      '$_onlineCount ONLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _onlineCount > 0
                            ? Colors.greenAccent
                            : GossipColors.textDim,
                        letterSpacing: 1.5,
                      ),
                    )
                  else if (_isOtherUserOnline)
                    const Text(
                      'ONLINE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.greenAccent,
                        letterSpacing: 1.5,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
              icon: const Icon(Icons.videocam, color: Colors.white54),
              onPressed: () {
                if (!widget.isGroup && _otherUserId == null) return;
                context.read<CallBloc>().add(StartCall(
                      receiverId: widget.isGroup ? null : _otherUserId,
                      roomId: widget.isGroup ? widget.roomId : null,
                      name: widget.chatName,
                      avatar: widget.avatarUrl,
                      isVideo: true,
                    ));
              }),
          IconButton(
              icon: const Icon(Icons.call, color: Colors.white54),
              onPressed: () {
                if (!widget.isGroup && _otherUserId == null) return;
                context.read<CallBloc>().add(StartCall(
                      receiverId: widget.isGroup ? null : _otherUserId,
                      roomId: widget.isGroup ? widget.roomId : null,
                      name: widget.chatName,
                      avatar: widget.avatarUrl,
                      isVideo: false,
                    ));
              }),
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
                      isGroup: widget.isGroup,
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

  // Media handling methods
  void _toggleEmojiPicker() {
    setState(() {
      _showEmojiPicker = !_showEmojiPicker;
    });
  }

  void _onEmojiSelected(Emoji emoji) {
    _messageController.text += emoji.emoji;
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        final fileExt = image.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '$userId/$fileName';

        await Supabase.instance.client.storage
            .from('chat-media')
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('chat-media')
            .getPublicUrl(filePath);

        final message = Message(
          id: '',
          roomId: widget.roomId,
          userId: userId,
          content: '',
          status: MessageStatus.sending,
          createdAt: DateTime.now(),
          mediaUrl: publicUrl,
          mediaType: 'image',
          mediaName: image.name,
          mediaSize: bytes.length,
          senderGender: widget.currentUserGender,
          senderName: 'You',
        );

        if (!mounted) return;
        context.read<ChatBloc>().add(SendMessageRequested(message));
      }
    } catch (e) {
      if (kDebugMode) print('Error: $e');
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? video =
          await _imagePicker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        final bytes = await video.readAsBytes();
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        final fileExt = video.path.split('.').last;
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final filePath = '$userId/$fileName';

        await Supabase.instance.client.storage
            .from('chat-media')
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('chat-media')
            .getPublicUrl(filePath);

        final message = Message(
          id: '',
          roomId: widget.roomId,
          userId: userId,
          content: '',
          status: MessageStatus.sending,
          createdAt: DateTime.now(),
          mediaUrl: publicUrl,
          mediaType: 'video',
          mediaName: video.name,
          mediaSize: bytes.length,
          senderGender: widget.currentUserGender,
          senderName: 'You',
        );

        if (!mounted) return;
        context.read<ChatBloc>().add(SendMessageRequested(message));
      }
    } catch (e) {
      if (kDebugMode) print('Error: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xlsx', 'ppt', 'pptx'],
      );

      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        final bytes = file.bytes!;
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        final fileName = file.name;
        final filePath =
            '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        await Supabase.instance.client.storage
            .from('chat-documents')
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('chat-documents')
            .getPublicUrl(filePath);

        final message = Message(
          id: '',
          roomId: widget.roomId,
          userId: userId,
          content: '',
          status: MessageStatus.sending,
          createdAt: DateTime.now(),
          mediaUrl: publicUrl,
          mediaType: 'document',
          mediaName: file.name,
          mediaSize: bytes.length,
          senderGender: widget.currentUserGender,
          senderName: 'You',
        );

        if (!mounted) return;
        context.read<ChatBloc>().add(SendMessageRequested(message));
      }
    } catch (e) {
      if (kDebugMode) print('Error: $e');
    }
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.first.bytes != null) {
        final file = result.files.first;
        final bytes = file.bytes!;
        final userId = Supabase.instance.client.auth.currentUser?.id;
        if (userId == null) return;

        final fileName = file.name;
        final filePath =
            '$userId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

        await Supabase.instance.client.storage
            .from('chat-audio')
            .uploadBinary(filePath, bytes);

        final publicUrl = Supabase.instance.client.storage
            .from('chat-audio')
            .getPublicUrl(filePath);

        final message = Message(
          id: '',
          roomId: widget.roomId,
          userId: userId,
          content: '',
          status: MessageStatus.sending,
          createdAt: DateTime.now(),
          mediaUrl: publicUrl,
          mediaType: 'audio',
          mediaName: file.name,
          mediaSize: bytes.length,
          senderGender: widget.currentUserGender,
          senderName: 'You',
        );

        if (!mounted) return;
        context.read<ChatBloc>().add(SendMessageRequested(message));
      }
    } catch (e) {
      if (kDebugMode) print('Error: $e');
    }
  }

  Future<void> _toggleVoiceRecording() async {
    if (_isRecording) {
      // Stop recording
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          setState(() {
            _isRecording = false;
          });

          // Get bytes from the recorded file/blob
          Uint8List bytes;
          if (kIsWeb) {
            final response = await http.get(Uri.parse(path));
            bytes = response.bodyBytes;
          } else {
            final file = File(path);
            bytes = await file.readAsBytes();
            await file.delete();
          }

          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId == null) return;

          final fileName = 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          final filePath = '$userId/$fileName';

          await Supabase.instance.client.storage
              .from('chat-audio')
              .uploadBinary(filePath, bytes);

          final publicUrl = Supabase.instance.client.storage
              .from('chat-audio')
              .getPublicUrl(filePath);

          final message = Message(
            id: '',
            roomId: widget.roomId,
            userId: userId,
            content: '',
            status: MessageStatus.sending,
            createdAt: DateTime.now(),
            mediaUrl: publicUrl,
            mediaType: 'voice',
            mediaName: fileName,
            mediaSize: bytes.length,
            senderGender: widget.currentUserGender,
            senderName: 'You',
          );

          if (!mounted) return;
          context.read<ChatBloc>().add(SendMessageRequested(message));
        }
      } catch (e) {
        setState(() {
          _isRecording = false;
        });
        if (kDebugMode) print('Error: $e');
      }
    } else {
      // Start recording
      try {
        if (await _audioRecorder.hasPermission()) {
          String? storagePath;
          if (!kIsWeb) {
            final directory = await getTemporaryDirectory();
            storagePath =
                '${directory.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
          }

          await _audioRecorder.start(
            const RecordConfig(encoder: AudioEncoder.aacLc),
            path: storagePath ?? '',
          );

          setState(() {
            _isRecording = true;
          });
        }
      } catch (e) {
        if (kDebugMode) print('Error: $e');
      }
    }
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Send Attachment',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                const SizedBox(width: 48),
                _AttachmentOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickFile();
                  },
                ),
                const SizedBox(width: 48),
                _AttachmentOption(
                  icon: Icons.audiotrack,
                  label: 'Audio',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _pickAudio();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      color: const Color(0xFF000000),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.emoji_emotions_outlined,
                            color: Color(0xFFB0B0B0), size: 22),
                        onPressed: _toggleEmojiPicker,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          style: const TextStyle(color: Colors.white),
                          cursorColor: Colors.white,
                          decoration: const InputDecoration(
                            hintText: "Type a gossip...",
                            hintStyle: TextStyle(color: Color(0xFF8E8E93)),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 12),
                          ),
                          onChanged: _onType,
                          onSubmitted: (_) => _sendMessage(),
                          maxLines: 5,
                          minLines: 1,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.attach_file,
                            color: Color(0xFFB0B0B0), size: 22),
                        onPressed: _showAttachmentOptions,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.camera_alt,
                            color: Color(0xFFB0B0B0), size: 22),
                        onPressed: () => _pickImage(ImageSource.camera),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _messageController.text.trim().isNotEmpty
                    ? _sendMessage
                    : _toggleVoiceRecording,
                child: Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : const Color(0xFF2C2C2E),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _messageController.text.trim().isNotEmpty
                        ? Icons.send
                        : (_isRecording ? Icons.stop : Icons.mic),
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          // Emoji Picker
          if (_showEmojiPicker)
            SizedBox(
              height: 250,
              child: EmojiPicker(
                onEmojiSelected: (category, emoji) {
                  _onEmojiSelected(emoji);
                },
                config: const Config(
                  height: 250,
                  checkPlatformCompatibility: true,
                  emojiViewConfig: EmojiViewConfig(
                    backgroundColor: Color(0xFF1C1C1E),
                    columns: 7,
                    emojiSizeMax: 28,
                  ),
                  categoryViewConfig: CategoryViewConfig(
                    backgroundColor: Color(0xFF1C1C1E),
                  ),
                ),
              ),
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

  Future<void> _showGroupInfo() async {
    try {
      // Fetch room data and check if current user is admin
      final userId = Supabase.instance.client.auth.currentUser?.id;
      final roomData = await Supabase.instance.client
          .from('chat_rooms')
          .select()
          .eq('id', widget.roomId)
          .single();

      final memberData = await Supabase.instance.client
          .from('group_members')
          .select('role')
          .eq('room_id', widget.roomId)
          .eq('user_id', userId!)
          .maybeSingle();

      final bool isAdmin =
          memberData?['role'] == 'admin' || roomData['admin_id'] == userId;

      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => GroupSettingsSheet(
          roomId: widget.roomId,
          groupData: roomData,
          isAdmin: isAdmin,
        ),
      );
    } catch (e) {
      if (mounted) {
        if (kDebugMode) print('Error loading group info: $e');
      }
    }
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
                onTap: () async {
                  if (_otherUserId == null) return;
                  Navigator.pop(context);
                  try {
                    await sl<ChatRepository>().blockUser(_otherUserId!);
                    if (!context.mounted) return;
                    ToastUtils.showInfo(context, 'User blocked successfully.');
                    Navigator.pop(context);
                  } catch (e) {
                    if (!context.mounted) return;
                    ToastUtils.showError(context, 'Failed to block user: $e');
                  }
                }),
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
  final bool isGroup;
  final Function(Message) onReply;
  final Function(String?) onReact;

  const _MessageBubble({
    required this.message,
    required this.isMe,
    this.isGroup = false,
    required this.onReply,
    required this.onReact,
  });

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  @override
  Widget build(BuildContext context) {
    Color bubbleColor;
    final gender = widget.message.senderGender?.toLowerCase();

    if (gender == 'male') {
      bubbleColor = const Color(0xFF87CEEB); // Sky Blue
    } else if (gender == 'female') {
      bubbleColor = const Color(0xFFF4C2C2); // Baby Pink
    } else if (gender == 'others' || gender == 'other') {
      bubbleColor = const Color(0xFFFFD700); // Golden
    } else {
      bubbleColor = widget.isMe
          ? GossipColors.primary.withValues(alpha: 0.2)
          : GossipColors.cardBackground;
    }

    final bool isSpecialColor =
        gender == 'male' || gender == 'female' || gender == 'other';
    final textColor = (isSpecialColor) ? Colors.black : Colors.white;

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
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (widget.message.status == MessageStatus.sending)
                      const Positioned.fill(child: _WaveLoadingOverlay()),
                    IntrinsicWidth(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (widget.isGroup && !widget.isMe) ...[
                            Text(
                              widget.message.senderName ?? 'Gossip Member',
                              style: TextStyle(
                                color: textColor.withValues(alpha: 0.7),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          if (widget.message.mediaUrl != null)
                            _buildMediaContent(),
                          if (widget.message.mediaUrl != null &&
                              widget.message.mediaType != 'voice' &&
                              widget.message.mediaType != 'audio' &&
                              widget.message.content.trim().isNotEmpty &&
                              !widget.message.content.contains('Image') &&
                              !widget.message.content.contains('Video') &&
                              !widget.message.content.contains('Document') &&
                              !widget.message.content.contains('Audio') &&
                              widget.message.content != '📷' &&
                              widget.message.content != '🎥')
                            const SizedBox(height: 8),
                          if (widget.message.mediaType != 'voice' &&
                              widget.message.mediaType != 'audio' &&
                              widget.message.content.trim().isNotEmpty &&
                              !widget.message.content.contains('Image') &&
                              !widget.message.content.contains('Video') &&
                              !widget.message.content.contains('Document') &&
                              !widget.message.content.contains('Audio') &&
                              widget.message.content != '📷' &&
                              widget.message.content != '🎥')
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
                                DateFormatter.formatMessageTime(
                                    widget.message.createdAt),
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
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaContent() {
    final mediaType = widget.message.mediaType;
    final mediaUrl = widget.message.mediaUrl!;

    if (mediaType == 'image') {
      return GestureDetector(
        onTap: () => _openUrl(mediaUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CachedNetworkImage(
                imageUrl: mediaUrl,
                placeholder: (context, url) => Container(
                  height: 200,
                  width: double.infinity,
                  color: Colors.white10,
                  child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.error),
                fit: BoxFit.cover,
              ),
            ],
          ),
        ),
      );
    }

    if (mediaType == 'video') {
      return GestureDetector(
        onTap: () => _openUrl(mediaUrl),
        child: Container(
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black26,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.play_circle_fill, color: Colors.white, size: 50),
              Positioned(
                bottom: 8,
                right: 8,
                child: Text(
                  widget.message.mediaName ?? 'Video',
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (mediaType == 'document') {
      return GestureDetector(
        onTap: () => _openUrl(mediaUrl),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.insert_drive_file, color: Colors.white70),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.message.mediaName ?? 'Document',
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.message.mediaSize != null)
                      Text(
                        '${(widget.message.mediaSize! / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(
                            color: Colors.white38, fontSize: 10),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.download, color: Colors.white38, size: 18),
            ],
          ),
        ),
      );
    }

    if (mediaType == 'voice' || mediaType == 'audio') {
      return _AudioMessagePlayer(url: mediaUrl, isMe: widget.isMe);
    }

    return const SizedBox.shrink();
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (kDebugMode) print('Could not open URL: $url');
    }
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
      case MessageStatus.delivered:
        return const Icon(Icons.check, size: 12, color: tickColor);
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 12, color: Colors.blue);
    }
  }
}

class _WaveLoadingOverlay extends StatefulWidget {
  const _WaveLoadingOverlay();

  @override
  State<_WaveLoadingOverlay> createState() => _WaveLoadingOverlayState();
}

class _WaveLoadingOverlayState extends State<_WaveLoadingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _WavePainter(
            progress: _controller.value,
            color: Colors.white.withValues(alpha: 0.25),
          ),
        );
      },
    );
  }
}

class _WavePainter extends CustomPainter {
  final double progress;
  final Color color;

  _WavePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final y = size.height * (1 - progress); // Water level rises

    path.moveTo(0, y);
    for (double x = 0; x <= size.width; x++) {
      final waveIntensity = 4.0;
      final waveLength = size.width / 1.5;
      path.lineTo(
          x,
          y +
              waveIntensity *
                  math.sin((x / waveLength + progress) * 2 * math.pi));
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) => true;
}

class _AudioMessagePlayer extends StatefulWidget {
  final String url;
  final bool isMe;

  const _AudioMessagePlayer({required this.url, required this.isMe});

  @override
  State<_AudioMessagePlayer> createState() => _AudioMessagePlayerState();
}

class _AudioMessagePlayerState extends State<_AudioMessagePlayer> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  void _initPlayer() {
    _audioPlayer
        .setSource(UrlSource(widget.url)); // Pre-load source to get duration
    _audioPlayer.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _audioPlayer.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void didUpdateWidget(_AudioMessagePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _audioPlayer.setSource(UrlSource(widget.url));
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play(UrlSource(widget.url));
    }
    if (mounted) setState(() => _isPlaying = !_isPlaying);
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.isMe ? Colors.black : Colors.white;

    return Container(
      width: 200,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          IconButton(
            icon: Icon(
              _isPlaying ? Icons.pause_circle_filled : Icons.play_circle_filled,
              color: color,
              size: 32,
            ),
            onPressed: _togglePlay,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    trackHeight: 2,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 4),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: color,
                    inactiveTrackColor: color.withValues(alpha: 0.2),
                    thumbColor: color,
                  ),
                  child: Slider(
                    min: 0,
                    max: _duration.inMilliseconds.toDouble() > 0
                        ? _duration.inMilliseconds.toDouble()
                        : 1.0,
                    value: _position.inMilliseconds.toDouble().clamp(
                        0.0,
                        _duration.inMilliseconds.toDouble() > 0
                            ? _duration.inMilliseconds.toDouble()
                            : 1.0),
                    onChanged: (value) async {
                      await _audioPlayer
                          .seek(Duration(milliseconds: value.toInt()));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: TextStyle(
                            color: color.withValues(alpha: 0.6), fontSize: 10),
                      ),
                      Text(
                        _formatDuration(_duration),
                        style: TextStyle(
                            color: color.withValues(alpha: 0.6), fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return "$twoDigitMinutes:$twoDigitSeconds";
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

class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
