import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'llm_service.dart';
import '../constants/api_keys.dart';
import 'tts_service.dart';
import 'firebase_services.dart';

enum VoiceState { idle, listening, processing, speaking, error }

/// A simple mock voice service that works on all platforms
/// without any native dependencies like Agora
class MockVoiceService {
  // State management
  VoiceState _currentState = VoiceState.idle;
  String _lastTranscription = '';
  String _lastResponse = '';
  String _lastError = '';

  // Speech-to-text engine
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _sttAvailable = false;
  bool _isListening = false;

  // LLM service
  final LLMService _llmService = LLMService();
  // TTS service
  final TTSService _ttsService = TTSService();
  // Firestore direct save (atomic user+ai turn)
  final FirebaseService _firebaseService = FirebaseService();

  // Track conversation messages for current session
  final List<Map<String, dynamic>> _conversationMessages = [];

  // Track if this is the first conversation of the session
  bool _isFirstConversation = true;

  // Platform support check
  bool get _platformSupportsSTT =>
      kIsWeb || Platform.isAndroid || Platform.isIOS;

  // Stream controllers
  final StreamController<VoiceState> _stateController =
      StreamController<VoiceState>.broadcast();
  final StreamController<String> _transcriptionController =
      StreamController<String>.broadcast();
  final StreamController<String> _partialTranscriptionController =
      StreamController<String>.broadcast();
  final StreamController<String> _responseController =
      StreamController<String>.broadcast();
  // New: partial response stream for streaming AI output
  final StreamController<String> _partialResponseController =
      StreamController<String>.broadcast();
  final StreamController<String> _errorController =
      StreamController<String>.broadcast();

  // Getters
  VoiceState get currentState => _currentState;
  String get lastTranscription => _lastTranscription;
  String get lastResponse => _lastResponse;
  String get lastError => _lastError;

  // Streams
  Stream<VoiceState> get stateStream => _stateController.stream;
  Stream<String> get transcriptionStream => _transcriptionController.stream;
  Stream<String> get partialTranscriptionStream =>
      _partialTranscriptionController.stream;
  Stream<String> get responseStream => _responseController.stream;
  Stream<String> get partialResponseStream => _partialResponseController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool get isListening => _isListening;
  // TTS flow guards
  bool _preambleSpoken = false;
  // Auto re-listen after TTS completion
  bool _autoReListen = true; // enabled by default for conversational flow
  bool _manualStopRequested = false;
  Timer? _autoListenTimer;

  // ---------------------------------------------------------------------------
  // ⚡ Preview streaming while user is still speaking
  // ---------------------------------------------------------------------------
  Timer? _previewDebounce;
  StreamSubscription<String>? _previewSub;
  String _lastPreviewInput = '';
  // removed: preview TTS state flag (not needed with preamble approach)

