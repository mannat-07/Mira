import '../services/mock_voice_service.dart';

class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final String sender;
  final bool isStreaming;
  final bool isComplete;

  ChatMessage({
    required this.content,
    required this.isUser,
    String? sender,
    DateTime? timestamp,
    this.isStreaming = false,
    this.isComplete = true,
  })  : sender = sender ?? (isUser ? 'user' : 'ai'),
        timestamp = timestamp ?? DateTime.now();

  ChatMessage copyWith({
    String? content,
    bool? isStreaming,
    bool? isComplete,
  }) {
    return ChatMessage(
      content: content ?? this.content,
      isUser: isUser,
      sender: sender,
      timestamp: timestamp,
      isStreaming: isStreaming ?? this.isStreaming,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

extension VoiceStateExtension on VoiceState {
  bool get isActive => this != VoiceState.idle;
  bool get isListening => this == VoiceState.listening;
  bool get isInitialized => true;

  String get stateDescription {
    switch (this) {
      case VoiceState.idle:
        return 'Tap to start voice conversation';
      case VoiceState.listening:
        return 'Listening...';
      case VoiceState.processing:
        return 'Processing your request...';
      case VoiceState.speaking:
        return 'Speaking response...';
      case VoiceState.error:
        return 'Error occurred';
    }
  }
}
