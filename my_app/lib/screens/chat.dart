import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';
import '../widgets/chat_bubble.dart';
import '../widgets/mic_button.dart';
import '../widgets/voice_animation.dart';
import '../providers/chat_provider.dart';
import '../models/chat_message.dart';
import '../services/mock_voice_service.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _micController;
  final ScrollController _scrollController = ScrollController();
  bool _isUserScrolling = false;
  Timer? _scrollDebounce;

  @override
  void initState() {
    super.initState();
    _micController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Detect when user manually scrolls
    _scrollController.addListener(_onScroll);

    // Scroll to bottom after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animate: false);
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // User is scrolling if they're not at the bottom
    final isAtBottom = _scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50;

    if (_isUserScrolling != !isAtBottom) {
      setState(() {
        _isUserScrolling = !isAtBottom;
      });
    }
  }

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position.maxScrollExtent;

    if (animate) {
      _scrollController.animateTo(
        position,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(position);
    }
  }

  void _scrollToBottomIfNeeded() {
    // Only auto-scroll if user is NOT manually scrolling
    if (!_isUserScrolling) {
      // Debounce rapid scroll calls
      _scrollDebounce?.cancel();
      _scrollDebounce = Timer(const Duration(milliseconds: 100), () {
        _scrollToBottom();
      });
    }
  }

  @override
  void dispose() {
    _micController.dispose();
    _scrollController.dispose();
    _scrollDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);

    // Listen to message changes and auto-scroll
    ref.listen<ChatState>(chatProvider, (previous, next) {
      if (next.messages.length > (previous?.messages.length ?? 0)) {
        // New message arrived, scroll to bottom after build
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottomIfNeeded();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildAppBar(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildChatArea(chatState),
                  ),
                ),
                _buildBottomControls(chatState.voiceState),
              ],
            ),
            // Show "scroll to bottom" FAB when user scrolls up
            if (_isUserScrolling)
              Positioned(
                bottom: 120,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: () {
                    setState(() => _isUserScrolling = false);
                    _scrollToBottom();
                  },
                  backgroundColor: AppColors.primary,
                  child: const Icon(Icons.arrow_downward, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🧱 APP BAR
  // ---------------------------------------------------------------------------
  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    Icon(Icons.graphic_eq, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Text('Mira', style: AppStyles.heading2),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        icon: Icon(icon, size: 24),
        onPressed: onTap,
        color: Colors.grey.shade700,
        tooltip: tooltip,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🧠 CHAT AREA (main content logic)
  // ---------------------------------------------------------------------------
  Widget _buildChatArea(ChatState chatState) {
    // 🔸 No messages yet — show welcome state
    if (chatState.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 20),
            Text(
              'Tap the mic to start talking',
              style: AppStyles.heading2.copyWith(color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Your conversation will appear here once you start speaking.',
              style: AppStyles.body2.copyWith(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // 🔹 Messages exist — show chat bubbles with ScrollController
    return SingleChildScrollView(
      controller: _scrollController, // ✅ Attach scroll controller
      child: Column(
        children: [
          const SizedBox(height: 20),
          ...chatState.messages.asMap().entries.map((entry) {
            final index = entry.key;
            final message = entry.value;
            return Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                ChatBubble(
                  text: message.content,
                  isUser: message.isUser,
                ),
                const SizedBox(height: 4),
                Text(
                  message.isUser ? 'You' : 'Mira',
                  style: AppStyles.body2,
                ),
                if (index != chatState.messages.length - 1)
                  const SizedBox(height: 16),
              ],
            );
          }),
          if (chatState.partialTranscription != null &&
              chatState.partialTranscription!.isNotEmpty)
            _buildPartialTranscription(chatState.partialTranscription!),
          if (chatState.voiceState.isListening) _buildListeningIndicator(),
          if (chatState.error != null) _buildErrorMessage(chatState.error!),
          const SizedBox(height: 20), // ✅ Extra space at bottom for scroll
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🔵 PARTIAL / LISTENING / ERROR WIDGETS
  // ---------------------------------------------------------------------------
  Widget _buildPartialTranscription(String partial) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic, size: 16, color: Colors.blue.shade600),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              partial,
              style: TextStyle(
                color: Colors.blue.shade800,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListeningIndicator() {
    return Column(
      children: const [
        SizedBox(height: 40),
        Text('Listening...', style: AppStyles.body2),
        SizedBox(height: 20),
        VoiceAnimation(),
      ],
    );
  }

  Widget _buildErrorMessage(String error) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: Colors.red.shade700, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🎙️ MIC + STATUS CONTROLS
  // ---------------------------------------------------------------------------
  Widget _buildBottomControls(VoiceState voiceState) {
    final chatState = ref.watch(chatProvider);

    String statusText = voiceState.stateDescription;
    if (chatState.isInitializing) {
      statusText = 'Initializing voice service...';
    } else if (!chatState.isInitialized) {
      statusText = 'Voice service initialization failed';
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(
            statusText,
            style: AppStyles.body2.copyWith(
              color: voiceState.isActive
                  ? const Color.fromRGBO(33, 150, 243, 1)
                  : Colors.grey,
              fontWeight:
                  voiceState.isActive ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: MicButton(
              onTap: () => _toggleListening(voiceState),
              isListening: voiceState.isListening,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 🎤 TOGGLE LISTENING
  // ---------------------------------------------------------------------------
  Future<void> _toggleListening(VoiceState voiceState) async {
    final chatNotifier = ref.read(chatProvider.notifier);
    final chatState = ref.read(chatProvider);
    final firebaseService = ref.read(firebaseServiceProvider);

    if (!chatState.isInitialized) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(chatState.isInitializing
              ? 'Voice service is still initializing...'
              : 'Voice service failed to initialize'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    if (voiceState.isListening) {
      // 🛑 Stop listening
      await chatNotifier.stopConversation();
      // 🔕 Do not bulk-save here; per-turn atomic saves are handled by VoiceService.
    } else {
      // 🆕 Start a new conversation only if no messages exist
      if (chatState.messages.isEmpty) {
        firebaseService.startNewConversation();
      }
      chatNotifier.startConversation();
    }
  }
}
