import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_bloc.dart';
import 'package:gossip/features/vibes/presentation/bloc/vibe_event.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import 'package:flutter/foundation.dart';

class VibePreviewScreen extends StatefulWidget {
  final XFile file;

  const VibePreviewScreen({super.key, required this.file});

  @override
  State<VibePreviewScreen> createState() => _VibePreviewScreenState();
}

class _VibePreviewScreenState extends State<VibePreviewScreen> {
  final TextEditingController _captionController = TextEditingController();
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final bytes = await widget.file.readAsBytes();
      if (mounted) {
        setState(() {
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('Error loading image bytes: $e');
    }
  }

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  void _postVibe() {
    context.read<VibeBloc>().add(
          UploadVibe(
            widget.file,
            caption: _captionController.text,
          ),
        );
    // Navigate back immediately, the bloc listener on the main screen will handle success/failure feedback if needed
    // Or we could wait here. For now, let's close the preview.
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Image Preview
          Positioned.fill(
            child: _imageBytes != null
                ? Image.memory(
                    _imageBytes!,
                    fit: BoxFit.contain,
                  )
                : const Center(
                    child:
                        CircularProgressIndicator(color: GossipColors.primary)),
          ),

          // Overlay Gradient
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.3),
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),

          // Top Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    GradientText(
                      'NEW VIBE',
                      gradient: GossipColors.primaryGradient,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(width: 48), // Balance close button
                  ],
                ),
              ),
            ),
          ),

          // Bottom Bar (Caption & Send)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: TextField(
                        controller: _captionController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Add a caption...',
                          hintStyle: TextStyle(color: Colors.white38),
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: _postVibe,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(
                        color: GossipColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded,
                          color: Colors.white, size: 24),
                    ),
                  ).animate().scale(delay: 200.ms),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
