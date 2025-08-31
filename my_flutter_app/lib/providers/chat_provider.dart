import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbot_app/models/message.dart';
import 'package:chatbot_app/models/conversation.dart';
import 'package:chatbot_app/services/chat_service.dart';

final chatServiceProvider = Provider<ChatService>((ref) => ChatService());

final currentChatIdProvider = StateProvider<String?>((ref) => null);

final messagesProvider = StreamProvider.family<List<Message>, String>((ref, chatId) {
  return ref.watch(chatServiceProvider).getMessages(chatId);
});

final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  return ref.watch(chatServiceProvider).getConversations();
});

final typingProvider = StateProvider<bool>((ref) => false);