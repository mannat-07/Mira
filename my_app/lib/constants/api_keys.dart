import 'package:flutter_dotenv/flutter_dotenv.dart';

/// API Keys Configuration
///
/// IMPORTANT: Get your free Gemini API key from:
/// https://makersuite.google.com/app/apikey
///
/// All API keys are now loaded from environment variables (.env file)
/// Never commit your .env file to version control!

class ApiKeys {
  // Gemini API key loaded from environment variable
  static String get geminiApiKey => dotenv.env['GEMINI_API_KEY'] ?? '';

  // Check if API key is configured
  static bool get isGeminiConfigured =>
      geminiApiKey.isNotEmpty && geminiApiKey != 'YOUR_GEMINI_API_KEY_HERE';
}
