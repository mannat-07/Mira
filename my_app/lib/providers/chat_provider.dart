import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/mock_voice_service.dart';
import '../services/firebase_services.dart';
import '../models/chat_message.dart';

class ChatState {
  final List<ChatMessage> messages;
  final VoiceState voiceState;
  final String? error;
  final bool isInitializing;
  final bool isInitialized;
  final String? partialTranscription;

  ChatState({
    this.messages = const [],
    this.voiceState = VoiceState.idle,
    this.error,
    this.isInitializing = true,
    this.isInitialized = false,
    this.partialTranscription,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    VoiceState? voiceState,
    String? error,
    bool? isInitializing,
    bool? isInitialized,
    String? partialTranscription,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      voiceState: voiceState ?? this.voiceState,
      error: error,
      isInitializing: isInitializing ?? this.isInitializing,
      isInitialized: isInitialized ?? this.isInitialized,
      partialTranscription: partialTranscription,
    );
  }
}

class ChatNotifier extends StateNotifier<ChatState> {
  final MockVoiceService _voiceService;
  final FirebaseService _firebaseService;

  ChatNotifier(this._voiceService, this._firebaseService) : super(ChatState()) {
    _initializeVoiceService();
    _loadLastConversation();
  }

  Future<void> _loadLastConversation() async {
    try {
      final messagesData =
          await _firebaseService.getLastSavedConversationMessages();
      if (messagesData != null && messagesData.isNotEmpty) {
        final loadedMessages = messagesData.map((data) {
          return ChatMessage(
            sender: data['sender'] ?? 'user',
            content: data['text'] ?? '',
            isUser: data['sender'] == 'user',
            timestamp:
                DateTime.tryParse(data['timestamp'] ?? '') ?? DateTime.now(),
          );
        }).toList();

        state =
            state.copyWith(messages: [...state.messages, ...loadedMessages]);
        print('✅ Loaded last conversation: ${loadedMessages.length} messages');
      }
    } catch (e) {
      print('Failed to load last conversation: $e');
    }
  }

  Future<void> _initializeVoiceService() async {
    try {
      state = state.copyWith(isInitializing: true, isInitialized: false);
      await _voiceService.initialize();
      state = state.copyWith(isInitializing: false, isInitialized: true);

      _voiceService.stateStream.listen((voiceState) {
        state = state.copyWith(voiceState: voiceState);
      });

      _voiceService.partialTranscriptionStream.listen((partial) {
        state = state.copyWith(partialTranscription: partial);
      });

      _voiceService.transcriptionStream.listen((transcription) {
        if (transcription.isNotEmpty) {
          final userMessage = ChatMessage(
            content: transcription,
            isUser: true,
          );
          state = state.copyWith(
            messages: [...state.messages, userMessage],
            partialTranscription: null,
          );
        }
      });
      // Do NOT update UI with streaming AI chunks; let TTS start ASAP
      // and only reflect the final AI response in UI after a short delay.
      _voiceService.responseStream.listen((finalText) async {
        if (finalText.isEmpty) return;
        // Small delay to keep UI flow intact while speech starts immediately
        await Future.delayed(const Duration(milliseconds: 700));
        final msgs = [...state.messages];
        msgs.add(ChatMessage(
          content: finalText,
          isUser: false,
          isStreaming: false,
          isComplete: true,
        ));
        state = state.copyWith(messages: msgs);
      });

      _voiceService.errorStream.listen((error) {
        state = state.copyWith(error: error);
      });
    } catch (e) {
      state = state.copyWith(
        error: 'Failed to initialize voice service: $e',
        isInitializing: false,
        isInitialized: false,
      );
    }
  }

  Future<void> startConversation() async {
    if (!state.isInitialized) {
      state = state.copyWith(
          error: 'Voice service is not initialized yet. Please wait...');
      return;
    }

    try {
      // Ensure auto re-listen stays enabled unless explicitly disabled later
      _voiceService.setAutoReListen(true);
      await _voiceService.startConversation();
    } catch (e) {
      state = state.copyWith(error: 'Failed to start conversation: $e');
    }
  }

  // ✅ AUTO-SAVE when conversation stops
  Future<void> stopConversation() async {
    try {
      await _voiceService.stopConversation();
      print("got here");
      // Removed bulk save to avoid duplicating per-turn saved messages.
      // If you later add unsaved transient messages, reintroduce a selective flush here.
    } catch (e) {
      state = state.copyWith(error: 'Failed to stop conversation: $e');
    }
  }

  void clearError() {
    state = state.copyWith(error: null);
  }

  Future<void> saveConversationToFirebase() async {
    if (state.messages.isEmpty) return;

    try {
      final messagesToSave = state.messages.map((msg) {
        return <String, dynamic>{
          'sender': msg.isUser ? 'user' : 'ai',
          'text': msg.content,
          'timestamp': msg.timestamp.toIso8601String(),
        };
      }).toList();

      await _firebaseService.saveConversation(messages: messagesToSave);
      print('✅ Conversation auto-saved to Firebase');
    } catch (e) {
      print('Failed to save conversation: $e');
    }
  }

  /// ✅ Clear all messages from chat UI
  void clearMessages() {
    print('🧹 ChatProvider: Clearing all messages from UI');
    state = state.copyWith(messages: []);
    print('✅ ChatProvider: Messages cleared');
  }
}

final mockVoiceServiceProvider = Provider<MockVoiceService>((ref) {
  final service = MockVoiceService();
  ref.onDispose(() => service.dispose());
  return service;
});

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

final chatProvider = StateNotifierProvider<ChatNotifier, ChatState>((ref) {
  final voiceService = ref.read(mockVoiceServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  return ChatNotifier(voiceService, firebaseService);
});
