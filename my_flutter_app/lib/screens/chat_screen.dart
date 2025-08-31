import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // For HapticFeedback
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:chatbot_app/models/message.dart';
import 'package:chatbot_app/providers/auth_provider.dart';
import 'package:chatbot_app/providers/chat_provider.dart';
import 'package:chatbot_app/widgets/message_bubble.dart';
import 'package:chatbot_app/widgets/sidebar.dart';
import 'package:uuid/uuid.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ChatScreenState createState() => ChatScreenState();
}

class ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _uuid = const Uuid();
  String _streamingBotText = "";
  bool _isStreaming = false;
  Timer? _typingTimer;
  final List<Map<String, dynamic>> _messageQueue = []; // Queue for pending messages
  bool _isProcessing = false;
  bool _isConnected = true; // Track network status
  bool _hasShownNetworkPopup = false; // Track if popup has been shown
  StreamSubscription? _connectivitySubscription; // Subscription for connectivity

  @override
  void initState() {
    super.initState();
    _checkConnectivity(); // Initial connectivity check
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final chatId = ref.read(currentChatIdProvider);
      final user = ref.read(authStateProvider).value;
      if (chatId == null && user != null && mounted) {
        final newChatId =
            await ref.read(chatServiceProvider).createNewChat(user.uid);
        if (mounted) {
          ref.read(currentChatIdProvider.notifier).state = newChatId;
          // Scroll to bottom after creating a new chat
          _scrollToBottom();
        }
      }
    });
    // Listen to connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (mounted) {
        setState(() {
          _isConnected = result != ConnectivityResult.none;
        });
        if (!_isConnected && !_hasShownNetworkPopup) {
          _showNetworkPopup();
        }
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _typingTimer?.cancel();
    _connectivitySubscription?.cancel(); // Cancel connectivity subscription
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients && mounted) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        _isConnected = connectivityResult != ConnectivityResult.none;
      });
    }
  }

  Future<void> _showNetworkPopup() async {
    if (!_hasShownNetworkPopup && mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Network Required'),
            content: const Text('A network connection is needed to chat. Please connect to the internet.'),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (mounted) {
                    setState(() {
                      _hasShownNetworkPopup = true;
                    });
                  }
                },
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _sendMessage(String? chatId, String userId) async {
    if (!_isConnected) {
      _showNetworkPopup();
      return;
    }

    if (_messageController.text.isEmpty) return;

    // Add message to queue
    _messageQueue.add({
      'chatId': chatId,
      'userId': userId,
      'text': _messageController.text,
    });
    if (mounted) {
      _messageController.clear();
      _processQueue();
    }
  }

  Future<void> _processQueue() async {
    if (_isProcessing || _messageQueue.isEmpty || !mounted) return;

    setState(() => _isProcessing = true);

    final messageData = _messageQueue.removeAt(0);
    String validChatId = messageData['chatId'] ?? '';
    final userId = messageData['userId'];
    final text = messageData['text'];

    if (validChatId.isEmpty) {
      validChatId = await ref.read(chatServiceProvider).createNewChat(userId);
      if (mounted) {
        ref.read(currentChatIdProvider.notifier).state = validChatId;
      }
    }

    final userMessage = Message(
      id: _uuid.v4(),
      text: text,
      isUser: true,
      timestamp: DateTime.now(),
      userId: userId,
      chatId: validChatId,
    );

    // Save user message
    await ref.read(chatServiceProvider).saveMessage(userMessage);

    // Scroll to bottom after user message
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _scrollToBottom();
        }
      });
    }

    setState(() {
      _isStreaming = true;
      _streamingBotText = "";
    });

    final botResponse =
        await ref.read(chatServiceProvider).getBotResponse(userMessage.text);

    _typingTimer?.cancel();
    final words = botResponse.split(" ");
    int index = 0;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (index < words.length) {
        setState(() {
          _streamingBotText += (index == 0 ? "" : " ") + words[index];
          index++;
          _scrollToBottom();
        });
      } else {
        timer.cancel();
        _typingTimer = null;

        final botMessage = Message(
          id: _uuid.v4(),
          text: botResponse,
          isUser: false,
          timestamp: DateTime.now(),
          userId: userId,
          chatId: validChatId,
        );
        ref.read(chatServiceProvider).saveMessage(botMessage);

        if (mounted) {
          setState(() {
            _isStreaming = false;
            _streamingBotText = "";
          });

          // Scroll to bottom after bot message
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _scrollToBottom();
            }
          });

          setState(() => _isProcessing = false);
          _processQueue(); // Process next message in queue
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final chatId = ref.watch(currentChatIdProvider);
    final messages = ref.watch(messagesProvider(chatId ?? ''));

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Talko',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.grey[800],
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => ref.read(authServiceProvider).signOut(),
          ),
        ],
      ),
      drawer: const Sidebar(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: messages.when(
                data: (msgs) {
                  // Create a list of messages to display
                  final displayMessages = List<Message>.from(msgs);
                  // Add streaming bot message only if streaming is active
                  if (_isStreaming && user != null && chatId != null && mounted) {
                    displayMessages.add(Message(
                      id: 'temp',
                      text: _streamingBotText,
                      isUser: false,
                      timestamp: DateTime.now(),
                      userId: user.uid,
                      chatId: chatId,
                    ));
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(12),
                    itemCount: displayMessages.length,
                    itemBuilder: (context, index) {
                      final message = displayMessages[index];
                      final isLastBotMessage = _isStreaming && index == displayMessages.length - 1 && !message.isUser;
                      return Column(
                        crossAxisAlignment: message.isUser
                            ? CrossAxisAlignment.end
                            : CrossAxisAlignment.start,
                        children: [
                          MessageBubble(
                            message: message,
                            animate: isLastBotMessage, // Trigger typing effect for the last bot message
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 2),
                            child: Text(
                              _formatTimestamp(message.timestamp),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Error: $e')),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      enabled: _isConnected, // Disable when no network
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        errorText: !_isConnected ? 'Network required' : null,
                      ),
                      onSubmitted: (_) {
                        if (user != null && _isConnected && mounted) {
                          _sendMessage(chatId, user.uid);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    backgroundColor: _isConnected ? Colors.grey[800] : Colors.grey,
                    elevation: 2,
                    onPressed: _isConnected && user != null && mounted
                        ? () {
                            HapticFeedback.lightImpact();
                            _sendMessage(chatId, user.uid);
                          }
                        : null, // Disable when no network
                    child: const Icon(Icons.send, color: Colors.white),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    if (diff.inDays > 0) {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
    return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}