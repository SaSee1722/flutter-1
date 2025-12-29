import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/core/di/injection_container.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:gossip/shared/utils/toast_utils.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final users = await sl<ChatRepository>().getBlockedUsers();
      if (mounted) {
        setState(() {
          _blockedUsers = users;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError(context, 'Failed to load blocked users');
      }
    }
  }

  Future<void> _unblockUser(String userId) async {
    try {
      await sl<ChatRepository>().unblockUser(userId);
      if (mounted) {
        ToastUtils.showInfo(context, 'User unblocked');
        _loadBlockedUsers();
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError(context, 'Failed to unblock user');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Blocked Users',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _blockedUsers.isEmpty
              ? const Center(
                  child: Text('No blocked users',
                      style: TextStyle(color: GossipColors.textDim)))
              : ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: _blockedUsers.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final user = _blockedUsers[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: GossipColors.cardBackground,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                GossipColors.primary.withValues(alpha: 0.1),
                            backgroundImage: user['avatar_url'] != null
                                ? CachedNetworkImageProvider(user['avatar_url'])
                                : null,
                            child: user['avatar_url'] == null
                                ? Text(user['username'][0].toUpperCase(),
                                    style: const TextStyle(
                                        color: GossipColors.primary,
                                        fontWeight: FontWeight.bold))
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              user['username'] ?? 'Unknown',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _unblockUser(user['id']),
                            child: const Text('UNBLOCK',
                                style: TextStyle(
                                    color: GossipColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12)),
                          ),
                        ],
                      ),
                    ).animate().fadeIn().slideX(begin: 0.1, end: 0);
                  },
                ),
    );
  }
}
