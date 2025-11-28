import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../services/firebase_services.dart'; // ✅ Firestore service

/// Service to handle Text-to-Speech functionality
class TTSService {
  static final TTSService _instance = TTSService._internal();
  factory TTSService() => _instance;
  TTSService._internal();

  FlutterTts? _tts;
  bool _initialized = false;
  bool _speaking = false;

  final _speakingCtrl = StreamController<bool>.broadcast();
  final _errorCtrl = StreamController<String>.broadcast();

  bool get isInitialized => _initialized;
  bool get isSpeaking => _speaking;
  Stream<bool> get speakingStream => _speakingCtrl.stream;
  Stream<String> get errorStream => _errorCtrl.stream;

  final FirebaseService _firebaseService = FirebaseService(); // ✅ Firestore

  // ---------------------------------------------------------------------------
  // 🔹 Initialization
  // ---------------------------------------------------------------------------
  Future<bool> initialize() async {
    try {
      debugPrint('TTSService: Initializing...');
      _tts = FlutterTts();

      _tts!.setStartHandler(() {
        debugPrint('TTSService: Started speaking');
        _speaking = true;
        _speakingCtrl.add(true);
      });
      _tts!.setCompletionHandler(() {
        debugPrint('TTSService: Finished speaking');
        _speaking = false;
        _speakingCtrl.add(false);
      });
      _tts!.setCancelHandler(() {
        debugPrint('TTSService: Speaking cancelled');
        _speaking = false;
        _speakingCtrl.add(false);
      });
      _tts!.setErrorHandler((msg) {
        debugPrint('TTSService: Error: $msg');
        _speaking = false;
        _speakingCtrl.add(false);
        _errorCtrl.add('TTS error: $msg');
      });

      await _configure();
      _initialized = true;
      debugPrint('TTSService: Initialized successfully');
      return true;
    } catch (e) {
      debugPrint('TTSService: Failed to initialize: $e');
      _errorCtrl.add('Failed to initialize TTS: $e');
      return false;
    }
  }

  Future<void> _configure() async {
    await _tts!.setLanguage('en-US');

    // ✅ Set platform-specific speech rate
    double speechRate;

    if (kIsWeb) {
      speechRate = 0.9; // Faster for web/Chrome
      debugPrint('TTSService: Using WEB speech rate: $speechRate');
    } else if (Platform.isAndroid) {
      speechRate = 0.5; // Keep slower for Android
      debugPrint('TTSService: Using ANDROID speech rate: $speechRate');
    } else {
      speechRate = 0.6; // Default for other platforms (iOS, etc.)
      debugPrint('TTSService: Using DEFAULT speech rate: $speechRate');
    }

    await _tts!.setSpeechRate(speechRate);
    await _tts!.setVolume(0.9);
    await _tts!.setPitch(1.0);

    if (!kIsWeb) {
      try {
        if (Platform.isIOS) {
          await _tts!.setSharedInstance(true);
        }
      } catch (_) {}
    }
  }

  // ---------------------------------------------------------------------------
  // 🗣️ Speak AI response (and save to Firestore)
  // ---------------------------------------------------------------------------
  Future<void> speak(String text, {bool saveToBackend = true}) async {
    if (!_initialized || text.trim().isEmpty) return;

    try {
      // Only stop if currently speaking to avoid spamming interruptions.
      if (_speaking) {
        await stop();
      }
      debugPrint('TTSService: Speaking: "$text"');
      await _tts!.speak(text);
      if (saveToBackend) {
        // ✅ Save this AI message to Firestore
        await _saveAIMessage(text);
      }
    } catch (e) {
      debugPrint('TTSService: Speak failed: $e');
      _errorCtrl.add('Speak failed: $e');
      _speaking = false;
      _speakingCtrl.add(false);
    }
  }

  // ---------------------------------------------------------------------------
  // 💬 Save AI message
  // ---------------------------------------------------------------------------
  Future<void> _saveAIMessage(String text) async {
    try {
      debugPrint('TTSService: Saving AI message...');
      await _firebaseService.saveConversation(messages: <Map<String, dynamic>>[
        <String, dynamic>{
          'text': text,
          'sender': 'ai',
          'timestamp': DateTime.now().toIso8601String(),
        }
      ]);
      debugPrint('TTSService: AI message saved to Firestore ✅');
    } catch (e) {
      debugPrint('TTSService: Failed to save AI message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // 💬 Public method to save AI message (without speaking)
  // ---------------------------------------------------------------------------
  Future<void> saveAIMessage(String text) async {
    await _saveAIMessage(text);
  }

  // ---------------------------------------------------------------------------
  // 🧍 Save user message (🆕 Added method)
  // ---------------------------------------------------------------------------
  Future<void> saveUserMessage(String text) async {
    if (text.trim().isEmpty) return;
    try {
      debugPrint('TTSService: Saving user message...');
      await _firebaseService.saveConversation(messages: <Map<String, dynamic>>[
        <String, dynamic>{
          'text': text,
          'sender': 'user',
          'timestamp': DateTime.now().toIso8601String(),
        }
      ]);
      debugPrint('TTSService: User message saved to Firestore ✅');
    } catch (e) {
      debugPrint('TTSService: Failed to save user message: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // ⚙️ Utility methods
  // ---------------------------------------------------------------------------
  Future<void> setSpeechRate(double rate) async {
    if (!_initialized) return;
    final normalized = rate.clamp(0.0, 1.0);
    try {
      await _tts!.setSpeechRate(normalized);
      debugPrint('TTSService: Speech rate set to $normalized');
    } catch (e) {
      debugPrint('TTSService: Failed to set speech rate: $e');
    }
  }

  Future<void> stop() async {
    if (!_initialized) return;
    try {
      await _tts!.stop();
      _speaking = false;
      _speakingCtrl.add(false);
      debugPrint('TTSService: Stopped speaking');
    } catch (_) {}
  }

  void dispose() {
    debugPrint('TTSService: Disposing...');
    stop();
    _speakingCtrl.close();
    _errorCtrl.close();
    _initialized = false;
  }
}
