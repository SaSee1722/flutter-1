import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import '../../../../core/theme/gossip_colors.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/di/injection_container.dart';
import '../../domain/repositories/chat_repository.dart';

class GroupsScreen extends StatelessWidget {
  const GroupsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context)
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: -0.2, end: 0),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildGroupsSection()
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
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
                    'GROUPS.',
                    gradient: GossipColors.primaryGradient,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/groups_header.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showCreateGroup(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: GossipColors.primaryGradient.colors
                          .map((c) => c.withValues(alpha: 0.2))
                          .toList(),
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Communities you belong to.',
            style: TextStyle(color: GossipColors.textDim, fontSize: 13),
          ),
        ],
      ),
    );
  }

  void _showCreateGroup(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateGroupSheet(),
    );
  }

  Widget _buildGroupsSection() {
    return StreamBuilder<List<dynamic>>(
      stream: sl<ChatRepository>().currentUser != null
          ? Supabase.instance.client
              .from('group_members')
              .stream(primaryKey: ['id']).eq(
                  'user_id', sl<ChatRepository>().currentUser!.id)
          : Stream.value([]),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: GossipColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Text(
                  'You are not in any groups.',
                  style: TextStyle(color: GossipColors.textDim),
                ),
              ),
            ),
          );
        }

        final groupMemberships = snapshot.data!;
        final roomIds = groupMemberships.map((m) => m['room_id']).toList();

        return FutureBuilder<List<dynamic>>(
          future: Supabase.instance.client
              .from('chat_rooms')
              .select()
              .inFilter('id', roomIds),
          builder: (context, groupSnapshot) {
            if (!groupSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final groups = groupSnapshot.data!;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _GroupListItem(group: group);
              },
            );
          },
        );
      },
    );
  }
}

class _CreateGroupSheet extends StatefulWidget {
  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final List<String> _selectedFriends = [];
  final TextEditingController _nameController = TextEditingController();
  List<Map<String, dynamic>> _friends = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    try {
      final contacts = await sl<ChatRepository>().getContacts();
      if (mounted) {
        setState(() {
          _friends = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: GossipColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GradientText(
                'CREATE GROUP.',
                gradient: GossipColors.primaryGradient,
                style: const TextStyle(
                  fontSize: 24,
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
          TextField(
            controller: _nameController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Group Name',
              hintStyle: const TextStyle(color: GossipColors.textDim),
              filled: true,
              fillColor: GossipColors.cardBackground,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'SELECT FRIENDS',
            style: TextStyle(
              color: GossipColors.textDim,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _friends.isEmpty
                    ? const Center(
                        child: Text('No friends found to add',
                            style: TextStyle(color: GossipColors.textDim)),
                      )
                    : ListView.separated(
                        itemCount: _friends.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final friend = _friends[index];
                          final isSelected =
                              _selectedFriends.contains(friend['id']);
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              backgroundColor: Colors.white12,
                              backgroundImage: friend['avatar'] != null
                                  ? NetworkImage(friend['avatar'])
                                  : null,
                              child: friend['avatar'] == null
                                  ? Text(friend['name']?[0] ?? '?')
                                  : null,
                            ),
                            title: Text(friend['name'] ?? 'Unknown',
                                style: const TextStyle(color: Colors.white)),
                            trailing: Checkbox(
                              value: isSelected,
                              onChanged: (val) {
                                setState(() {
                                  if (val == true) {
                                    _selectedFriends.add(friend['id']!);
                                  } else {
                                    _selectedFriends.remove(friend['id']);
                                  }
                                });
                              },
                              activeColor: GossipColors.primary,
                              checkColor: Colors.black,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4)),
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedFriends.isEmpty ||
                      _nameController.text.isEmpty
                  ? null
                  : () async {
                      try {
                        await sl<ChatRepository>().createGroup(
                          name: _nameController.text,
                          memberIds: _selectedFriends,
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Group created successfully!')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Failed to create group: $e')),
                          );
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: GossipColors.primary,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('CREATE',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupListItem extends StatelessWidget {
  final Map<String, dynamic> group;

  const _GroupListItem({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: GossipColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: CircleAvatar(
          radius: 28,
          backgroundColor: GossipColors.primary.withValues(alpha: 0.2),
          backgroundImage: group['avatar_url'] != null
              ? NetworkImage(group['avatar_url'])
              : null,
          child: group['avatar_url'] == null
              ? const Icon(Icons.group, color: GossipColors.primary)
              : null,
        ),
        title: Text(
          group['name'] ?? 'Unnamed Group',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          group['bio'] ?? 'No description',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: GossipColors.textDim,
            fontSize: 13,
          ),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: GossipColors.textDim,
        ),
        onTap: () {
          // TODO: Navigate to group chat
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opening ${group['name']}')),
          );
        },
      ),
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }
}
