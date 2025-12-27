import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import '../../../../core/theme/gossip_colors.dart';

class CallsScreen extends StatelessWidget {
  const CallsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context)
                .animate()
                .fadeIn(duration: 600.ms)
                .slideY(begin: -0.2, end: 0),
            _buildDateHeader('21/12/2025')
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildCallsSection()
                        .animate()
                        .fadeIn(delay: 400.ms, duration: 600.ms)
                        .slideY(begin: 0.1, end: 0),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  GradientText(
                    'CALLS.',
                    gradient: GossipColors.primaryGradient,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/images/calls_header.png',
                    height: 40,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => _showSelectContact(context),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: GossipColors.primaryGradient.colors
                          .map((c) => c.withValues(alpha: 0.2))
                          .toList(),
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.add_rounded,
                      color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Stay connected with voice & video.',
            style: TextStyle(color: GossipColors.textDim, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        children: [
          Text(
            date,
            style: const TextStyle(
                color: GossipColors.textDim,
                fontSize: 10,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  void _showSelectContact(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _SelectContactSheet(),
    );
  }

  Widget _buildCallsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GossipColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'No recent calls.',
            style: TextStyle(color: GossipColors.textDim),
          ),
        ),
      ),
    );
  }
}

class _SelectContactSheet extends StatelessWidget {
  final List<Map<String, String>> _contacts = [
    {'id': '1', 'name': 'Sakthi Shree'},
    {'id': '2', 'name': 'Alice'},
    {'id': '3', 'name': 'Bob'},
    {'id': '4', 'name': 'Diana'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: GossipColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientText(
            'SELECT CONTACT.',
            gradient: GossipColors.primaryGradient,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _contacts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final contact = _contacts[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: Colors.white12,
                    child: Text(contact['name']![0]),
                  ),
                  title: Text(contact['name']!,
                      style: const TextStyle(color: Colors.white)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'Starting Audio Call with ${contact['name']}')));
                        },
                        icon:
                            const Icon(Icons.call, color: GossipColors.primary),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text(
                                  'Starting Video Call with ${contact['name']}')));
                        },
                        icon: const Icon(Icons.videocam,
                            color: GossipColors.secondary),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
