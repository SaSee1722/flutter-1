import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:gossip/shared/widgets/gradient_text.dart';
import '../../../../core/theme/gossip_colors.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gossip/features/call/presentation/bloc/call_bloc.dart';
import 'package:gossip/features/call/presentation/bloc/call_event.dart';
import 'package:gossip/features/call/presentation/bloc/call_state.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../../../core/di/injection_container.dart';
import '../../../call/domain/repositories/call_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

class CallsScreen extends StatefulWidget {
  const CallsScreen({super.key});

  @override
  State<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends State<CallsScreen> {
  late String _currentUserId;
  RealtimeChannel? _callsChannel;

  @override
  void initState() {
    super.initState();
    _currentUserId = sl<ChatRepository>().currentUser!.id;
    _setupRealtimeListener();
  }

  void _setupRealtimeListener() {
    _callsChannel?.unsubscribe();

    // 1. Realtime Attempt
    _callsChannel = sl<SupabaseClient>().channel('calls_realtime_updates');
    _callsChannel!
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'calls',
          callback: (payload) {
            if (mounted) setState(() {});
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _callsChannel?.unsubscribe();
    super.dispose();
  }

  DateTime _parseTimestamp(dynamic timestamp) {
    if (timestamp == null) return DateTime.now();
    final str = timestamp.toString();
    // Parse UTC correctly
    DateTime dt = DateTime.parse(
        str.contains('Z') || str.contains('+') ? str : '${str}Z');

    // HEALING LOGIC: If the time is more than 30 mins in the future, it's a poisoned
    // timestamp from the previous bug. Correct it by subtracting the 5.5h offset.
    final now = DateTime.now().toUtc();
    if (dt.isAfter(now.add(const Duration(minutes: 30)))) {
      dt = dt.subtract(const Duration(hours: 5, minutes: 30));
    }
    return dt.toLocal();
  }

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
            _buildDateHeader('RECENT CALLS')
                .animate()
                .fadeIn(delay: 200.ms, duration: 600.ms),
            Expanded(
              child: BlocListener<CallBloc, CallState>(
                listener: (context, state) {
                  if (state is CallIdle) {
                    debugPrint('DEBUG: Call ended, refreshing history...');
                    setState(() {});
                  }
                },
                child: RefreshIndicator(
                  onRefresh: () async {
                    setState(() {});
                  },
                  color: GossipColors.primary,
                  child: _buildHistoryList(context, _currentUserId),
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

  Widget _buildHistoryList(BuildContext context, String currentUserId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      key: ValueKey(
          DateTime.now().millisecondsSinceEpoch), // Force re-fetch on rebuild
      future: sl<CallRepository>().getCallHistory(currentUserId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: Padding(
            padding: EdgeInsets.all(32.0),
            child: CircularProgressIndicator(),
          ));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
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

        final calls = snapshot.data!;

        // HEALING SORT: Sort based on our healed timestamps to ensure
        // that new calls are ALWAYS at the top, even if old poisoned
        // calls have "future" timestamps in the DB.
        calls.sort((a, b) => _parseTimestamp(b['created_at'])
            .compareTo(_parseTimestamp(a['created_at'])));

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: GossipColors.cardBackground,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: (calls.length > 20)
                ? 20
                : calls.length, // Limit to recent 20 for performance
            separatorBuilder: (_, __) =>
                Divider(color: Colors.white.withValues(alpha: 0.05)),
            itemBuilder: (context, index) {
              final call = calls[index];
              final isCaller = call['caller_id'] == currentUserId;
              final roomInfo = call['chat_rooms'];
              final isGroup = call['room_id'] != null && roomInfo != null;

              // Helper to safely extract username/avatar from join result
              Map<String, dynamic>? getProfile(dynamic data) {
                if (data == null) return null;
                if (data is Map<String, dynamic>) return data;
                if (data is List && data.isNotEmpty) {
                  return data.first as Map<String, dynamic>;
                }
                return null;
              }

              final callerP = getProfile(call['caller_profile']);
              final receiverP = getProfile(call['receiver_profile']);

              // DEFENSIVE IDENTITY: Always pick the profile that isn't the current user
              final otherProfile =
                  (call['caller_id'] == currentUserId) ? receiverP : callerP;

              final otherName = isGroup
                  ? (roomInfo['name'] ?? 'Group Call')
                  : (otherProfile?['username'] ??
                      (call['caller_id'] == currentUserId
                          ? 'Unknown Receiver'
                          : (call['caller_name'] ?? 'Unknown Caller')));

              final otherAvatar = isGroup
                  ? roomInfo['avatar_url']
                  : (otherProfile?['avatar_url'] ??
                      (call['caller_id'] == currentUserId
                          ? null
                          : call['caller_avatar']));

              final status = call['status'] as String;
              final createdAt = _parseTimestamp(call['created_at']);

              return ListTile(
                contentPadding: EdgeInsets.zero,
                onTap: () => _showCallDetails(context, call, isCaller),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: GossipColors.primary.withValues(alpha: 0.1),
                  backgroundImage:
                      otherAvatar != null ? NetworkImage(otherAvatar) : null,
                  child: otherAvatar == null
                      ? Text(
                          otherName[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        )
                      : null,
                ),
                title: Text(
                  otherName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Row(
                  children: [
                    Icon(
                      isCaller
                          ? Icons.call_made_rounded
                          : (status == 'missed' || status == 'rejected'
                              ? Icons.call_missed_rounded
                              : Icons.call_received_rounded),
                      size: 14,
                      color: isCaller
                          ? Colors.blueAccent
                          : (status == 'missed' || status == 'rejected'
                              ? Colors.redAccent
                              : Colors.greenAccent),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${isCaller ? "Called" : "Received"}${_formatDuration(call['duration'])} · ${DateFormat('h:mm a').format(createdAt)}',
                      style: const TextStyle(
                        color: GossipColors.textDim,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                trailing: IconButton(
                  onPressed: () {
                    context.read<CallBloc>().add(StartCall(
                          receiverId: isCaller
                              ? call['receiver_id']
                              : call['caller_id'],
                          name: otherName,
                          avatar: otherAvatar,
                          isVideo: call['is_video'] ?? false,
                        ));
                  },
                  icon: Icon(
                    call['is_video'] == true ? Icons.videocam : Icons.call,
                    color: GossipColors.primary.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  String _formatDuration(dynamic seconds, {bool detailed = false}) {
    if (seconds == null || (seconds is int && seconds == 0)) return "";
    int secs = 0;
    if (seconds is int) {
      secs = seconds;
    } else if (seconds is String) {
      secs = int.tryParse(seconds) ?? 0;
    }

    if (secs == 0) return "";

    final duration = Duration(seconds: secs);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final s = duration.inSeconds.remainder(60);

    if (detailed) {
      if (hours > 0) return "${hours}h ${minutes}m ${s}s";
      if (minutes > 0) return "${minutes}m ${s}s";
      return "${s}s";
    }

    if (hours > 0) {
      return " · ${hours}h ${minutes}m";
    } else if (minutes > 0) {
      return " · ${minutes}m ${s}s";
    } else {
      return " · ${s}s";
    }
  }

  void _showCallDetails(
      BuildContext context, Map<String, dynamic> call, bool isCaller) {
    final roomInfo = call['chat_rooms'];
    final isGroup = call['room_id'] != null && roomInfo != null;

    Map<String, dynamic>? getProfile(dynamic data) {
      if (data == null) return null;
      if (data is Map<String, dynamic>) return data;
      if (data is List && data.isNotEmpty) {
        return data.first as Map<String, dynamic>;
      }
      return null;
    }

    final callerP = getProfile(call['caller_profile']);
    final receiverP = getProfile(call['receiver_profile']);
    final currentUserId = sl<ChatRepository>().currentUser!.id;
    final otherProfile =
        (call['caller_id'] == currentUserId) ? receiverP : callerP;

    final otherName = isGroup
        ? (roomInfo['name'] ?? 'Group Call')
        : (otherProfile?['username'] ??
            (call['caller_id'] == currentUserId
                ? 'Unknown Receiver'
                : (call['caller_name'] ?? 'Unknown Caller')));

    final otherAvatar = isGroup
        ? roomInfo['avatar_url']
        : (otherProfile?['avatar_url'] ??
            (call['caller_id'] == currentUserId
                ? null
                : call['caller_avatar']));

    final createdAt = _parseTimestamp(call['created_at']);
    final durationSecs = call['duration'] as int? ?? 0;
    // Calculate endedAt based on duration to ensure they match perfectly
    final endedAt = createdAt.add(Duration(seconds: durationSecs));

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        decoration: const BoxDecoration(
          color: GossipColors.cardBackground,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      otherAvatar != null ? NetworkImage(otherAvatar) : null,
                  child: otherAvatar == null
                      ? Text(otherName[0].toUpperCase())
                      : null,
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      call['is_video'] == true ? 'Video Call' : 'Voice Call',
                      style: const TextStyle(color: GossipColors.textDim),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildInfoRow(Icons.call_made_rounded, 'Called at',
                DateFormat('h:mm a').format(createdAt), _formatDate(createdAt)),
            _buildInfoRow(Icons.call_end_rounded, 'Ended at',
                DateFormat('h:mm a').format(endedAt), _formatDate(endedAt)),
            _buildInfoRow(Icons.timer_outlined, 'Duration',
                _formatDuration(call['duration'] ?? 0, detailed: true), ''),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final d = DateTime(local.year, local.month, local.day);

    if (d == today) return "Today";
    if (d == yesterday) return "Yesterday";

    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];

    return "${weekdays[local.weekday - 1]}, ${local.day} ${months[local.month - 1]}";
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, String subValue) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: GossipColors.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: GossipColors.textDim, fontSize: 12)),
              Row(
                children: [
                  Text(value,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500)),
                  if (subValue.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(subValue,
                        style: const TextStyle(
                            color: GossipColors.textDim, fontSize: 13)),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectContactSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: GossipColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'New Call',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          FutureBuilder<List<dynamic>>(
            future: Future.wait([
              sl<ChatRepository>().getContacts(),
              sl<ChatRepository>().getRooms().first,
            ]),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No participants found',
                      style: TextStyle(color: GossipColors.textDim)),
                );
              }

              final contacts = snapshot.data![0] as List<Map<String, dynamic>>;
              final rooms = snapshot.data![1] as List<dynamic>;
              final groups = rooms.where((r) => r.isGroup == true).toList();

              final allParticipants = [
                ...contacts.map((c) => {...c, 'isGroup': false}),
                ...groups.map((g) => {
                      'id': g.id,
                      'username': g.name,
                      'avatar_url': g.avatarUrl,
                      'isGroup': true
                    }),
              ];

              if (allParticipants.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No contacts or groups found',
                      style: TextStyle(color: GossipColors.textDim)),
                );
              }

              return Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: allParticipants.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = allParticipants[index];
                    final isGroup = item['isGroup'] == true;

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor:
                            GossipColors.primary.withValues(alpha: 0.1),
                        backgroundImage: item['avatar_url'] != null
                            ? NetworkImage(item['avatar_url'])
                            : null,
                        child: item['avatar_url'] == null
                            ? Text(
                                (item['username']?[0] ?? '?').toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              )
                            : null,
                      ),
                      title: Row(
                        children: [
                          Text(
                            item['username'] ?? 'Unknown',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (isGroup) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    GossipColors.primary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'GROUP',
                                style: TextStyle(
                                  color: GossipColors.primary,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.read<CallBloc>().add(StartCall(
                                    receiverId: isGroup ? null : item['id'],
                                    roomId: isGroup ? item['id'] : null,
                                    name: item['username'] ?? 'Unknown',
                                    avatar: item['avatar_url'],
                                    isVideo: false,
                                  ));
                            },
                            icon: const Icon(Icons.call,
                                color: GossipColors.primary),
                          ),
                          IconButton(
                            onPressed: () {
                              Navigator.pop(context);
                              context.read<CallBloc>().add(StartCall(
                                    receiverId: isGroup ? null : item['id'],
                                    roomId: isGroup ? item['id'] : null,
                                    name: item['username'] ?? 'Unknown',
                                    avatar: item['avatar_url'],
                                    isVideo: true,
                                  ));
                            },
                            icon: const Icon(Icons.videocam,
                                color: GossipColors.secondary),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
