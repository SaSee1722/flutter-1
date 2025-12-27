import 'package:flutter/material.dart';
import '../../../../core/theme/gossip_colors.dart';

class GroupInfoScreen extends StatelessWidget {
  final String groupName;
  final bool isAdmin;

  const GroupInfoScreen({
    super.key,
    required this.groupName,
    this.isAdmin = false,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Group Info', style: TextStyle(color: Colors.white)),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () {},
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileSection(),
            const SizedBox(height: 32),
            _buildMembersSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: GossipColors.primary, width: 2),
                image: const DecorationImage(
                  image: NetworkImage('https://picsum.photos/seed/group/300'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (isAdmin)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: GossipColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.camera_alt,
                      size: 18, color: Colors.black),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          groupName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Group Bio: Discussing the latest vibes...',
          style: TextStyle(color: GossipColors.textDim, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildMembersSection(BuildContext context) {
    final members = [
      {'name': 'Sakthi Shree', 'role': 'Admin'},
      {'name': 'Alice', 'role': 'Member'},
      {'name': 'Bob', 'role': 'Member'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'MEMBERS',
                style: TextStyle(
                  color: GossipColors.textDim,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                '${members.length} Members',
                style:
                    const TextStyle(color: GossipColors.textDim, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: GossipColors.cardBackground,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white12),
            ),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              separatorBuilder: (_, __) =>
                  Divider(color: Colors.white.withValues(alpha: 0.05)),
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: Text(member['name']![0]),
                  ),
                  title: Text(member['name']!,
                      style: const TextStyle(color: Colors.white)),
                  subtitle: Text(member['role']!,
                      style: const TextStyle(
                          color: GossipColors.textDim, fontSize: 12)),
                  trailing: isAdmin && member['role'] != 'Admin'
                      ? IconButton(
                          icon: const Icon(Icons.person_remove,
                              color: Colors.redAccent, size: 20),
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text('Removed ${member['name']}')),
                            );
                          },
                        )
                      : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
