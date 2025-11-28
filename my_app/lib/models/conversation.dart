// lib/models/conversation.dart
import 'package:cloud_firestore/cloud_firestore.dart';

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

  // Create from Firestore document
  factory Conversation.fromFirestore(Map<String, dynamic> data, String docId) {
    final Timestamp ts = data['timestamp'] as Timestamp? ?? Timestamp.now();
    
    return Conversation(
      id: docId,
      userId: data['userId'] as String? ?? 'unknown',
      title: data['title'] as String? ?? 'Untitled Conversation',
      messages: List<Map<String, dynamic>>.from(data['messages'] ?? []),
      timestamp: ts.toDate(),
    );
  }

  // Get subtitle from last AI message
  String get subtitle {
    final lastAIMessage = messages.lastWhere(
      (m) => m['sender'] == 'ai',
      orElse: () => {'text': 'Conversation recorded'},
    );
    final text = lastAIMessage['text'] as String? ?? 'No response';
    return text.length > 60 ? '${text.substring(0, 60)}...' : text;
  }

  // Format date as "Jul 23, 2022" or "Today"
  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
  }
}