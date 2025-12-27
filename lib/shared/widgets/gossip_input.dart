import 'package:flutter/material.dart';
import '../../core/theme/gossip_colors.dart';

class GossipInputField extends StatelessWidget {
  final String hintText;
  final TextEditingController controller;
  final bool isPassword;
  final TextInputType keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;

  const GossipInputField({
    super.key,
    required this.hintText,
    required this.controller,
    this.isPassword = false,
    this.keyboardType = TextInputType.text,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161616),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: GossipColors.textMain, fontSize: 13),
        cursorColor: GossipColors.primary,
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(
              color: GossipColors.textDim.withValues(alpha: 0.5),
              fontSize: 13,
              fontWeight: FontWeight.w500),
          prefixIcon: prefixIcon != null
              ? IconTheme(
                  data: IconThemeData(
                      color: GossipColors.textDim.withValues(alpha: 0.5),
                      size: 18),
                  child: prefixIcon!,
                )
              : null,
          suffixIcon: suffixIcon != null
              ? IconTheme(
                  data: const IconThemeData(color: GossipColors.textDim),
                  child: suffixIcon!,
                )
              : null,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          isDense: true,
        ),
      ),
    );
  }
}
