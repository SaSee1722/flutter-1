import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/gossip_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';

class GroupSettingsSheet extends StatefulWidget {
  final String roomId;
  final Map<String, dynamic> groupData;
  final bool isAdmin;

  const GroupSettingsSheet({
    super.key,
    required this.roomId,
    required this.groupData,
    required this.isAdmin,
  });

  @override
  State<GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends State<GroupSettingsSheet> {
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.groupData['name']);
    _descriptionController =
        TextEditingController(text: widget.groupData['bio'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
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
              const Row(
                children: [
                  Text('GROUP',
                      style: TextStyle(
                          color: GossipColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                  Text(' SETTINGS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: GossipColors.primary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Center(
            child: GestureDetector(
              onTap: widget.isAdmin ? _changeGroupIcon : null,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0xFF1A1A1A),
                    backgroundImage: widget.groupData['avatar_url'] != null
                        ? NetworkImage(widget.groupData['avatar_url'])
                        : null,
                    child: widget.groupData['avatar_url'] == null
                        ? Text(
                            widget.groupData['name']?[0]?.toUpperCase() ?? 'P',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  if (widget.isAdmin)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: GossipColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: const Color(0xFF0A0A0A), width: 3),
                        ),
                        child: const Icon(Icons.camera_alt,
                            color: Colors.black, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (widget.isAdmin)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'TAP TO CHANGE ICON',
                  style: TextStyle(
                    color: GossipColors.textDim,
                    fontSize: 10,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 32),
          const Text(
            'GROUP NAME',
            style: TextStyle(
              color: GossipColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameController,
            enabled: widget.isAdmin,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'DESCRIPTION',
            style: TextStyle(
              color: GossipColors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descriptionController,
            enabled: widget.isAdmin,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            maxLines: 2,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF1A1A1A),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            ),
          ),
          const SizedBox(height: 24),
          InkWell(
            onTap: _viewMembers,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.group, color: GossipColors.primary, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'View Members',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Spacer(),
                  Icon(Icons.chevron_right, color: GossipColors.textDim),
                ],
              ),
            ),
          ),
          if (widget.isAdmin) ...[
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _saveChanges,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GossipColors.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SAVE CHANGES',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
          ],
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  void _changeGroupIcon() {
    // TODO: Implement image picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Image picker coming soon!')),
    );
  }

  void _viewMembers() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _GroupMembersSheet(
        roomId: widget.roomId,
        isAdmin: widget.isAdmin,
        adminId: widget.groupData['admin_id'],
      ),
    );
  }

  Future<void> _saveChanges() async {
    try {
      await Supabase.instance.client.from('chat_rooms').update({
        'name': _nameController.text,
        'bio': _descriptionController.text,
      }).eq('id', widget.roomId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}

class _GroupMembersSheet extends StatelessWidget {
  final String roomId;
  final bool isAdmin;
  final String adminId;

  const _GroupMembersSheet({
    required this.roomId,
    required this.isAdmin,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
              TextButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  // Reopen group settings
                },
                icon: const Icon(Icons.arrow_back, color: GossipColors.primary),
                label: const Text(
                  'Back',
                  style: TextStyle(color: GossipColors.primary, fontSize: 14),
                ),
              ),
              const Row(
                children: [
                  Text('GROUP',
                      style: TextStyle(
                          color: GossipColors.primary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                  Text(' MEMBERS',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2)),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white54),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: FutureBuilder<List<dynamic>>(
              future: Supabase.instance.client
                  .from('group_members')
                  .select('user_id, role')
                  .eq('room_id', roomId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snapshot.data!;
                return ListView.builder(
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final userId = member['user_id'];
                    final isOwner = userId == adminId;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 24,
                            backgroundColor:
                                GossipColors.primary.withValues(alpha: 0.2),
                            child: const Icon(Icons.person,
                                color: GossipColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  userId,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (isOwner)
                                  const Text(
                                    'Owner',
                                    style: TextStyle(
                                      color: GossipColors.textDim,
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  const Text(
                                    'Member',
                                    style: TextStyle(
                                      color: GossipColors.textDim,
                                      fontSize: 12,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isAdmin && !isOwner)
                            TextButton(
                              onPressed: () => _removeMember(context, userId),
                              child: const Text(
                                'REMOVE',
                                style: TextStyle(
                                  color: Colors.redAccent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
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
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Future<void> _removeMember(BuildContext context, String userId) async {
    try {
      await Supabase.instance.client
          .from('group_members')
          .delete()
          .eq('room_id', roomId)
          .eq('user_id', userId);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member removed successfully!')),
        );
        // Refresh the list
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
