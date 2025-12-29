import 'package:flutter/material.dart';
import 'package:gossip/core/theme/gossip_colors.dart';
import 'package:gossip/features/chat/presentation/pages/chat_list_screen.dart';
import 'package:gossip/features/chat/presentation/pages/groups_screen.dart';
import 'package:gossip/features/chat/presentation/pages/calls_screen.dart';
import 'settings_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_bloc.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_event.dart';
import 'package:gossip/features/chat/presentation/bloc/chat_state.dart';
import 'package:gossip/features/chat/domain/repositories/chat_repository.dart';
import 'package:gossip/core/di/injection_container.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const ChatListScreen(),
    const GroupsScreen(),
    const CallsScreen(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure rooms are loaded for badges
    context.read<ChatBloc>().add(LoadRooms());
    // Initial online status
    sl<ChatRepository>().setOnlineStatus(true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    sl<ChatRepository>().setOnlineStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      sl<ChatRepository>().setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      sl<ChatRepository>().setOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GossipColors.background,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: _pages,
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 24,
            child: BlocBuilder<ChatBloc, ChatState>(
              builder: (context, state) {
                final chatBadge = state.rooms
                    .where((r) => !r.isGroup)
                    .fold(0, (sum, r) => sum + r.unreadCount);
                final groupBadge = state.rooms
                    .where((r) => r.isGroup)
                    .fold(0, (sum, r) => sum + r.unreadCount);

                return _FloatingNavBar(
                  selectedIndex: _selectedIndex,
                  chatBadge: chatBadge,
                  groupBadge: groupBadge,
                  onItemSelected: (index) =>
                      setState(() => _selectedIndex = index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _FloatingNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;
  final int chatBadge;
  final int groupBadge;

  const _FloatingNavBar({
    required this.selectedIndex,
    required this.onItemSelected,
    this.chatBadge = 0,
    this.groupBadge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        height: 64,
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D).withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(color: Colors.white12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _NavBarItem(
              icon: Icons.chat_bubble_rounded,
              isSelected: selectedIndex == 0,
              badgeCount: chatBadge,
              onTap: () => onItemSelected(0),
            ),
            _NavBarItem(
              icon: Icons.groups_rounded,
              isSelected: selectedIndex == 1,
              badgeCount: groupBadge,
              onTap: () => onItemSelected(1),
            ),
            _NavBarItem(
              icon: Icons.call_rounded,
              isSelected: selectedIndex == 2,
              onTap: () => onItemSelected(2),
            ),
            _NavBarItem(
              icon: Icons.person_rounded,
              isSelected: selectedIndex == 3,
              isProfile: true,
              onTap: () => onItemSelected(3),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final int badgeCount;
  final bool isProfile;

  const _NavBarItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.badgeCount = 0,
    this.isProfile = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        color: Colors.transparent,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? GossipColors.primary : GossipColors.textDim,
              size: 26,
            ),
            if (badgeCount > 0)
              Positioned(
                top: 10,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: GossipColors.secondary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    badgeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (isSelected)
              Positioned(
                bottom: 8,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: GossipColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
