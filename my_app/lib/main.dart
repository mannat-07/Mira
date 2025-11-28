// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart'; // ✅ include this

import 'screens/chat.dart';
import 'screens/history.dart';
import 'constants/theme.dart';

// 🆕 import the new landing page
import 'screens/landing_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔐 Load environment variables from .env file
  try {
    await dotenv.load(fileName: ".env");
    print('✅ Environment variables loaded successfully');
  } catch (e) {
    print('⚠️ Warning: Could not load .env file: $e');
    print('   Make sure to copy .env.example to .env and fill in your values');
  }

  String? firebaseError;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e, st) {
    firebaseError = e.toString();
    print('❌ Firebase initialization failed: $e\n$st');
  }

  runApp(
    ProviderScope(
      child: firebaseError == null
          ? const ConvoAIApp()
          : FirebaseErrorApp(error: firebaseError),
    ),
  );
}

class FirebaseErrorApp extends StatelessWidget {
  final String? error;
  const FirebaseErrorApp({Key? key, this.error}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mira - Startup Error',
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(title: const Text('Startup error')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 12),
                const Text(
                  'Firebase failed to initialize.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Text(error ?? 'Unknown error', textAlign: TextAlign.center),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () {
                    main(); // simple retry
                  },
                  child: const Text('Retry initialization'),
                ),
              ],
            ),
          ),
        ),
      ),
      theme: AppTheme.lightTheme,
    );
  }
}

class ConvoAIApp extends StatefulWidget {
  const ConvoAIApp({Key? key}) : super(key: key);

  @override
  State<ConvoAIApp> createState() => _ConvoAIAppState();
}

class _ConvoAIAppState extends State<ConvoAIApp> {
  bool _showLanding = true; // 🆕 state flag

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mira',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _showLanding
          ? LandingPage(
              onContinue: () {
                setState(() {
                  _showLanding = false; // move to main app
                });
              },
            )
          : const MainNavigationScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// 🌐 Main Navigation
// ---------------------------------------------------------------------------

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({Key? key}) : super(key: key);

  @override
  State<MainNavigationScreen> createState() => MainNavigationScreenState();
}

class MainNavigationScreenState extends State<MainNavigationScreen>
    with SingleTickerProviderStateMixin {
  int currentIndex = 0;
  late AnimationController _animationController;

  final List<Widget> _screens = [
    const ChatScreen(),
    const HistoryScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Widget _buildNavItem(IconData icon, int index, String label) {
    final isSelected = currentIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          currentIndex = index;
        });
        _animationController
          ..reset()
          ..forward();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2196F3).withAlpha(25)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return Transform.scale(
                  scale: isSelected
                      ? 1.0 + (_animationController.value * 0.2)
                      : 1.0,
                  child: Icon(
                    icon,
                    color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
                    size: 28,
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2196F3) : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 420),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) {
          final inAnimation =
              CurvedAnimation(parent: animation, curve: Curves.easeOut);
          return FadeTransition(
            opacity: inAnimation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.06),
                end: Offset.zero,
              ).animate(inAnimation),
              child: child,
            ),
          );
        },
        child: SizedBox.expand(
          key: ValueKey<int>(currentIndex),
          child: _screens[currentIndex],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(13),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(Icons.mic, 0, "Chat"),
              _buildNavItem(Icons.history, 1, "History"),
            ],
          ),
        ),
      ),
    );
  }
}
