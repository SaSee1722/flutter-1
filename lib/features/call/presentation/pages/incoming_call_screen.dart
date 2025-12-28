import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/theme/gossip_colors.dart';
import '../bloc/call_bloc.dart';
import '../bloc/call_event.dart';
import '../bloc/call_state.dart';

class IncomingCallScreen extends StatelessWidget {
  final CallRinging state;

  const IncomingCallScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    GossipColors.primary.withValues(alpha: 0.2),
                    Colors.black,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Avatar with Pulse
                Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ...List.generate(3, (index) {
                        return Container(
                          width: 140 + (index * 40.0),
                          height: 140 + (index * 40.0),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color:
                                  GossipColors.primary.withValues(alpha: 0.1),
                              width: 2,
                            ),
                          ),
                        )
                            .animate(
                                onPlay: (controller) => controller.repeat())
                            .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.5, 1.5),
                              duration: 2.seconds,
                              curve: Curves.easeOut,
                              delay: (index * 0.5).seconds,
                            )
                            .fadeOut();
                      }),
                      CircleAvatar(
                        radius: 70,
                        backgroundColor: GossipColors.cardBackground,
                        backgroundImage: state.callerAvatar != null
                            ? NetworkImage(state.callerAvatar!)
                            : null,
                        child: state.callerAvatar == null
                            ? Text(
                                (state.callerName.isNotEmpty
                                        ? state.callerName[0]
                                        : "?")
                                    .toUpperCase(),
                                style: const TextStyle(
                                    fontSize: 40, color: Colors.white),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  state.callerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ).animate().fadeIn().slideY(begin: 0.3),

                const SizedBox(height: 8),

                Text(
                  state.isIncoming
                      ? "GOSSIP ${state.isVideo ? 'VIDEO' : 'AUDIO'} CALL"
                      : "CALLING...",
                  style: const TextStyle(
                    color: GossipColors.primary,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w500,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: 1.seconds),

                const Spacer(),

                // Actions
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 64),
                  child: state.isIncoming
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Decline
                            _CallButton(
                              icon: Icons.call_end,
                              color: Colors.red,
                              label: "Decline",
                              onPressed: () {
                                context
                                    .read<CallBloc>()
                                    .add(RejectCall(state.callId));
                              },
                            ),

                            // Accept
                            _CallButton(
                              icon: state.isVideo ? Icons.videocam : Icons.call,
                              color: Colors.green,
                              label: "Accept",
                              onPressed: () {
                                context
                                    .read<CallBloc>()
                                    .add(AnswerCall(state.callId));
                              },
                            ),
                          ],
                        )
                      : Center(
                          // Cancel (if outgoing)
                          child: _CallButton(
                            icon: Icons.close,
                            color: Colors.red,
                            label: "Cancel",
                            onPressed: () {
                              context
                                  .read<CallBloc>()
                                  .add(EndCall(state.callId));
                            },
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CallButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onPressed;

  const _CallButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          label,
          style: const TextStyle(color: GossipColors.textDim, fontSize: 12),
        ),
      ],
    ).animate().scale(delay: 500.ms);
  }
}