  /// Initialize the voice service (mock - always succeeds)
  Future<void> initialize() async {
    try {
      debugPrint('MockVoiceService: Initializing...');

      // Check if platform supports STT
      if (!_platformSupportsSTT) {
        debugPrint(
            'MockVoiceService: Platform does not support speech recognition');
        debugPrint('MockVoiceService: Run with: flutter run -d chrome');
        _updateError(
            'Speech recognition not supported on Linux desktop.\n\nTo test voice capture on PC:\n1. Stop this app (press q)\n2. Run: flutter run -d chrome\n3. Grant microphone permission\n4. Click mic and speak!');
        _isInitialized = true;
        return;
      }

      // Initialize LLM service
      if (ApiKeys.isGeminiConfigured) {
        try {
          await _llmService.initialize(ApiKeys.geminiApiKey);
          debugPrint('MockVoiceService: LLM service initialized');
        } catch (e) {
          debugPrint('MockVoiceService: LLM initialization failed: $e');
          _updateError(
              'Failed to initialize AI service. Please check API key.');
          _isInitialized = true;
          return;
        }
      } else {
        debugPrint('MockVoiceService: Warning - Gemini API key not configured');
        _updateError('Gemini API key not configured.\n\n'
            'Please add your API key in:\n'
            'lib/constants/api_keys.dart\n\n'
            'Get a free key at:\n'
            'https://makersuite.google.com/app/apikey');
        _isInitialized = true;
        return;
      }

      // Initialize TTS service (non-blocking for overall flow)
      try {
        final ttsOk = await _ttsService.initialize();
        if (ttsOk) {
          debugPrint('MockVoiceService: TTS service initialized');
          // Reflect TTS speaking state into VoiceState
          _ttsService.speakingStream.listen((isSpeaking) {
            if (isSpeaking) {
              _updateState(VoiceState.speaking);
            } else if (_currentState == VoiceState.speaking) {
              // Return to idle only if we were speaking
              _updateState(VoiceState.idle);
              // Optionally auto re-enable mic after speaking
              _scheduleAutoListenAfterResponse();
            }
          });
          _ttsService.errorStream.listen((err) {
            debugPrint('MockVoiceService: TTS error: $err');
            _updateError('TTS error: $err');
          });
        } else {
          debugPrint(
              'MockVoiceService: TTS initialization failed; continuing without TTS');
        }
      } catch (e) {
        debugPrint('MockVoiceService: TTS init exception: $e');
      }

      // Request mic permission where applicable (mobile/desktop)
      try {
        final status = await Permission.microphone.request();
        if (status != PermissionStatus.granted) {
          debugPrint('MockVoiceService: Microphone permission not granted');
          _updateError('Microphone permission denied');
          _isInitialized = true;
          return;
        }
      } catch (e) {
        debugPrint('MockVoiceService: Permission request failed: $e');
      }

      // Try to initialize on-device speech recognition
      try {
        _sttAvailable = await _speech.initialize(
          onError: (err) {
            debugPrint('MockVoiceService: STT error: $err');
            _updateState(VoiceState.error);
          },
          onStatus: (status) {
            debugPrint('MockVoiceService: STT status: $status');
            if (status == 'notListening' && _isListening) {
              // finalize and move to idle if needed
              _isListening = false;
              if (_currentState == VoiceState.listening) {
                _updateState(VoiceState.idle);
              }
            }
          },
        );
        debugPrint('MockVoiceService: STT available: $_sttAvailable');
      } catch (e) {
        debugPrint('MockVoiceService: STT init failed: $e');
        _sttAvailable = false;
      }

      _isInitialized = true;
      _updateState(VoiceState.idle);

      debugPrint('MockVoiceService: Initialized successfully');
    } catch (e) {
      debugPrint('MockVoiceService: Failed to initialize: $e');
      _updateError('Failed to initialize: $e');
      rethrow;
    }
  }

  /// Start voice conversation (real mic capture only)
  Future<void> startConversation() async {
    if (!_isInitialized) {
      throw Exception('Service not initialized');
    }
    // If user explicitly starts, clear manual stop guard
    _manualStopRequested = false;

    try {
      debugPrint('MockVoiceService: Starting conversation...');

      // ✅ Only start NEW conversation on first call
      if (_isFirstConversation) {
        _conversationMessages.clear();
        _firebaseService.startNewConversation();
        _isFirstConversation = false;
        debugPrint('🆕 Starting FIRST conversation of session');
      } else {
        // Continue existing conversation thread
        debugPrint(
            '📝 Continuing existing conversation thread (${_conversationMessages.length} messages so far)');
      }

      // Check platform support first
      if (!_platformSupportsSTT) {
        _updateError(
            'Speech recognition is not supported on this platform (Linux desktop).');
        return;
      }

      // Check if STT is available
      if (!_sttAvailable) {
        _updateError('Speech recognition is not available on this device.');
        return;
      }

      _updateState(VoiceState.listening);
      _isListening = true;

      await _speech.listen(
        onResult: (result) {
          final words = result.recognizedWords;
          if (words.isNotEmpty) {
            _lastTranscription = words;

            if (result.finalResult) {
              // Final result - add to transcription stream (creates message)
              _transcriptionController.add(words);
              debugPrint('MockVoiceService: Final transcription: $words');
              _isListening = false;

              // Process with LLM
              _processWithLLM(words);
            } else {
              // Partial result - show live updates without creating messages
              _partialTranscriptionController.add(words);
              debugPrint('MockVoiceService: Partial transcription: $words');

              // Start/refresh preview stream with debounce to reduce thrash
              _schedulePreviewLLM(words);
            }
          }
        },
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        partialResults: true,
        cancelOnError: true,
        localeId: 'en_US',
      );
      debugPrint('MockVoiceService: Listening with STT...');
    } catch (e) {
      debugPrint('MockVoiceService: Error in conversation: $e');
      _updateError('Conversation error: $e');
      _isListening = false;
    }
  }

