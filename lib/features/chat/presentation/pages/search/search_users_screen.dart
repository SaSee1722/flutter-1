import 'package:flutter/material.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:gossip/core/di/injection_container.dart';

class SearchUsersScreen extends StatefulWidget {
  const SearchUsersScreen({super.key});

  @override
  State<SearchUsersScreen> createState() => _SearchUsersScreenState();
}

class _SearchUsersScreenState extends State<SearchUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ChatRepository _chatRepository = sl<ChatRepository>(); // Use DI
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    // Debounce optimization could be added here
    _performSearch(query);
  }

  Future<void> _performSearch(String query) async {
    setState(() => _isLoading = true);
    try {
      final results = await _chatRepository.searchUsers(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      await _chatRepository.sendFriendRequest(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: GossipColors.cardBackground,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        onChanged: _onSearchChanged,
                        decoration: const InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(color: GossipColors.textDim),
                          border: InputBorder.none,
                          prefixIcon:
                              Icon(Icons.search, color: GossipColors.textDim),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_isLoading)
              const LinearProgressIndicator(color: GossipColors.primary),
            Expanded(
              child: _searchResults.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_search,
                              size: 64, color: Colors.white12),
                          const SizedBox(height: 16),
                          Text(
                            _searchController.text.isEmpty
                                ? 'Type to search users'
                                : 'No users found',
                            style: const TextStyle(color: GossipColors.textDim),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _searchResults.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          tileColor: GossipColors.cardBackground,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          leading: CircleAvatar(
                            backgroundImage: NetworkImage(user['avatar_url'] ??
                                'https://picsum.photos/seed/${user['username']}/100'),
                          ),
                          title: Text(
                            user['username'] ?? 'Unknown',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.person_add,
                                color: GossipColors.primary),
                            onPressed: () => _sendFriendRequest(user['id']),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
