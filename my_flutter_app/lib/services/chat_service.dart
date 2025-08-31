
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:chatbot_app/models/message.dart';
import 'package:chatbot_app/models/conversation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String geminiApiKey = 'AIzaSyDUxhLgT_jRsaI0DHobJFF2JibBcbfHgvY'; // Replace with env-safe storage

  Future<String> getBotResponse(String userMessage) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$geminiApiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': userMessage}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'topK': 40,
            'topP': 0.95,
            'maxOutputTokens': 1024,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['candidates'] != null &&
            data['candidates'].isNotEmpty &&
            data['candidates'][0]['content'] != null &&
            data['candidates'][0]['content']['parts'] != null &&
            data['candidates'][0]['content']['parts'].isNotEmpty) {
          return data['candidates'][0]['content']['parts'][0]['text'];
        } else {
          throw Exception('Unexpected response structure: ${response.body}');
        }
      } else {
        throw Exception(
            'Failed to get response from Gemini API. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      print('Error communicating with Gemini API: $e');
      throw Exception('Error communicating with Gemini API: $e');
    }
  }

  Future<String> createNewChat(String userId) async {
    final chatRef = _firestore.collection('conversations').doc();
    await chatRef.set({
      'id': chatRef.id,
      'userId': userId,
      'createdAt': DateTime.now().toIso8601String(),
      'title': '', // empty title at first
    });
    return chatRef.id;
  }

  Future<void> saveMessage(Message message) async {
  final chatRef = _firestore.collection('conversations').doc(message.chatId);

  await chatRef.collection('messages').doc(message.id).set({
    ...message.toMap(),
    'timestamp': FieldValue.serverTimestamp(), // Use server timestamp
  });

  // Check if this is the first message (conversation title is still empty)
  final chatDoc = await chatRef.get();
  if (chatDoc.exists && (chatDoc.data()?['title'] ?? '').isEmpty) {
    await chatRef.update({'title': message.text});
  }
}
  Stream<List<Message>> getMessages(String chatId) {
    return _firestore
        .collection('conversations')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: false)// newest at top
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Message.fromMap(doc.data())).toList());
  }

  Stream<List<Conversation>> getConversations() {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return Stream.value([]);

    return _firestore
        .collection('conversations')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Conversation.fromMap(doc.data())).toList());
  }
}