  /// Process text with AI and get response
  Future<void> _processWithLLM(String userMessage) async {
    try {
      debugPrint('MockVoiceService: Processing with LLM...');
      debugPrint('MockVoiceService: User message: "$userMessage"');
      _updateState(VoiceState.processing);

      // Stop any preview stream when we have final input
      _cancelPreviewLLM();

      // Add user message to conversation
      final userMsg = {
        'text': userMessage,
        'sender': 'user',
        'timestamp': DateTime.now().toIso8601String(),
      };
      _conversationMessages.add(userMsg);
      debugPrint('MockVoiceService: Added user message to conversation');

      // Stream message to LLM and emit partial chunks
      final buffer = StringBuffer();
      await for (final chunk in _llmService.streamMessage(userMessage)) {
        buffer.write(chunk);
        final partial = buffer.toString();
        _partialResponseController.add(partial);
        // Do NOT speak partials in final pass to avoid interruptions.
      }

      // Finalize response
      final response = buffer.toString();
      _lastResponse = response;
      _responseController.add(response);
      debugPrint(
          'MockVoiceService: Final LLM response: "${response.substring(0, response.length > 50 ? 50 : response.length)}..."');

      // Add AI response to conversation
      final aiMsg = {
        'text': response,
        'sender': 'ai',
        'timestamp': DateTime.now().toIso8601String(),
      };
      _conversationMessages.add(aiMsg);
      debugPrint('MockVoiceService: Added AI message to conversation');

      // ✅ Save conversation to Firestore
      await _saveCurrentConversation();

      // Speak final response
      if (_ttsService.isInitialized) {
        // If a preamble is playing, stop it once before final speak
        if (_ttsService.isSpeaking) {
          await _ttsService.stop();
        }
        await _ttsService.speak(response, saveToBackend: false);
      }

      if (!_ttsService.isInitialized) {
        _updateState(VoiceState.idle);
      }
    } catch (e, stackTrace) {
      debugPrint('MockVoiceService: LLM error: $e');
      debugPrint('MockVoiceService: Stack trace: $stackTrace');

      // ✅ Still save conversation even if there's an error (user message exists)
      if (_conversationMessages.isNotEmpty) {
        debugPrint('MockVoiceService: Saving conversation despite error...');
        await _saveCurrentConversation();
      }

      _updateError('AI processing error: $e');
      _updateState(VoiceState.idle);
    }
  }

