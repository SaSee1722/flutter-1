import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/repositories/chat_repository.dart';
import '../../domain/entities/message.dart';
import 'chat_event.dart';
import 'chat_state.dart';

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  final ChatRepository _chatRepository;
  StreamSubscription? _roomsSubscription;
  StreamSubscription? _messagesSubscription;

  ChatBloc(this._chatRepository) : super(const ChatState()) {
    on<LoadRooms>(_onLoadRooms);
    on<LoadMessages>(_onLoadMessages);
    on<SendMessageRequested>(_onSendMessageRequested);
    on<MessagesUpdated>(_onMessagesUpdated);
    on<RoomsUpdated>(_onRoomsUpdated);
  }

  Future<void> _onLoadRooms(
    LoadRooms event,
    Emitter<ChatState> emit,
  ) async {
    if (_roomsSubscription != null) return; // Keep the same subscription

    emit(state.copyWith(isLoadingRooms: true));

    _roomsSubscription = _chatRepository.getRooms().listen(
      (rooms) {
        add(RoomsUpdated(rooms));
      },
      onError: (error) {
        add(RoomsUpdated([]));
      },
    );
  }

  Future<void> _onLoadMessages(
    LoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isLoadingMessages: true, messages: []));
    await _messagesSubscription?.cancel();

    _messagesSubscription =
        _chatRepository.getMessages(event.roomId).listen((messages) {
      add(MessagesUpdated(messages));
    });
  }

  Future<void> _onSendMessageRequested(
    SendMessageRequested event,
    Emitter<ChatState> emit,
  ) async {
    // Optimistic Update: Add the message to the list immediately
    final updatedMessages = List<Message>.from(state.messages)
      ..insert(0, event.message);
    emit(state.copyWith(messages: updatedMessages));

    // Artificial delay to ensure "Sending..." animation is visible
    // This addresses the issue where 1:1 chats update too fast to see the animation
    await Future.delayed(const Duration(milliseconds: 1000));

    try {
      await _chatRepository.sendMessage(event.message);
    } catch (e) {
      emit(state.copyWith(error: e.toString()));
    }
  }

  void _onMessagesUpdated(
    MessagesUpdated event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(
      messages: event.messages,
      isLoadingMessages: false,
    ));

    // Logic for 'Delivered' status
    for (final message in event.messages) {
      if (message.status == MessageStatus.sent &&
          message.userId != _chatRepository.currentUser?.id) {
        _chatRepository.markAsDelivered(message.id);
      }
    }
  }

  void _onRoomsUpdated(
    RoomsUpdated event,
    Emitter<ChatState> emit,
  ) {
    emit(state.copyWith(
      rooms: event.rooms,
      isLoadingRooms: false,
    ));
  }

  @override
  Future<void> close() {
    _roomsSubscription?.cancel();
    _messagesSubscription?.cancel();
    return super.close();
  }
}
