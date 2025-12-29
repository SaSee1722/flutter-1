import 'package:flutter/material.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';

class StickerPickerSheet extends StatefulWidget {
  final Function(String url, String type) onStickerSelected;

  const StickerPickerSheet({super.key, required this.onStickerSelected});

  @override
  State<StickerPickerSheet> createState() => _StickerPickerSheetState();
}

class _StickerPickerSheetState extends State<StickerPickerSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ImagePicker _picker = ImagePicker();
  List<FileObject> _stickers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStickers();
  }

  Future<void> _fetchStickers() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final List<FileObject> files = await Supabase.instance.client.storage
          .from('chat-media')
          .list(path: '$userId/stickers');

      if (mounted) {
        setState(() {
          _stickers =
              files.where((f) => f.name != '.emptyFolderPlaceholder').toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadSticker() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final bytes = await image.readAsBytes();
      final fileExt = image.path.split('.').last;
      final fileName =
          'sticker_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = '$userId/stickers/$fileName';

      await Supabase.instance.client.storage
          .from('chat-media')
          .uploadBinary(filePath, bytes);

      _fetchStickers();
    } catch (e) {
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GossipColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          TabBar(
            controller: _tabController,
            indicatorColor: GossipColors.primary,
            labelColor: GossipColors.primary,
            unselectedLabelColor: GossipColors.textDim,
            tabs: const [
              Tab(text: "My Stickers"),
              Tab(text: "GIFs"),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildStickersGrid(),
                _buildGifsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStickersGrid() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton.icon(
            onPressed: _uploadSticker,
            icon: const Icon(Icons.add),
            label: const Text("Create New Sticker"),
            style: ElevatedButton.styleFrom(
              backgroundColor: GossipColors.primary.withValues(alpha: 0.2),
              foregroundColor: GossipColors.primary,
            ),
          ),
        ),
        Expanded(
          child: _stickers.isEmpty
              ? const Center(
                  child: Text("No stickers yet",
                      style: TextStyle(color: Colors.white54)))
              : GridView.builder(
                  padding: const EdgeInsets.all(8),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _stickers.length,
                  itemBuilder: (context, index) {
                    final file = _stickers[index];
                    final userId =
                        Supabase.instance.client.auth.currentUser?.id;
                    final publicUrl = Supabase.instance.client.storage
                        .from('chat-media')
                        .getPublicUrl('$userId/stickers/${file.name}');

                    return GestureDetector(
                      onTap: () =>
                          widget.onStickerSelected(publicUrl, 'sticker'),
                      child: CachedNetworkImage(
                        imageUrl: publicUrl,
                        fit: BoxFit.contain,
                        placeholder: (_, __) =>
                            Container(color: Colors.white10),
                      ).animate().scale(),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildGifsTab() {
    // Placeholder for Giphy or similar
    // Since we don't have API keys, we'll allow uploading GIFs similar to stickers?
    // Or just show a message.
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.gif, size: 48, color: Colors.white54),
          const SizedBox(height: 8),
          const Text(
            "Upload Custom GIFs",
            style: TextStyle(color: Colors.white54),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: ElevatedButton.icon(
              onPressed: () async {
                // Reuse upload logic but maybe mark as GIF
                _uploadSticker(); // For now same bucket
              },
              icon: const Icon(Icons.upload),
              label: const Text("Upload GIF"),
              style: ElevatedButton.styleFrom(
                backgroundColor: GossipColors.primary.withValues(alpha: 0.2),
                foregroundColor: GossipColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
