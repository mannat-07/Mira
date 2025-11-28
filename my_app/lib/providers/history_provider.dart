import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_services.dart';
import '../models/conversation.dart';

// -----------------------------------------------------------------------------
// 1️⃣ Firebase Service Provider
// -----------------------------------------------------------------------------
final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

// -----------------------------------------------------------------------------
// 2️⃣ Conversation History Stream Provider
//    (Used by HistoryScreen to listen to Firestore updates in real time)
// -----------------------------------------------------------------------------
final conversationHistoryProvider =
    StreamProvider.autoDispose<List<Conversation>>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);
  return firebaseService.getConversationHistory();
});

// -----------------------------------------------------------------------------
// 3️⃣ Chat Saver Provider
//    (Used by ChatScreen to save messages to Firestore)
// -----------------------------------------------------------------------------
final chatSaverProvider = Provider<
    Future<String> Function(List<Map<String, dynamic>> messages)>((ref) {
  final firebaseService = ref.watch(firebaseServiceProvider);

  return (List<Map<String, dynamic>> messages) async {
    await firebaseService.saveConversation(messages: messages);
    return "✅ Conversation saved successfully";
  };
});
