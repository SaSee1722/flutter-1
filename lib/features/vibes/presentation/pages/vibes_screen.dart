import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/user_status.dart';
import '../../../../core/theme/gossip_colors.dart';
import '../../../../shared/widgets/glass_card.dart';

class VibesScreen extends StatefulWidget {
  const VibesScreen({super.key});

  @override
  State<VibesScreen> createState() => _VibesScreenState();
}

class _VibesScreenState extends State<VibesScreen> {
  final List<UserStatus> _mockStatuses = [
    UserStatus(
      id: '1',
      userId: 'u1',
      username: 'Alice',
      mediaUrl: 'https://picsum.photos/seed/a/400/800',
      isVideo: false,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 24)),
    ),
    UserStatus(
      id: '2',
      userId: 'u2',
      username: 'Bob',
      mediaUrl: 'https://picsum.photos/seed/b/400/800',
      isVideo: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      expiresAt: DateTime.now().add(const Duration(hours: 22)),
    ),
  ];

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: GossipColors.cardBackground,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.white),
              title:
                  const Text('Camera', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.white),
              title:
                  const Text('Gallery', style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      final media = await picker.pickImage(source: source);
      if (media != null) {
        // Handle upload here
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      body: CustomScrollView(
        slivers: [
          const SliverAppBar(
            floating: true,
            pinned: true,
            backgroundColor: GossipColors.background,
            title: Text('VIBES', style: TextStyle(fontWeight: FontWeight.bold)),
          ),

          // My Status
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('My Vibe',
                      style: TextStyle(
                          color: GossipColors.textDim,
                          fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: _pickMedia,
                    child: GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor:
                                    GossipColors.primary.withValues(alpha: 0.2),
                                child: const Icon(Icons.person,
                                    color: GossipColors.primary),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  decoration: const BoxDecoration(
                                      color: GossipColors.primary,
                                      shape: BoxShape.circle),
                                  child: const Icon(Icons.add,
                                      size: 20, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 16),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add a Vibe',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                              Text('Share a moment for 24 hours',
                                  style: TextStyle(
                                      color: GossipColors.textDim,
                                      fontSize: 13)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recent Statuses
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: const Text('Recent Vibes',
                  style: TextStyle(
                      color: GossipColors.textDim,
                      fontWeight: FontWeight.bold)),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.75,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final status = _mockStatuses[index];
                  return _VibeCard(status: status);
                },
                childCount: _mockStatuses.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeCard extends StatelessWidget {
  final UserStatus status;

  const _VibeCard({required this.status});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {}, // View status logic
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Image.network(status.mediaUrl,
                fit: BoxFit.cover,
                height: double.infinity,
                width: double.infinity),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.6),
                    Colors.transparent
                  ],
                ),
              ),
            ),
            Positioned(
              bottom: 12,
              left: 12,
              child: Text(
                status.username ?? 'Unknown',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
