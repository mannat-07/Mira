import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../constants/styles.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback onContinue;
  const LandingPage({Key? key, required this.onContinue}) : super(key: key);

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.15)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              // 🟦 Animated primary-colored icon
              ScaleTransition(
                scale: _scaleAnimation,
                child: Icon(
                  Icons.graphic_eq,
                  size: 100,
                  color: AppColors.primary, // ✅ unified color theme
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Welcome to Mira',
                style: AppStyles.heading1.copyWith(color: AppColors.primary),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Your personal voice assistant.\nTap the mic, speak naturally, and chat effortlessly.',
                style: AppStyles.body2.copyWith(color: Colors.grey.shade700),
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: widget.onContinue,
                icon: const Icon(Icons.arrow_forward_ios_rounded,
                    color: Colors.white),
                label: const Text(
                  'Get Started',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
