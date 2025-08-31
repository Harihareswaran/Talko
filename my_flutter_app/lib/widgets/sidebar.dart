import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:chatbot_app/providers/chat_provider.dart';
import 'package:chatbot_app/models/conversation.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

class Sidebar extends ConsumerWidget {
  const Sidebar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: Colors.grey),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Chat History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final userId = FirebaseAuth.instance.currentUser?.uid;
                    if (userId != null) {
                      final newChatId = await ref.read(chatServiceProvider).createNewChat(userId);
                      ref.read(currentChatIdProvider.notifier).state = newChatId;
                      if (context.mounted) {
                        Navigator.pop(context);
                      }
                    } else {
                      print('No authenticated user for new chat'); // Debug log
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please sign in to create a new chat')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 40),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                  ),
                  child: const Text('New Chat'),
                ),
              ],
            ),
          ),
          Expanded(
            child: conversations.when(
              data: (convs) {
                print('Sidebar: Rendering ${convs.length} conversations'); // Debug log
                if (convs.isEmpty) {
                  return const Center(child: Text('No conversations found'));
                }
                final groupedConvs = _groupConversationsByDate(convs);
                return ListView.builder(
                  itemCount: groupedConvs.length,
                  itemBuilder: (context, index) {
                    final group = groupedConvs.entries.elementAt(index);
                    return ExpansionTile(
                      title: Text(group.key),
                      children: group.value.map((conv) => ListTile(
                            title: Text(conv.title),
                            subtitle: Text(DateFormat('MMM dd, yyyy').format(conv.createdAt)),
                            onTap: () {
                              ref.read(currentChatIdProvider.notifier).state = conv.id;
                              if (context.mounted) {
                                Navigator.pop(context);
                              }
                            },
                          )).toList(),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                print('Sidebar: Error loading conversations: $e'); // Debug log
                return Center(child: Text('Error: $e'));
              },
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Conversation>> _groupConversationsByDate(List<Conversation> convs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final grouped = {
      'Today': <Conversation>[],
      'Yesterday': <Conversation>[],
      'This Week': <Conversation>[],
      'Older': <Conversation>[],
    };

    for (var conv in convs) {
      final convDate = DateTime(conv.createdAt.year, conv.createdAt.month, conv.createdAt.day);
      if (convDate == today) {
        grouped['Today']!.add(conv);
      } else if (convDate == yesterday) {
        grouped['Yesterday']!.add(conv);
      } else if (convDate.isAfter(weekAgo)) {
        grouped['This Week']!.add(conv);
      } else {
        grouped['Older']!.add(conv);
      }
    }

    return grouped..removeWhere((key, value) => value.isEmpty);
  }
}