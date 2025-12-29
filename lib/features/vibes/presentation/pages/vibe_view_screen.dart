import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/vibes/domain/entities/user_status.dart';
import 'package:video_player/video_player.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_bloc.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_event.dart';
import 'package:gossip/core/di/injection_container.dart';
import 'package:gossip/features/vibes/domain/repositories/status_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class VibeViewScreen extends StatefulWidget {
  final List<UserStatus> vibes;
  final int initialIndex;

  const VibeViewScreen({
    super.key,
    required this.vibes,
    this.initialIndex = 0,
  });

  @override
  State<VibeViewScreen> createState() => _VibeViewScreenState();
}

class _VibeViewScreenState extends State<VibeViewScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  VideoPlayerController? _videoController;
  late int _currentIndex;

  UserStatus get _currentVibe => widget.vibes[_currentIndex];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _progressController = AnimationController(vsync: this);
    _startTimer();
  }

  Future<void> _startTimer() async {
    _progressController.stop();
    _progressController.reset();

    await _videoController?.dispose();
    _videoController = null;

    if (_currentVibe.isVideo) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(_currentVibe.mediaUrl));
      try {
        await _videoController!.initialize();
        // Limit to 30s if longer, or use video duration
        final duration =
            _videoController!.value.duration > const Duration(seconds: 30)
                ? const Duration(seconds: 30)
                : _videoController!.value.duration;

        _progressController.duration = duration;
        await _videoController!.play();
        if (mounted) setState(() {});
      } catch (e) {
        _progressController.duration = const Duration(seconds: 15);
      }
    } else {
      _progressController.duration = const Duration(seconds: 15);
    }

    _progressController.forward().whenComplete(_nextVibe);
    _markViewed(); // Mark as viewed when starting the timer
  }

  void _nextVibe() {
    if (!mounted) return;
    if (_currentIndex < widget.vibes.length - 1) {
      setState(() {
        _currentIndex++;
      });
      _startTimer();
    } else {
      Navigator.pop(context);
    }
  }

  void _prevVibe() {
    if (!mounted) return;
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
      });
      _startTimer();
    } else {
      _progressController.forward(from: 0);
      _videoController?.seekTo(Duration.zero);
      _videoController?.play();
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _handleTap(TapUpDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final tapPosition = details.globalPosition.dx;

    if (tapPosition < screenWidth / 3) {
      _prevVibe();
    } else {
      _nextVibe();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vibe = _currentVibe;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTapDown: (_) {
          _progressController.stop();
          _videoController?.pause();
        },
        onTapUp: (details) {
          _handleTap(details);
          _progressController.forward();
          _videoController?.play();
        },
        onLongPress: () {
          _progressController.stop();
          _videoController?.pause();
        },
        onLongPressEnd: (_) {
          _progressController.forward();
          _videoController?.play();
        },
        onVerticalDragEnd: (details) {
          if (details.primaryVelocity! > 0) {
            Navigator.pop(context);
          }
        },
        child: Stack(
          children: [
            // Content
            Center(
              child: vibe.isVideo
                  ? (_videoController != null &&
                          _videoController!.value.isInitialized
                      ? AspectRatio(
                          aspectRatio: _videoController!.value.aspectRatio,
                          child: VideoPlayer(_videoController!),
                        )
                      : const CircularProgressIndicator(
                          color: GossipColors.primary))
                  : CachedNetworkImage(
                      imageUrl: vibe.mediaUrl,
                      fit: BoxFit.scaleDown,
                      placeholder: (context, url) => const Center(
                        child: CircularProgressIndicator(
                          color: GossipColors.primary,
                        ),
                      ),
                      errorWidget: (context, _, __) =>
                          const Icon(Icons.broken_image, color: Colors.white),
                    ),
            ),

            // Gradient Overlay
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.6),
                    ],
                  ),
                ),
              ),
            ),

            // Progress Bar
            Positioned(
              top: 40,
              left: 10,
              right: 10,
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: Colors.white24,
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 2,
                  );
                },
              ),
            ),

            // User Info
            Positioned(
              top: 54,
              left: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundImage: vibe.avatarUrl != null
                        ? CachedNetworkImageProvider(vibe.avatarUrl!)
                        : CachedNetworkImageProvider(
                            'https://picsum.photos/seed/${vibe.username.hashCode}/100'),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vibe.username ?? 'Unknown',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        _timeAgo(vibe.createdAt),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Top Bar additions
            Positioned(
              top: 54,
              right: 64, // To the left of close button
              child: vibe.userId ==
                      Supabase.instance.client.auth.currentUser?.id
                  ? IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: () => _confirmDelete(context, vibe),
                    )
                  : const SizedBox(),
            ),

            // Close Button
            Positioned(
              top: 54,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),

            // Caption
            if (vibe.caption != null && vibe.caption!.isNotEmpty)
              Positioned(
                bottom: 80,
                left: 16,
                right: 16,
                child: Text(
                  vibe.caption!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        color: Colors.black,
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.2, end: 0),

            // Viewer Stats (Eye icon)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child:
                  vibe.userId == Supabase.instance.client.auth.currentUser?.id
                      ? Column(
                          children: [
                            const Icon(Icons.remove_red_eye_outlined,
                                color: Colors.white, size: 24),
                            const SizedBox(height: 4),
                            Text(
                              '${vibe.viewCount} Views',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        )
                      : const SizedBox(),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, UserStatus vibe) {
    _progressController.stop();
    _videoController?.pause();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: GossipColors.cardBackground,
        title:
            const Text('Delete Vibe?', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to remove this vibe?',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _progressController.forward();
              _videoController?.play();
            },
            child:
                const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              try {
                // Use the parent context to access the bloc
                context.read<VibeBloc>().add(DeleteVibe(vibe.id));
              } catch (e) {
                // Fallback
                sl<StatusRepository>().deleteStatus(vibe.id);
              }
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Close vibe view
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Future<void> _markViewed() async {
    final vibe = _currentVibe;
    final myId = Supabase.instance.client.auth.currentUser?.id;
    if (vibe.userId != myId) {
      await sl<StatusRepository>().markStatusViewed(vibe.id);
    }
  }

  String _timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
