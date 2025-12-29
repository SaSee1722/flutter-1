import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:gossip/core/di/injection_container.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import 'package:flutter_animate/flutter_animate.dart';

class UserProfilePreviewScreen extends StatefulWidget {
  final String username;

  const UserProfilePreviewScreen({super.key, required this.username});

  @override
  State<UserProfilePreviewScreen> createState() =>
      _UserProfilePreviewScreenState();
}

class _UserProfilePreviewScreenState extends State<UserProfilePreviewScreen> {
  final ChatRepository _chatRepository = sl<ChatRepository>();
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  Future<void> _fetchUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await _chatRepository.searchUsers(widget.username);
      // Find exact match by username case-insensitively
      final exactMatch = results.firstWhere(
        (u) =>
            u['username']?.toString().toLowerCase() ==
            widget.username.toLowerCase(),
        orElse: () => throw Exception('User not found'),
      );
      setState(() {
        _userData = exactMatch;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _sendFriendRequest() async {
    if (_userData == null) return;
    try {
      await _chatRepository.sendFriendRequest(_userData!['id']);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
        _fetchUser(); // Refresh to show pending status
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: GossipColors.primary))
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 64),
                      const SizedBox(height: 16),
                      Text(_error!,
                          style: const TextStyle(color: Colors.white70)),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _fetchUser,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildProfileContent(),
    );
  }

  Widget _buildProfileContent() {
    final avatarUrl = _userData?['avatar_url'];
    final username = _userData?['username'] ?? 'User';
    final status = _userData?['friendship_status'];

    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Hero(
            tag: 'profile_pic_$username',
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: GossipColors.primary.withValues(alpha: 0.5),
                    width: 4),
                boxShadow: [
                  BoxShadow(
                    color: GossipColors.primary.withValues(alpha: 0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: ClipOval(
                child: avatarUrl != null
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(
                            Icons.person,
                            size: 80,
                            color: Colors.white24),
                      )
                    : const Icon(Icons.person, size: 80, color: Colors.white24),
              ),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
          const SizedBox(height: 24),
          GradientText(
            username.toUpperCase(),
            gradient: GossipColors.primaryGradient,
            style: const TextStyle(
                fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: 2),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 8),
          Text(
            '@$username',
            style: const TextStyle(color: Colors.white38, fontSize: 16),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 48),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: _buildActionButtons(status, username),
          )
              .animate()
              .slideY(begin: 0.5, end: 0, delay: 400.ms, curve: Curves.easeOut),
        ],
      ),
    );
  }

  Widget _buildActionButtons(String? status, String username) {
    if (status == 'accepted') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: GossipColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: GossipColors.primary.withValues(alpha: 0.2)),
        ),
        child: const Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, color: GossipColors.primary),
              SizedBox(width: 8),
              Text(
                'ALREADY FRIENDS',
                style: TextStyle(
                    color: GossipColors.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'pending') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: const Center(
          child: Text(
            'REQUEST PENDING',
            style: TextStyle(
                color: Colors.white38,
                fontWeight: FontWeight.bold,
                letterSpacing: 1),
          ),
        ),
      );
    }

    return Column(
      children: [
        GestureDetector(
          onTap: _sendFriendRequest,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: GossipColors.primaryGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: GossipColors.primary.withValues(alpha: 0.4),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                )
              ],
            ),
            child: const Center(
              child: Text(
                'ADD FRIEND',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    letterSpacing: 1.5),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Join the conversation with $username today',
          style: const TextStyle(color: Colors.white24, fontSize: 12),
        ),
      ],
    );
  }
}
