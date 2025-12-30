import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:glassmorphism_ui/glassmorphism_ui.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/gossip_colors.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

class ActiveCallScreen extends StatefulWidget {
  final CallActive state;

  const ActiveCallScreen({super.key, required this.state});

  @override
  State<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends State<ActiveCallScreen> {
  bool _showControls = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Remote Video Grid or Placeholder
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(() => _showControls = !_showControls),
              child: Stack(
                children: [
                  // Remote Video (Always in tree to ensure audio plays)
                  if (widget.state.remoteRenderers.isNotEmpty)
                    _buildVideoGrid(),

                  // Audio Placeholder (Overlay if not a video call)
                  if (!widget.state.isVideo) _buildAudioPlaceholder(),
                ],
              ),
            ),
          ),

          // Local Video (PiP) - Only show in 1-1 to save space in groups for now
          if (!widget.state.isVideoOff &&
              widget.state.remoteRenderers.length <= 1)
            Positioned(
              top: 60,
              right: 20,
              width: 110,
              height: 160,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  color: Colors.white10,
                  child: RTCVideoView(
                    widget.state.localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ).animate().fadeIn().slideX(begin: 0.5),

          // Header (Name & Status)
          if (_showControls)
            Positioned(
              top: 60,
              left: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.state.remoteName ?? "Group Call",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.lock_rounded,
                          color: GossipColors.primary, size: 12),
                      const SizedBox(width: 4),
                      const Text(
                        "End-to-end encrypted",
                        style: TextStyle(
                            color: GossipColors.textDim, fontSize: 10),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.state.formattedDuration,
                        style: const TextStyle(
                          color: GossipColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.5),

          // Bottom Controls
          if (_showControls)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: GlassContainer(
                  blur: 20,
                  opacity: 0.1,
                  borderRadius: BorderRadius.circular(40),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _ControlIcon(
                          icon:
                              widget.state.isMuted ? Icons.mic_off : Icons.mic,
                          isActive: widget.state.isMuted,
                          onTap: () =>
                              context.read<CallBloc>().add(ToggleMute()),
                        ),
                        _ControlIcon(
                          icon: widget.state.isVideoOff
                              ? Icons.videocam_off
                              : Icons.videocam,
                          isActive: widget.state.isVideoOff,
                          onTap: () =>
                              context.read<CallBloc>().add(ToggleVideo()),
                        ),
                        _ControlIcon(
                          icon: Icons.volume_up,
                          isActive: widget.state.isSpeakerOn,
                          onTap: () =>
                              context.read<CallBloc>().add(ToggleSpeaker()),
                        ),
                        _ControlIcon(
                          icon: Icons.call_end,
                          color: Colors.red,
                          onTap: () => context
                              .read<CallBloc>()
                              .add(EndCall(widget.state.callId)),
                        ),
                      ],
                    ),
                  ),
                ),
              ).animate().fadeIn().slideY(begin: 0.5),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoGrid() {
    final renderers = widget.state.remoteRenderers.values.toList();

    if (renderers.length == 1) {
      final renderer = renderers.first;
      return RTCVideoView(
        renderer,
        key: ValueKey(
            'remote_video_${renderer.hashCode}_${renderer.srcObject?.id}_${renderer.srcObject?.getVideoTracks().length}'),
        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
      );
    }

    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: renderers.length <= 2 ? 1 : 2,
        childAspectRatio: renderers.length <= 2 ? 1 : 0.7,
      ),
      itemCount: renderers.length,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.black, width: 1),
          ),
          child: RTCVideoView(
            renderers[index],
            objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
          ),
        );
      },
    );
  }

  Widget _buildAudioPlaceholder() {
    return Container(
      color: GossipColors.background,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 80,
              backgroundColor: GossipColors.cardBackground,
              backgroundImage: widget.state.remoteAvatar != null
                  ? NetworkImage(widget.state.remoteAvatar!)
                  : null,
              child: widget.state.remoteAvatar == null
                  ? Text(
                      (widget.state.remoteName?[0] ?? "G").toUpperCase(),
                      style: const TextStyle(fontSize: 50, color: Colors.white),
                    )
                  : null,
            ).animate(onPlay: (c) => c.repeat(reverse: true)).scale(
                begin: const Offset(1, 1),
                end: const Offset(1.05, 1.05),
                duration: 2.seconds),
            const SizedBox(height: 24),
            Text(
              widget.state.formattedDuration,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w300,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ControlIcon extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color? color;
  final VoidCallback onTap;

  const _ControlIcon({
    required this.icon,
    this.isActive = false,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color ?? (isActive ? Colors.white : Colors.white10),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: color != null
              ? Colors.white
              : (isActive ? Colors.black : Colors.white),
          size: 28,
        ),
      ),
    );
  }
}