  // ---------------------------------------------------------------------------
  // 💾 Save Current Conversation Helper
  // ---------------------------------------------------------------------------
  Future<void> _saveCurrentConversation() async {
    if (_conversationMessages.isEmpty) {
      debugPrint('⚠️ MockVoiceService: No messages to save');
      return;
    }

    try {
      debugPrint(
          '💾 MockVoiceService: Saving conversation with ${_conversationMessages.length} messages...');

      // Create a copy to avoid modifications during save
      final messagesToSave =
          List<Map<String, dynamic>>.from(_conversationMessages);

      await _firebaseService.saveConversation(messages: messagesToSave);

      debugPrint('✅ MockVoiceService: Conversation saved successfully!');
      debugPrint(
          '📊 MockVoiceService: Saved ${messagesToSave.length} messages');
    } catch (e, stackTrace) {
      debugPrint('❌ MockVoiceService: Failed to save conversation: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }

  // ---------------------------------------------------------------------------
  // ⚡ LLM Preview while still speaking (debounced restarts)
  // ---------------------------------------------------------------------------
  void _schedulePreviewLLM(String text) {
    // Only restart preview if text actually changed and is long enough
    if (text == _lastPreviewInput) return;
    _lastPreviewInput = text;

    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 400), () {
      _startPreviewLLM(_lastPreviewInput);
    });
  }

  Future<void> _startPreviewLLM(String text) async {
    if (!_isInitialized || text.trim().isEmpty) return;

    // Cancel any existing preview stream
    await _previewSub?.cancel();
    // no-op

    final buffer = StringBuffer();
    try {
      _previewSub = _llmService.streamMessage(text).listen((chunk) async {
        buffer.write(chunk);
        final partial = buffer.toString();
        _partialResponseController.add(partial);
        // Speak a short preamble only once to reduce perceived latency
        if (!_preambleSpoken && _ttsService.isInitialized) {
          _preambleSpoken = true;
          await _ttsService.speak('Okay,', saveToBackend: false);
        }
      }, onError: (e) {
        debugPrint('MockVoiceService: Preview stream error: $e');
      }, onDone: () {
        // Do nothing; finalization handled in _processWithLLM
      });
    } catch (e) {
      debugPrint('MockVoiceService: Failed to start preview: $e');
    }
  }

  void _cancelPreviewLLM() {
    _previewDebounce?.cancel();
    _previewDebounce = null;
    _previewSub?.cancel();
    _previewSub = null;
    // no-op
    // don't reset _preambleSpoken here; we may stop it at final speak
  }

  /// Stop conversation
  Future<void> stopConversation() async {
    try {
      debugPrint('MockVoiceService: Stopping conversation...');
      _manualStopRequested = true;
      _autoListenTimer?.cancel();

      // ✅ Save conversation before stopping (if any messages exist)
      if (_conversationMessages.isNotEmpty) {
        debugPrint('💾 MockVoiceService: Saving conversation on stop...');
        await _saveCurrentConversation();
      }

      if (_speech.isListening) {
        await _speech.stop();
      }
      _isListening = false;
      // Stop any ongoing TTS
      if (_ttsService.isInitialized) {
        await _ttsService.stop();
      }
      _updateState(VoiceState.idle);
      debugPrint(
          'MockVoiceService: Conversation paused (thread continues with ${_conversationMessages.length} messages)');
      _preambleSpoken = false;
    } catch (e) {
      debugPrint('MockVoiceService: Error stopping conversation: $e');
      _updateError('Stop error: $e');
    }
  }

  /// ✅ Explicitly start a NEW conversation thread
  Future<void> startNewThread() async {
    debugPrint('🔄 MockVoiceService: Starting NEW conversation thread');

    // Save current conversation if it exists
    if (_conversationMessages.isNotEmpty) {
      debugPrint(
          '💾 Saving previous conversation before starting new thread...');
      await _saveCurrentConversation();
    }

    // Clear messages and reset Firebase session
    _conversationMessages.clear();
    _firebaseService.startNewConversation();
    _isFirstConversation =
        false; // Reset flag so next startConversation continues the new thread

    debugPrint('✅ New conversation thread started');
  }

  /// ✅ Clears the current conversation messages from memory
  void clearCurrentConversation() {
    debugPrint('🧹 Clearing current conversation from memory');
    _conversationMessages.clear();
    _isFirstConversation = true; // Reset for next conversation
    debugPrint(
        '✅ Conversation cleared (${_conversationMessages.length} messages remaining)');
  }

  // ---------------------------------------------------------------------------
  // 🔁 Auto re-enable mic after TTS completes
  // ---------------------------------------------------------------------------
  void _scheduleAutoListenAfterResponse() {
    if (!_autoReListen) return;
    if (!_isInitialized || !_sttAvailable || _isListening) return;
    if (_manualStopRequested) return; // respect manual stop
    // Avoid multiple timers
    _autoListenTimer?.cancel();
    _autoListenTimer = Timer(const Duration(milliseconds: 300), () async {
      // Final guard checks before starting
      if (!_autoReListen || _manualStopRequested || _isListening) return;
      try {
        await startConversation();
      } catch (e) {
        debugPrint('MockVoiceService: Auto re-listen failed: $e');
      }
    });
  }

  /// Public toggle for auto re-listen behavior
  void setAutoReListen(bool enabled) {
    _autoReListen = enabled;
    if (!enabled) {
      _autoListenTimer?.cancel();
    }
  }

  /// Update state and notify listeners
  void _updateState(VoiceState newState) {
    _currentState = newState;
    _stateController.add(newState);
    debugPrint('MockVoiceService: State changed to: $newState');
  }

  /// Update error and notify listeners
  void _updateError(String error) {
    _lastError = error;
    _errorController.add(error);
    _updateState(VoiceState.error);
  }

  /// Dispose resources
  void dispose() {
    debugPrint('MockVoiceService: Disposing...');

    if (_speech.isListening) {
      _speech.stop();
    }
    _llmService.dispose();
    _ttsService.dispose();
    _stateController.close();
    _transcriptionController.close();
    _partialTranscriptionController.close();
    _responseController.close();
    _partialResponseController.close();
    _errorController.close();
    _cancelPreviewLLM();

    _isInitialized = false;
  }
}
