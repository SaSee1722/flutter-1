import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

abstract class CallRepository {
  Future<void> makeCall(String receiverId, RTCSessionDescription offer);
  Future<void> answerCall(String callId, RTCSessionDescription answer);
  Future<void> addIceCandidate(String callId, RTCIceCandidate candidate, bool isCaller);
  Stream<Map<String, dynamic>> onCallUpdate(String userId);
  Stream<List<Map<String, dynamic>>> onIceCandidates(String callId);
}

class SupabaseCallRepository implements CallRepository {
  final SupabaseClient _supabase;

  SupabaseCallRepository(this._supabase);

  @override
  Future<void> makeCall(String receiverId, RTCSessionDescription offer) async {
    await _supabase.from('calls').insert({
      'caller_id': _supabase.auth.currentUser!.id,
      'receiver_id': receiverId,
      'offer': offer.toMap(),
      'status': 'ringing',
    });
  }

  @override
  Future<void> answerCall(String callId, RTCSessionDescription answer) async {
    await _supabase.from('calls').update({
      'answer': answer.toMap(),
      'status': 'accepted',
    }).eq('id', callId);
  }

  @override
  Future<void> addIceCandidate(String callId, RTCIceCandidate candidate, bool isCaller) async {
    await _supabase.from('ice_candidates').insert({
      'call_id': callId,
      'candidate': candidate.toMap(),
      'is_caller': isCaller,
    });
  }

  @override
  Stream<Map<String, dynamic>> onCallUpdate(String userId) {
    return _supabase
        .from('calls')
        .stream(primaryKey: ['id'])
        .eq('receiver_id', userId)
        .map((data) => data.isNotEmpty ? data.first : {});
  }

  @override
  Stream<List<Map<String, dynamic>>> onIceCandidates(String callId) {
    return _supabase
        .from('ice_candidates')
        .stream(primaryKey: ['id'])
        .eq('call_id', callId);
  }
}
