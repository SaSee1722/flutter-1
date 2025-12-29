import 'package:equatable/equatable.dart';
import '../../domain/entities/message.dart';
import '../../domain/entities/chat_room.dart';

abstract class ChatEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadRooms extends ChatEvent {}

class RoomsUpdated extends ChatEvent {
  final List<ChatRoom> rooms;
  RoomsUpdated(this.rooms);

  @override
  List<Object?> get props => [rooms];
}

class LoadMessages extends ChatEvent {
  final String roomId;
  LoadMessages(this.roomId);

  @override
  List<Object?> get props => [roomId];
}

class SendMessageRequested extends ChatEvent {
  final Message message;
  SendMessageRequested(this.message);

  @override
  List<Object?> get props => [message];
}

class MessagesUpdated extends ChatEvent {
  final List<Message> messages;
  MessagesUpdated(this.messages);

  @override
  List<Object?> get props => [messages];
}

class UpdateReactionRequest extends ChatEvent {
  final String messageId;
  final String? reaction; // null to remove

  UpdateReactionRequest({required this.messageId, this.reaction});

  @override
  List<Object?> get props => [messageId, reaction];
}
