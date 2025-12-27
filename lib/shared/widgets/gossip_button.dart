import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/gossip_colors.dart';

class GossipButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool useGradient;
  final double? width;

  const GossipButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.useGradient = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              onPressed();
            },
      child: Container(
        width: width ?? double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: useGradient ? GossipColors.primaryGradient : null,
          color: useGradient ? null : GossipColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            if (useGradient)
              BoxShadow(
                color: GossipColors.primary.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        alignment: Alignment.center,
        child: isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
