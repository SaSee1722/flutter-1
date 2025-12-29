import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import 'package:gossip/shared/widgets/glass_card.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/core/services/localization_service.dart';
import 'package:gossip/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:gossip/features/auth/presentation/bloc/auth_event.dart';
import 'package:gossip/features/auth/presentation/bloc/auth_state.dart';
import 'package:gossip/core/di/injection_container.dart';
import 'package:gossip/shared/utils/toast_utils.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'blocked_users_screen.dart';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:gossip/core/constants/supabase_constants.dart';
import 'get_started_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isEditing = false;
  final String _language = 'English';
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _fullNameController;
  late TextEditingController _usernameController;
  late TextEditingController _ageController;
  late TextEditingController _phoneController;
  late TextEditingController _bioController;
  String? _selectedGender;

  Map<String, dynamic>? _profileData;
  bool _isLoadingProfile = true;
  bool _isSaving = false;
  bool _isPublic = true;
  XFile? _localAvatarFile;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _usernameController = TextEditingController();
    _ageController = TextEditingController();
    _phoneController = TextEditingController();
    _bioController = TextEditingController();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = sl<SupabaseClient>().auth.currentUser;
    if (user != null) {
      try {
        final response = await sl<SupabaseClient>()
            .from(SupabaseConstants.profilesTable)
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (mounted && response != null) {
          setState(() {
            _profileData = response;
            _fullNameController.text = response['full_name'] ?? '';
            _usernameController.text = response['username'] ?? '';
            _ageController.text = response['age'] ?? '';
            _phoneController.text = response['phone'] ?? '';
            _bioController.text = response['bio'] ?? '';
            _selectedGender = response['gender'];
            _isPublic = response['is_public'] ?? true;
            _isLoadingProfile = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _isLoadingProfile = false);
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _ageController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  String _t(String key) => LocalizationService.translate(key, _language);

  Color _getGenderColor() {
    final gender = _selectedGender?.toLowerCase() ?? '';
    if (gender == 'male') return const Color(0xFF2FB5E8);
    if (gender == 'female') return const Color(0xFFFF7EB2);
    if (gender == 'others' || gender == 'other') return const Color(0xFFFFD700);
    return GossipColors.primary;
  }

  BoxDecoration _getBackgroundDecoration() {
    return const BoxDecoration(
      color: Colors.black,
    );
  }

  Future<void> _pickImage() async {
    final isDesktop = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux);

    showModalBottomSheet(
      context: context,
      backgroundColor: GossipColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isDesktop)
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.white),
                title: const Text('Take Photo',
                    style: TextStyle(color: Colors.white)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    final XFile? image = await _picker.pickImage(
                      source: ImageSource.camera,
                      maxWidth: 256,
                      maxHeight: 256,
                      imageQuality: 60,
                    );
                    if (image != null) _updateAvatar(image);
                  } catch (e) {
                    if (context.mounted) {
                      ToastUtils.showError(context, 'Camera error: $e');
                    }
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title: Text(
                  isDesktop ? 'Select from Computer' : 'Choose from Gallery',
                  style: const TextStyle(color: Colors.white)),
              onTap: () async {
                Navigator.pop(context);
                try {
                  final XFile? image = await _picker.pickImage(
                    source: ImageSource.gallery,
                    maxWidth: 256,
                    maxHeight: 256,
                    imageQuality: 60,
                  );
                  if (image != null) {
                    _updateAvatar(image);
                  }
                } catch (e) {
                  if (context.mounted) {
                    ToastUtils.showError(context, 'Error selecting image: $e');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _updateAvatar(XFile file) {
    setState(() => _localAvatarFile = file);
    context.read<AuthBloc>().add(AuthProfileUpdateRequested(avatarFile: file));
  }

  Future<void> _toggleVisibility(bool value) async {
    setState(() => _isPublic = value);
    context.read<AuthBloc>().add(AuthProfileUpdateRequested(isPublic: value));
  }

  void _shareProfile() {
    final username = _usernameController.text;
    final name = _fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : 'Gossip User';

    if (username.isEmpty) {
      ToastUtils.showError(
          context, 'Set a username first to share your profile');
      return;
    }

    final message =
        "Hey! Let's talk on GOSSIP. Add me by clicking here:\nhttps://gossip-messenger.web.app/profile/$username\n\nor search for my username: $username\nMy name is $name.";

    // ignore: deprecated_member_use
    Share.share(message);
  }

  void _saveChanges() {
    setState(() => _isSaving = true);
    context.read<AuthBloc>().add(AuthProfileUpdateRequested(
          fullName: _fullNameController.text,
          username: _usernameController.text,
          age: _ageController.text,
          phone: _phoneController.text,
          gender: _selectedGender,
          bio: _bioController.text,
        ));
    setState(() => _isEditing = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: GossipColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Glow Effect
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _getGenderColor().withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ).animate().fadeIn(duration: 1000.ms),

          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: _getBackgroundDecoration(),
            child: BlocListener<AuthBloc, AuthState>(
              listener: (context, state) {
                if (state is AuthUnauthenticated) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const GetStartedScreen()),
                    (route) => false,
                  );
                } else if (state is AuthAuthenticated) {
                  if (_localAvatarFile != null) {
                    setState(() => _localAvatarFile = null);
                    ToastUtils.showSuccess(
                        context, 'Avatar updated successfully');
                  }
                  if (_isSaving) {
                    ToastUtils.showSuccess(
                        context, 'Profile updated successfully');
                    _isSaving = false;
                  }
                } else if (state is AuthFailure) {
                  setState(() {
                    _isSaving = false;
                    _localAvatarFile = null;
                  });
                  ToastUtils.showError(context, state.message);
                }
              },
              child: SafeArea(
                bottom: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 800),
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 40),
                          _buildProfileHeader()
                              .animate()
                              .fadeIn(duration: 600.ms)
                              .scale(
                                  begin: const Offset(0.9, 0.9),
                                  end: const Offset(1, 1)),
                          const SizedBox(height: 40),
                          _buildPersonalInfoSection(),
                          const SizedBox(height: 32),
                          _buildSettingsSection(),
                          const SizedBox(height: 32),
                          _buildLogoutButton(),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    final avatarUrl = _profileData?['avatar_url'];
    final name = _fullNameController.text.isNotEmpty
        ? _fullNameController.text
        : 'Gossip User';
    final email = sl<SupabaseClient>().auth.currentUser?.email ?? '';

    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _getGenderColor().withValues(alpha: 0.5),
                    blurRadius: 40,
                    spreadRadius: 4,
                  )
                ],
                border: Border.all(color: Colors.white24, width: 2),
              ),
              child: ClipOval(
                child: _localAvatarFile != null
                    ? (kIsWeb
                        ? Image.network(_localAvatarFile!.path,
                            fit: BoxFit.cover)
                        : Image.file(File(_localAvatarFile!.path),
                            fit: BoxFit.cover))
                    : avatarUrl != null
                        ? CachedNetworkImage(
                            imageUrl: avatarUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: Colors.white.withValues(alpha: 0.05),
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: GossipColors.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Image.network(
                                'https://picsum.photos/seed/profile/300',
                                fit: BoxFit.cover),
                          )
                        : Image.network(
                            'https://picsum.photos/seed/profile/300',
                            fit: BoxFit.cover),
              ),
            ),
            Positioned(
              bottom: 4,
              right: 4,
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: GossipColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 4)
                    ],
                  ),
                  child: const Icon(Icons.camera_enhance_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        GradientText(
          name.toUpperCase(),
          gradient: GossipColors.primaryGradient,
          style: const TextStyle(
              fontSize: 26, fontWeight: FontWeight.w900, letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        Text(
          email,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 13,
              letterSpacing: 1),
        ),
      ],
    );
  }

  Widget _buildPersonalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                GradientText(
                  _t('personal_info'),
                  gradient: GossipColors.primaryGradient,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
                const SizedBox(width: 8),
                Image.asset('assets/images/personal_info_header.png',
                    height: 45, fit: BoxFit.contain),
              ],
            ),
            _buildEditButton(),
          ],
        ),
        const SizedBox(height: 16),
        _isEditing ? _buildCardStyleEdit() : _buildDisplayInfo(),
      ],
    );
  }

  Widget _buildEditButton() {
    return GestureDetector(
      onTap: () {
        if (_isEditing) {
          _saveChanges();
        } else {
          setState(() => _isEditing = true);
        }
      },
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          gradient: _isEditing ? GossipColors.primaryGradient : null,
          color: _isEditing ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          _isEditing ? _t('save') : _t('edit'),
          style: TextStyle(
            color: _isEditing ? Colors.white : GossipColors.primary,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildCardStyleEdit() {
    return Column(
      children: [
        _buildEditItem(
            Icons.person_outline, _t('full_name'), _fullNameController),
        const SizedBox(height: 12),
        _buildEditItem(
            Icons.alternate_email, _t('username'), _usernameController),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _buildEditItem(
                    Icons.calendar_today, _t('age'), _ageController)),
            const SizedBox(width: 12),
            Expanded(child: _buildGenderDropdownCard()),
          ],
        ),
        const SizedBox(height: 12),
        _buildEditItem(Icons.phone_android, _t('phone'), _phoneController),
        const SizedBox(height: 12),
        _buildEditItem(Icons.info_outline, _t('bio'), _bioController,
            maxLines: 3),
      ],
    ).animate().fadeIn(duration: 400.ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildEditItem(
      IconData icon, String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, color: _getGenderColor(), size: 14),
                    const SizedBox(width: 8),
                    Text(label.toUpperCase(),
                        style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1)),
                  ],
                ),
                TextField(
                  controller: controller,
                  maxLines: maxLines,
                  cursorColor: _getGenderColor(),
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.normal),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Enter $label',
                    hintStyle: TextStyle(
                        color: Colors.white.withValues(alpha: 0.1),
                        fontSize: 15),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGenderDropdownCard() {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      opacity: 0.1,
      borderRadius: 20,
      border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wc, color: GossipColors.primary, size: 14),
              const SizedBox(width: 8),
              Text(_t('gender'),
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.4),
                      fontSize: 10,
                      fontWeight: FontWeight.bold)),
            ],
          ),
          DropdownButton<String>(
            value: ['Male', 'Female', 'Others'].contains(_selectedGender)
                ? _selectedGender
                : null,
            dropdownColor: const Color(0xFF1A1A1A),
            underline: const SizedBox(),
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down_rounded,
                color: Colors.white24, size: 20),
            hint: const Text('Select',
                style: TextStyle(color: Colors.white24, fontSize: 14)),
            style: const TextStyle(color: Colors.white, fontSize: 15),
            items: ['Male', 'Female', 'Others']
                .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                .toList(),
            onChanged: (v) => setState(() => _selectedGender = v),
          ),
        ],
      ),
    );
  }

  Widget _buildDisplayInfo() {
    return GlassCard(
      padding: const EdgeInsets.all(8),
      opacity: 0.05,
      child: Column(
        children: [
          _buildInfoRow(
              Icons.person_outline, _t('full_name'), _fullNameController.text),
          _buildInfoRow(
              Icons.alternate_email, _t('username'), _usernameController.text),
          _buildInfoRow(Icons.calendar_today, _t('age'), _ageController.text),
          _buildInfoRow(
              Icons.phone_android, _t('phone'), _phoneController.text),
          _buildInfoRow(
              Icons.wc, _t('gender'), _selectedGender ?? 'Not Specified'),
          _buildInfoRow(Icons.info_outline, _t('bio'), _bioController.text),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                shape: BoxShape.circle),
            child: Icon(icon, color: GossipColors.primary, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: GossipColors.textDim,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value.isEmpty ? '---' : value,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GradientText(
              _t('settings'),
              gradient: GossipColors.primaryGradient,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2),
            ),
            const SizedBox(width: 8),
            Image.asset('assets/images/gossip_header.png',
                height: 45, fit: BoxFit.contain),
          ],
        ),
        const SizedBox(height: 16),
        GlassCard(
          padding: const EdgeInsets.all(8),
          opacity: 0.05,
          child: Column(
            children: [
              _SettingsToggle(
                  icon: Icons.notifications_none_rounded,
                  label: _t('notifications'),
                  value: true,
                  onChanged: (v) {}),
              _SettingsToggle(
                  icon: _isPublic
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                  label: _t('public_visibility'),
                  value: _isPublic,
                  onChanged: _toggleVisibility),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const BlockedUsersScreen()),
                  );
                },
                behavior: HitTestBehavior.opaque,
                child: _SettingsChevron(
                  icon: Icons.block_rounded,
                  label: _t('blocked_users'),
                ),
              ),
              GestureDetector(
                onTap: () => _showAboutUs(context),
                behavior: HitTestBehavior.opaque,
                child: const _SettingsChevron(
                  icon: Icons.info_outline_rounded,
                  label: 'About Us',
                ),
              ),
              GestureDetector(
                onTap: _shareProfile,
                behavior: HitTestBehavior.opaque,
                child: _SettingsChevron(
                  icon: Icons.share_rounded,
                  label: _t('share_profile'),
                ),
              ),
              GestureDetector(
                onTap: () => _showDeleteAccountConfirmation(context),
                behavior: HitTestBehavior.opaque,
                child: const _SettingsChevron(
                  icon: Icons.delete_forever_rounded,
                  label: 'Delete Account',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAboutUs(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0D0D0D),
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GradientText('ABOUT GOSSIP.',
                gradient: GossipColors.primaryGradient,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text(
              'Gossip is a premium messaging platform designed for those who appreciate style and substance. Connect with friends and communities in a beautifully crafted environment.',
              style:
                  TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 24),
            const Text(
              'Version 1.0.0',
              style: TextStyle(color: Colors.white24, fontSize: 12),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDeleteAccountConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text('Delete Account?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This action is permanent and cannot be undone. All your messages and profile data will be lost.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white24)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              try {
                // Show loading indicator
                if (context.mounted) {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => const Center(
                        child: CircularProgressIndicator(
                            color: GossipColors.primary)),
                  );
                }

                await sl<ChatRepository>().deleteAccount();

                if (!context.mounted) return;
                Navigator.pop(context); // Close loading indicator

                ToastUtils.showSuccess(
                    context, 'Successfully deleted your account');

                // Small delay to let the toast be seen
                await Future.delayed(const Duration(milliseconds: 500));
                if (!context.mounted) return;

                context.read<AuthBloc>().add(AuthLogoutRequested());
              } catch (e) {
                if (!context.mounted) return;
                try {
                  Navigator.pop(context); // Close loading indicator if open
                } catch (_) {}
                ToastUtils.showError(context, 'Account deletion failed: $e');
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return GestureDetector(
      onTap: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFF1A0808),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded,
                color: GossipColors.secondary, size: 20),
            const SizedBox(width: 12),
            Text(_t('logout'),
                style: const TextStyle(
                    color: GossipColors.secondary,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

class _SettingsToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggle(
      {required this.icon,
      required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 16),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 14))),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: GossipColors.primary,
            activeTrackColor: GossipColors.primary.withValues(alpha: 0.2),
          ),
        ],
      ),
    );
  }
}

class _SettingsChevron extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SettingsChevron({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 16),
          Expanded(
              child: Text(label,
                  style: const TextStyle(color: Colors.white, fontSize: 14))),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right_rounded, color: Colors.white24),
        ],
      ),
    );
  }
}
