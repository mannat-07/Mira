# Environment Variables Setup Guide

This guide explains how to configure environment variables for the ConvoAI application.

## 🔐 Security Notice

**IMPORTANT:** Never commit `.env` files or any files containing real API keys, tokens, or secrets to version control!

All sensitive data has been moved to environment variables to keep your credentials secure.

## 📋 Prerequisites

Before you begin, make sure you have the following:

1. **Gemini API Key**: Get your free API key from [Google AI Studio](https://makersuite.google.com/app/apikey)
2. **Firebase Project**: Your Firebase configuration from [Firebase Console](https://console.firebase.google.com/)
3. **Agora Credentials** (for backend): Get from [Agora Console](https://console.agora.io/)

## 🚀 Setup Instructions

### Flutter Application Setup

1. **Copy the example environment file:**
   ```bash
   cd my_app
   cp .env.example .env
   ```

2. **Edit the `.env` file and fill in your actual values:**
   ```bash
   nano .env
   # or use your preferred text editor
   ```

3. **Required environment variables:**
   - `GEMINI_API_KEY` - Your Gemini API key for LLM functionality
   - `FIREBASE_WEB_API_KEY`, `FIREBASE_WEB_APP_ID`, etc. - Firebase configuration for web platform
   - `FIREBASE_ANDROID_API_KEY`, `FIREBASE_ANDROID_APP_ID`, etc. - Firebase configuration for Android
   - `FIREBASE_IOS_API_KEY`, `FIREBASE_IOS_APP_ID`, etc. - Firebase configuration for iOS
   - And similar for macOS and Windows platforms

4. **Install dependencies:**
   ```bash
   flutter pub get
   ```

5. **Run the app:**
   ```bash
   flutter run
   ```

### Backend Functions Setup

1. **Navigate to the functions directory:**
   ```bash
   cd my_app/backend/functions
   ```

2. **Copy the example environment file:**
   ```bash
   cp .env.example .env
   ```

3. **Edit the `.env` file and fill in your Agora credentials:**
   ```bash
   nano .env
   ```

4. **Required environment variables:**
   - `AGORA_APP_ID` - Your Agora application ID
   - `AGORA_TOKEN` - Your Agora authentication token
   - `AGORA_CERTIFICATE` - Your Agora certificate
   - `AGORA_AI_BASE_URL` - Agora AI API base URL (if using Agora AI services)

5. **Install dependencies:**
   ```bash
   npm install
   ```

6. **Test locally:**
   ```bash
   npm run serve
   ```

7. **Deploy to Firebase:**
   ```bash
   npm run deploy
   ```

## 📝 How It Works

### Flutter (Dart)

The application uses the `flutter_dotenv` package to load environment variables:

- **Loading**: Environment variables are loaded in `lib/main.dart` at app startup
- **Accessing**: Use `dotenv.env['VARIABLE_NAME']` to access values
- **Files affected**:
  - `lib/constants/api_keys.dart` - Gemini API key
  - `lib/firebase_options.dart` - Firebase configuration
  - `lib/main.dart` - Initializes dotenv

### Backend (Node.js)

The backend uses the `dotenv` package for environment variables:

- **Loading**: Environment variables are loaded in `backend/functions/index.js`
- **Accessing**: Use `process.env.VARIABLE_NAME` to access values
- **Fallback**: Can also use Firebase Functions config as a fallback
- **Files affected**:
  - `backend/functions/index.js` - Main functions file

## 🔍 What Was Changed

### Removed Hardcoded Values:

1. **Gemini API Key**: Previously hardcoded in `lib/constants/api_keys.dart`
2. **Firebase Configuration**: All platform-specific API keys in `lib/firebase_options.dart`
3. **Agora Credentials**: App ID, token, and certificate in `backend/functions/index.js`

### Added Security:

1. **Environment Variables**: All sensitive data moved to `.env` files
2. **Git Ignore**: Updated `.gitignore` to exclude:
   - `.env` and `.env.*` files (except `.env.example`)
   - `node_modules/`
   - `venv/`, `__pycache__/`
   - Firebase service configuration files with secrets

## 🛠️ Troubleshooting

### "Could not load .env file" Error

**Problem**: The app can't find the `.env` file.

**Solution**:
1. Make sure you've created the `.env` file from `.env.example`
2. Verify the file is in the correct location:
   - Flutter: `my_app/.env`
   - Backend: `my_app/backend/functions/.env`
3. Check that the file name is exactly `.env` (with the leading dot)

### "Invalid API Key" Error

**Problem**: API key is not valid or not set.

**Solution**:
1. Open your `.env` file
2. Verify you've replaced placeholder values with real API keys
3. Make sure there are no extra spaces or quotes around the values
4. Restart the application after changing `.env` values

### Firebase Initialization Failed

**Problem**: Firebase can't initialize with the provided credentials.

**Solution**:
1. Verify all Firebase environment variables are set correctly
2. Check that you're using the correct configuration for your platform
3. Get fresh configuration from [Firebase Console](https://console.firebase.google.com/)
4. Make sure the Firebase project is properly set up

### Backend Functions Not Working

**Problem**: Backend functions can't access environment variables.

**Solution**:
1. For local development: Make sure `.env` file exists in `backend/functions/`
2. For production: Set Firebase Functions config:
   ```bash
   firebase functions:config:set agora.app_id="YOUR_APP_ID"
   firebase functions:config:set agora.token="YOUR_TOKEN"
   firebase functions:config:set agora.certificate="YOUR_CERTIFICATE"
   ```

## 📚 Additional Resources

- [Flutter dotenv Documentation](https://pub.dev/packages/flutter_dotenv)
- [Node.js dotenv Documentation](https://www.npmjs.com/package/dotenv)
- [Firebase Functions Environment Configuration](https://firebase.google.com/docs/functions/config-env)
- [12-Factor App Methodology](https://12factor.net/config)

## ✅ Verification Checklist

Before committing your code, verify:

- [ ] `.env` file is listed in `.gitignore`
- [ ] No API keys or secrets in code files
- [ ] `.env.example` files are present with placeholder values
- [ ] All team members have created their own `.env` files
- [ ] Application runs successfully with environment variables
- [ ] Backend functions work with environment variables

## 🤝 Team Collaboration

When working with a team:

1. **Never share `.env` files directly** - Instead:
   - Share the `.env.example` file (already in the repo)
   - Communicate separately (Slack, email, password manager) to share actual keys
   
2. **Each developer should**:
   - Create their own `.env` file from `.env.example`
   - Use their own development API keys when possible
   
3. **For production**:
   - Use Firebase Functions config or Cloud Secret Manager
   - Set up proper access controls
   - Rotate keys regularly

---

**Remember:** Security is everyone's responsibility! Keep your credentials safe. 🔒
