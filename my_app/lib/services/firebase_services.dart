import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

/// Service class for handling all Firebase Firestore operations
class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Temporary user (replace later with Firebase Auth UID)
  final String tempUserId = 'guest_user_123';
  final String collectionPath = 'conversations';

  /// ✅ Keeps track of the active conversation session
  String? _activeConversationId;

  /// ✅ Ensures Firebase is initialized before any Firestore access
  Future<void> _ensureInitialized() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
        print('✅ Firebase initialized in FirebaseService');
      }
      // Test Firestore connection
      await _db.settings;
      print('✅ Firestore connection verified');
    } catch (e) {
      print('❌ Firebase initialization error: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // 🟩 SAVE CONVERSATION
  // ---------------------------------------------------------------------------
  Future<void> saveConversation({
    required List<Map<String, dynamic>> messages,
  }) async {
    await _ensureInitialized();

    if (messages.isEmpty) {
      print('⚠️ No messages to save');
      return;
    }

    try {
      print(
          '🟡 Attempting to save conversation with ${messages.length} messages');

      // Debug: Print the messages being saved
      print('📝 Messages to save:');
      for (var msg in messages) {
        print('   - ${msg['sender']}: ${msg['text']}');
      }

      // Extract the first user message as title (ensure web DDC typing safety)
      final Map<String, dynamic> firstUserMessage = messages.firstWhere(
        (m) => m['sender'] == 'user',
        orElse: () => {'text': 'Untitled Conversation'},
      );
      final String firstUserMessageText =
          (firstUserMessage['text'] as String?) ?? 'Untitled Conversation';

      final shortTitle = firstUserMessageText.length > 50
          ? '${firstUserMessageText.substring(0, 50)}...'
          : firstUserMessageText;

      final conversationData = {
        'userId': tempUserId,
        'timestamp': FieldValue.serverTimestamp(),
        'messages': messages,
        'title': shortTitle,
      };

      // ✅ NEW: Append to existing conversation if active
      if (_activeConversationId != null) {
        print('🟢 Updating existing conversation: $_activeConversationId');

        final docRef =
            _db.collection(collectionPath).doc(_activeConversationId);
        await _db.runTransaction((transaction) async {
          final snapshot = await transaction.get(docRef);
          if (!snapshot.exists) {
            print('⚠️ Active conversation missing, creating new one...');
            final newDoc =
                await _db.collection(collectionPath).add(conversationData);
            _activeConversationId = newDoc.id;
            print('✅ Created new conversation with ID: ${newDoc.id}');
            return;
          }

          final existingMessages =
              List<Map<String, dynamic>>.from(snapshot['messages'] ?? []);
          existingMessages.addAll(messages);

          transaction.update(docRef, {
            'messages': existingMessages,
            'timestamp': FieldValue.serverTimestamp(),
          });
          print('✅ Updated conversation with ${messages.length} new messages');
        });

        print('✅ Messages appended to existing conversation!');
      } else {
        print('🟢 Creating new conversation...');
        final newDoc =
            await _db.collection(collectionPath).add(conversationData);
        _activeConversationId = newDoc.id;
        print('✅ New conversation created with ID: $_activeConversationId');

        // Verify the document was created
        final verifyDoc = await newDoc.get();
        if (verifyDoc.exists) {
          print('✅ Verified: Document exists in Firestore');
          final data = verifyDoc.data();
          print('   - Title: ${data?['title']}');
          print(
              '   - Messages count: ${(data?['messages'] as List?)?.length ?? 0}');
          print('   - UserID: ${data?['userId']}');
        } else {
          print('❌ Warning: Document not found after creation!');
        }
      }
    } catch (e, st) {
      print('❌ Failed to save conversation: $e');
      print(st);
    }
  }

  // ---------------------------------------------------------------------------
  // 🟦 GET CONVERSATION HISTORY STREAM
  // ---------------------------------------------------------------------------
  Stream<List<Conversation>> getConversationHistory() async* {
    try {
      await _ensureInitialized();
      print('📖 Fetching conversation history for user: $tempUserId');

      // Query conversations - simpler query without composite index
      yield* _db
          .collection(collectionPath)
          .where('userId', isEqualTo: tempUserId)
          .snapshots()
          .map((snapshot) {
        print('📦 Received ${snapshot.docs.length} conversation documents');

        // Convert to Conversation objects
        final conversations = snapshot.docs
            .map((doc) {
              try {
                final data = doc.data();
                print('📄 Processing conversation: ${doc.id}');
                return Conversation.fromFirestore(data, doc.id);
              } catch (e) {
                print('❌ Error parsing conversation ${doc.id}: $e');
                return null;
              }
            })
            .whereType<Conversation>()
            .toList();

        // Sort by timestamp in Dart (not in query) to avoid index requirement
        conversations.sort((a, b) => b.timestamp.compareTo(a.timestamp));

        print('✅ Successfully parsed ${conversations.length} conversations');
        return conversations;
      }).handleError((error) {
        print('❌ Firestore stream error: $error');
        print('Error details: ${error.runtimeType}');
      });
    } catch (e, stackTrace) {
      print('❌ Failed to create Firestore stream: $e');
      print('Stack trace: $stackTrace');
      yield [];
    }
  }

  // ---------------------------------------------------------------------------
  // 🟨 GET MOST RECENT CONVERSATION
  // ---------------------------------------------------------------------------
  Future<List<Map<String, dynamic>>?> getLastSavedConversationMessages() async {
    await _ensureInitialized();

    try {
      final query = await _db
          .collection(collectionPath)
          .where('userId', isEqualTo: tempUserId)
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 5));

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        final messagesField = data['messages'];
        if (messagesField is List) {
          _activeConversationId =
              query.docs.first.id; // ✅ keep track of last session
          return List<Map<String, dynamic>>.from(messagesField);
        }
      }
    } catch (e) {
      print('❌ Failed to load last conversation: $e');
    }
    return null;
  }

  Future<void> deleteConversation(String conversationId) async {
    await _ensureInitialized();

    try {
      print('🗑️ Deleting conversation: $conversationId');

      await _db.collection(collectionPath).doc(conversationId).delete();

      // If we're deleting the active conversation, reset it
      if (_activeConversationId == conversationId) {
        _activeConversationId = null;
        print('🔄 Active conversation reset');
      }

      print('✅ Conversation deleted successfully');
    } catch (e) {
      print('❌ Error deleting conversation: $e');
      rethrow;
    }
  }

  /// Deletes all conversations for the current user
  Future<void> clearAllConversations() async {
    await _ensureInitialized();

    try {
      final batch = _db.batch();
      final snapshots = await _db
          .collection(collectionPath)
          .where('userId', isEqualTo: tempUserId)
          .get();

      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      _activeConversationId = null; // ✅ Reset active session
      print('🧹 All conversations cleared successfully');
    } catch (e) {
      print('❌ Failed to clear conversations: $e');
    }
  }

  /// ✅ Public helper to start a new session manually
  void startNewConversation() {
    print('🔄 Starting new conversation session...');
    _activeConversationId = null;
  }
}

