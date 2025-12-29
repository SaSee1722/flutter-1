import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:gossip/core/theme/gossip_colors.dart';

class ToastUtils {
  static void showCustomToast(BuildContext context, String message,
      {bool isError = false}) {
    // ScaffoldMessenger.of(context).clearSnackBars();

    final snackBar = SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      padding: EdgeInsets.zero,
      // Move to top by using a large margin at the bottom or just positioning
      // SnackBar doesn't easily move to top in standard Flutter without a custom overlay,
      // but we can use alignment in the content and a top-aligned container.
      margin: EdgeInsets.only(
        bottom: MediaQuery.of(context).size.height -
            140, // Top margin hack for SnackBar
        left: 24,
        right: 24,
      ),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isError
                    ? Colors.red.withValues(alpha: 0.5)
                    : GossipColors.primary.withValues(alpha: 0.5),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isError ? Colors.red : GossipColors.primary)
                      .withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isError ? Colors.red : GossipColors.primary)
                        .withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isError ? Colors.redAccent : GossipColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isError ? 'GOSSIP ERROR' : 'GOSSIP SUCCESS',
                        style: TextStyle(
                          color: (isError
                              ? Colors.redAccent
                              : GossipColors.primary),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      duration: const Duration(seconds: 4),
    );

    ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  static void showSuccess(BuildContext context, String message) {
    showCustomToast(context, message, isError: false);
  }

  static void showInfo(BuildContext context, String message) {
    showCustomToast(context, message, isError: false);
  }

  static void showError(BuildContext context, String message) {
    showCustomToast(context, message, isError: true);
  }
}
