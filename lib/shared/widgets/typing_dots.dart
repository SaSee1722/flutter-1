import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/core/theme/gossip_colors.dart';

class TypingDots extends StatelessWidget {
  final Color? color;
  final double dotSize;
  final double spacing;

  const TypingDots({
    super.key,
    this.color,
    this.dotSize = 4,
    this.spacing = 2,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? GossipColors.primary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        3,
        (i) => Container(
          margin: EdgeInsets.symmetric(horizontal: spacing),
          width: dotSize,
          height: dotSize,
          decoration: BoxDecoration(
            color: dotColor,
            shape: BoxShape.circle,
          ),
        )
            .animate(onPlay: (c) => c.repeat())
            .moveY(
              duration: 300.ms,
              delay: (i * 150).ms,
              begin: 0,
              end: -dotSize,
              curve: Curves.easeInOut,
            )
            .then()
            .moveY(
              duration: 300.ms,
              begin: -dotSize,
              end: 0,
              curve: Curves.easeInOut,
            ),
      ),
    );
  }
}
