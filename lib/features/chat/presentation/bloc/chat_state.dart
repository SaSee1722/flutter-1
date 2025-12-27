import 'package:equatable/equatable.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_room.dart';

class ChatState extends Equatable {
  final List<ChatRoom> rooms;
  final List<Message> messages;
  final bool isLoadingRooms;
  final bool isLoadingMessages;
  final String? error;

  const ChatState({
    this.rooms = const [],
    this.messages = const [],
    this.isLoadingRooms = false,
    this.isLoadingMessages = false,
    this.error,
  });

  ChatState copyWith({
    List<ChatRoom>? rooms,
    List<Message>? messages,
    bool? isLoadingRooms,
    bool? isLoadingMessages,
    String? error,
  }) {
    return ChatState(
      rooms: rooms ?? this.rooms,
      messages: messages ?? this.messages,
      isLoadingRooms: isLoadingRooms ?? this.isLoadingRooms,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        rooms,
        messages,
        isLoadingRooms,
        isLoadingMessages,
        error,
      ];
}