// ===========================================================================
// 🧩 MODEL: CONVERSATION
// ===========================================================================
class Conversation {
  final String id;
  final String userId;
  final String title;
  final List<Map<String, dynamic>> messages;
  final DateTime timestamp;

  Conversation({
    required this.id,
    required this.userId,
    required this.title,
    required this.messages,
    required this.timestamp,
  });

  factory Conversation.fromFirestore(Map<String, dynamic> data, String docId) {
    try {
      final timestampField = data['timestamp'];
      DateTime timestamp;

      if (timestampField is Timestamp) {
        timestamp = timestampField.toDate();
      } else if (timestampField is String) {
        timestamp = DateTime.tryParse(timestampField) ?? DateTime.now();
      } else {
        timestamp = DateTime.now();
      }

      final rawMessages = (data['messages'] as List?)
              ?.map((m) => Map<String, dynamic>.from(m))
              .toList() ??
          [];

      return Conversation(
        id: docId,
        userId: data['userId'] as String? ?? 'unknown',
        title: data['title'] as String? ?? 'Untitled Conversation',
        messages: rawMessages,
        timestamp: timestamp,
      );
    } catch (e) {
      print('❌ Error creating Conversation from Firestore: $e');
      rethrow;
    }
  }

  String get subtitle {
    try {
      final Map<String, dynamic> lastAIMessage = messages.lastWhere(
        (m) => m['sender'] == 'ai',
        orElse: () => {'text': 'Conversation recorded'},
      );
      final String text = lastAIMessage['text'] as String? ?? 'No response';
      return text.length > 60 ? '${text.substring(0, 60)}...' : text;
    } catch (e) {
      return 'Conversation recorded';
    }
  }

  String get formattedDate {
    try {
      final now = DateTime.now();
      final diff = now.difference(timestamp);

      if (diff.inDays == 0) return 'Today';
      if (diff.inDays == 1) return 'Yesterday';
      if (diff.inDays < 7) return '${diff.inDays} days ago';

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
    } catch (_) {
      return 'Recent';
    }
  }
}
