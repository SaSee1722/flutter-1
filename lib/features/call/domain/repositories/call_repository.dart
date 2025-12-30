import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CallRepository {
  Future<String> makeCall({
    String? receiverId,
    String? roomId,
    required bool isVideo,
    required RTCSessionDescription offer,
    String? callerName,
    String? callerAvatar,
    DateTime? startTime,
  });
  Future<void> answerCall(String callId, RTCSessionDescription answer);
  Future<void> rejectCall(String callId);
  Future<void> endCall(String callId, {int? duration});
  Future<void> updateCallVideoStatus(String callId, bool isVideo);
  Future<void> updateOffer(String callId, RTCSessionDescription offer);
  Future<void> addIceCandidate(
      String callId, RTCIceCandidate candidate, bool isCaller);
  Stream<List<Map<String, dynamic>>> onIncomingCalls(String userId);
  Stream<Map<String, dynamic>> onCallUpdate(String callId);
  Stream<List<Map<String, dynamic>>> onIceCandidates(String callId);
  Future<List<Map<String, dynamic>>> getCallHistory(String userId);
}

class SupabaseCallRepository implements CallRepository {
  final SupabaseClient _supabase;

  SupabaseCallRepository(this._supabase);

  @override
  Future<String> makeCall({
    String? receiverId,
    String? roomId,
    required bool isVideo,
    required RTCSessionDescription offer,
    String? callerName,
    String? callerAvatar,
    DateTime? startTime,
  }) async {
    try {
      final response = await _supabase
          .from('calls')
          .insert({
            'caller_id': _supabase.auth.currentUser!.id,
            'receiver_id': receiverId,
            'room_id': roomId,
            'offer': offer.toMap(),
            'status': 'ringing',
            'is_video': isVideo,
            'caller_name': callerName,
            'caller_avatar': callerAvatar,
            if (startTime != null)
              'created_at': startTime.toUtc().toIso8601String(),
          })
          .select('id')
          .single();
      return response['id'];
    } catch (e) {
      debugPrint('DEBUG: makeCall error: $e');
      rethrow;
    }
  }

  @override
  Future<void> answerCall(String callId, RTCSessionDescription answer) async {
    await _supabase.from('calls').update({
      'answer': answer.toMap(),
      'status': 'accepted',
    }).eq('id', callId);
  }

  @override
  Future<void> rejectCall(String callId) async {
    await _supabase.from('calls').update({
      'status': 'rejected',
    }).eq('id', callId);
  }

  @override
  Future<void> endCall(String callId, {int? duration}) async {
    await _supabase.from('calls').update({
      'status': 'ended',
      'ended_at': DateTime.now().toUtc().toIso8601String(),
      if (duration != null) 'duration': duration,
    }).eq('id', callId);
  }

  @override
  Future<void> updateCallVideoStatus(String callId, bool isVideo) async {
    await _supabase.from('calls').update({
      'is_video': isVideo,
    }).eq('id', callId);
  }

  @override
  Future<void> updateOffer(String callId, RTCSessionDescription offer) async {
    await _supabase.from('calls').update({
      'offer': offer.toMap(),
    }).eq('id', callId);
  }

  @override
  Future<void> addIceCandidate(
      String callId, RTCIceCandidate candidate, bool isCaller) async {
    await _supabase.from('ice_candidates').insert({
      'call_id': callId,
      'candidate': candidate.toMap(),
      'is_caller': isCaller,
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> onIncomingCalls(String userId) {
    // Listen to all calls I have access to (RLS handles filtering)
    return _supabase.from('calls').stream(primaryKey: ['id']).map((data) => data
        .where((item) =>
            item['status'] == 'ringing' && item['caller_id'] != userId)
        .toList());
  }

  @override
  Stream<Map<String, dynamic>> onCallUpdate(String callId) {
    return _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('id', callId)
        .map((data) => data.isNotEmpty ? data.first : {});
  }

  @override
  Stream<List<Map<String, dynamic>>> onIceCandidates(String callId) {
    return _supabase
        .from('ice_candidates')
        .stream(primaryKey: ['id']).eq('call_id', callId);
  }

  @override
  Future<List<Map<String, dynamic>>> getCallHistory(String userId) async {
    try {
      final response = await _supabase
          .from('calls')
          .select(
              '*, caller_profile:profiles!calls_caller_id_fkey(username, avatar_url), receiver_profile:profiles!calls_receiver_id_fkey(username, avatar_url), chat_rooms(name, avatar_url)')
          .or('caller_id.eq.$userId,receiver_id.eq.$userId,room_id.not.is.null') // Direct calls OR any group call I have RLS access to
          .order('created_at', ascending: false)
          .limit(50);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('ERROR: getCallHistory failed: $e');
      return [];
    }
  }
}
