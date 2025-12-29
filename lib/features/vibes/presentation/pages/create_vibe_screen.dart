import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/vibes/domain/entities/user_status.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_bloc.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_state.dart';
import 'package:gossip/features/vibes/presentation/pages/vibe_preview_screen.dart';
import 'package:gossip/features/vibes/presentation/pages/vibe_view_screen.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import 'package:gossip/shared/utils/toast_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateVibeScreen extends StatefulWidget {
  const CreateVibeScreen({super.key});

  @override
  State<CreateVibeScreen> createState() => _CreateVibeScreenState();
}

class _CreateVibeScreenState extends State<CreateVibeScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    // macOS and Windows do not support camera in image_picker
    if (source == ImageSource.camera &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      if (mounted) {
        ToastUtils.showError(context,
            'Camera capture is only supported on Mobile devices. Please use Gallery to upload from your files.');
      }
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (image != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VibePreviewScreen(file: image, isVideo: false),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('cameraDelegate')) {
          ToastUtils.showError(context,
              'Unable to access camera on this platform. Please use the Gallery option.');
        } else {
          ToastUtils.showError(context, 'Failed to pick image: $e');
        }
      }
    }
  }

  Future<void> _pickVideo(ImageSource source) async {
    // macOS and Windows do not support camera in image_picker
    if (source == ImageSource.camera &&
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.macOS ||
            defaultTargetPlatform == TargetPlatform.windows)) {
      if (mounted) {
        ToastUtils.showError(context,
            'Video capture is only supported on Mobile devices. Please use Gallery to upload from your files.');
      }
      return;
    }

    try {
      final XFile? video = await _picker.pickVideo(
        source: source,
        maxDuration: const Duration(seconds: 30),
      );
      if (video != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VibePreviewScreen(file: video, isVideo: true),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString();
        if (errorMsg.contains('cameraDelegate')) {
          ToastUtils.showError(context,
              'Unable to access camera on this platform. Please use the Gallery option.');
        } else {
          ToastUtils.showError(context, 'Failed to pick video: $e');
        }
      }
    }
  }

  void _showMediaOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GossipColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.camera_alt,
                    color: Colors.blueAccent, size: 20),
              ),
              title: const Text('Capture Image',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.videocam,
                    color: Colors.redAccent, size: 20),
              ),
              title: const Text('Capture Video (Max 30s)',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _pickVideo(ImageSource.camera);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: GossipColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.photo_library,
                    color: GossipColors.primary, size: 20),
              ),
              title: const Text('Gallery',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                _showGalleryOptions();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showGalleryOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: GossipColors.cardBackground,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildGalleryOption(
                  icon: Icons.image,
                  label: 'Image',
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                _buildGalleryOption(
                  icon: Icons.videocam,
                  label: 'Video',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideo(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildGalleryOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: BlocConsumer<VibeBloc, VibeState>(
                listener: (context, state) {
                  if (state is VibeError) {
                    ToastUtils.showError(context, state.message);
                  }
                },
                builder: (context, state) {
                  UserStatus? myVibe;
                  if (state is VibesLoaded) {
                    final currentUserId =
                        Supabase.instance.client.auth.currentUser?.id;
                    try {
                      myVibe = state.vibes
                          .firstWhere((v) => v.userId == currentUserId);
                    } catch (_) {}
                  }

                  return Padding(
                    padding:
                        const EdgeInsets.only(top: 40, left: 24, right: 24),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPostVibeCard(),
                        const SizedBox(width: 20),
                        if (myVibe != null)
                          _buildMyVibeCard(myVibe)
                              .animate()
                              .fadeIn()
                              .slideX(begin: 0.2, end: 0),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white54),
          ),
          Column(
            children: [
              GradientText(
                'VIBES',
                gradient: GossipColors.primaryGradient,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'DISAPPEARING STORIES OF YOUR CIRCLE.',
                style: TextStyle(
                  color: GossipColors.textDim,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: _showMediaOptions,
            icon: const Icon(Icons.camera_alt_outlined, color: Colors.white54),
            style: IconButton.styleFrom(
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostVibeCard() {
    return GestureDetector(
      onTap: _showMediaOptions,
      child: Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.2),
            width: 1,
            style: BorderStyle
                .solid, // Custom dashed border painter could be used here but solid with low opacity looks fine or we can add a DashPainter
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, color: Colors.white, size: 32),
            const SizedBox(height: 12),
            const Text(
              'POST VIBE',
              style: TextStyle(
                color: GossipColors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyVibeCard(UserStatus vibe) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VibeViewScreen(vibes: [vibe], initialIndex: 0),
        ),
      ),
      child: Container(
        width: 120,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          image: DecorationImage(
            image: CachedNetworkImageProvider(vibe.mediaUrl), // Optimized logic
            fit: BoxFit.cover,
          ),
          boxShadow: [
            BoxShadow(
              color: GossipColors.primary.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 10,
                    backgroundColor: GossipColors.primary,
                    backgroundImage: vibe.mediaUrl.isNotEmpty
                        ? CachedNetworkImageProvider(vibe.mediaUrl)
                        : null,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Your Vibe',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
