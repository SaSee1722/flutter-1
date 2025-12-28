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
      margin: const EdgeInsets.fromLTRB(24, 0, 24, 40),
      content: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isError
                    ? Colors.red.withValues(alpha: 0.3)
                    : GossipColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isError ? Colors.red : GossipColors.primary)
                      .withValues(alpha: 0.1),
                  blurRadius: 10,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: (isError ? Colors.red : GossipColors.primary)
                        .withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.info_outline_rounded,
                    color: isError ? Colors.redAccent : GossipColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      duration: const Duration(seconds: 3),
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
