import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/gossip_colors.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gossip/core/notifications/notification_sound_helper.dart';
import '../../../../shared/utils/toast_utils.dart';

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
  String? _avatarUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.groupData['name']);
    _descriptionController =
        TextEditingController(text: widget.groupData['bio'] ?? '');
    _avatarUrl = widget.groupData['avatar_url'];
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
                    backgroundImage:
                        _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                    child: _avatarUrl == null
                        ? Text(
                            widget.groupData['name']?[0]?.toUpperCase() ?? 'G',
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          )
                        : null,
                  ),
                  if (_isLoading)
                    const Positioned.fill(
                      child: Center(
                        child: CircularProgressIndicator(
                          color: GossipColors.primary,
                        ),
                      ),
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
          const SizedBox(height: 16),
          InkWell(
            onTap: _setCustomNotification,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                children: [
                  Icon(Icons.music_note, color: Colors.purpleAccent, size: 20),
                  SizedBox(width: 12),
                  Text(
                    'Custom Notification',
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

  Future<void> _changeGroupIcon() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 75,
      );

      if (image == null) return;

      setState(() => _isLoading = true);

      final bytes = await image.readAsBytes();
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path = '${widget.roomId}/$fileName';

      await Supabase.instance.client.storage.from('group_avatars').uploadBinary(
          path, bytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg'));

      final publicUrl = Supabase.instance.client.storage
          .from('group_avatars')
          .getPublicUrl(path);

      setState(() {
        _avatarUrl = publicUrl;
        _isLoading = false;
      });

      // Also update the database immediately
      await Supabase.instance.client
          .from('chat_rooms')
          .update({'avatar_url': publicUrl}).eq('id', widget.roomId);
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ToastUtils.showError(context, 'Error: $e');
      }
    }
  }

  Future<void> _setCustomNotification() async {
    // We do NOT pop the context here, we keep the sheet open or maybe better?
    // Actually typically we might want to pop since file picker takes over.
    // But let's keep it consistent with chat detail.
    // Since this is a sheet, file picker will open on top.
    final currentContext = context;
    final success =
        await NotificationSoundHelper.setCustomSound(chatId: widget.roomId);

    if (!currentContext.mounted) return;

    if (success) {
      ToastUtils.showSuccess(currentContext, 'Custom sound set successfully!');
    }
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
                  .select('user_id, role, profiles(username, avatar_url)')
                  .eq('room_id', roomId),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final members = snapshot.data!;
                if (members.isEmpty) {
                  return const Center(
                    child: Text(
                      'No members found',
                      style: TextStyle(color: GossipColors.textDim),
                    ),
                  );
                }
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
                            backgroundImage: member['profiles']
                                        ?['avatar_url'] !=
                                    null
                                ? NetworkImage(member['profiles']['avatar_url'])
                                : null,
                            child: member['profiles']?['avatar_url'] == null
                                ? const Icon(Icons.person,
                                    color: GossipColors.primary)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  member['profiles']?['username'] ?? userId,
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
        ToastUtils.showSuccess(context, 'Member removed successfully!');
        // Refresh the list
        Navigator.pop(context);
        Navigator.pop(context);
      }
    } catch (e) {
      if (context.mounted) {
        ToastUtils.showError(context, 'Error: $e');
      }
    }
  }
}
