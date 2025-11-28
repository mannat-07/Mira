# Mira - Voice Conversation App

A Flutter-based AI voice conversation application powered by Google Gemini LLM, Firebase, and Agora for real-time voice communication.

<p align="center">
  <img src="/Mira.gif" alt="App Demo" width="400" />
</p>


## 🚀 Features

- 🎤 **Voice Conversations**: Real-time voice input and AI responses
- 🤖 **AI-Powered**: Integrated with Google Gemini 2.0 Flash LLM
- 💬 **Chat History**: Persistent conversation storage with Firebase Firestore
- 🔊 **Text-to-Speech**: AI responses converted to natural speech
- 🎨 **Modern UI**: Clean, intuitive interface with smooth animations
- 🔐 **Secure**: All credentials managed via environment variables

## 🔧 Quick Setup

### 1. Clone the Repository

```bash
git clone <repository-url>
cd convoai/my_app
```

### 2. Set Up Environment Variables

**IMPORTANT**: Copy the example environment file and fill in your credentials:

```bash
# Copy the template
cp .env.example .env

# Edit with your actual credentials
nano .env  # or use your preferred editor
```

Fill in all the required values in `.env`:
- `GEMINI_API_KEY` - Your Google Gemini API key
- `FIREBASE_*` - All Firebase configuration values for each platform
- See `.env.example` for the complete list

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
# For development
flutter run

# For specific platform
flutter run -d chrome    # Web
flutter run -d android   # Android
flutter run -d ios       # iOS
```

## 🏗️ Backend Setup (Optional)

If you need to use the Firebase Cloud Functions backend:

```bash
cd backend/functions
cp .env.example .env
# Fill in your Agora credentials
npm install
npm run serve  # Test locally
npm run deploy # Deploy to Firebase
```

## 📁 Project Structure

```
lib/
├── constants/          # API keys, theme, colors, styles
├── models/            # Data models (Message, Conversation, etc.)
├── providers/         # State management (Riverpod)
├── screens/           # UI screens (Chat, History, Settings)
├── services/          # Business logic (LLM, Firebase, Voice)
├── widgets/           # Reusable UI components
└── main.dart          # App entry point

backend/
└── functions/         # Firebase Cloud Functions
    └── index.js       # Backend API endpoints
```

## 🛠️ Tech Stack

**Frontend:**
- Flutter & Dart
- Riverpod (State Management)
- Firebase Core & Firestore
- Google Generative AI (Gemini)
- Speech-to-Text & Flutter TTS
- flutter_dotenv (Environment Variables)

**Backend:**
- Firebase Cloud Functions
- Node.js
- Axios

## 📝 Environment Variables

All sensitive data is managed through environment variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key | ✅ |
| `FIREBASE_WEB_API_KEY` | Firebase Web API key | ✅ |
| `FIREBASE_ANDROID_API_KEY` | Firebase Android API key | ✅ |
| `FIREBASE_IOS_API_KEY` | Firebase iOS API key | ✅ |

**Remember**: Keep your credentials safe and never commit sensitive data! 🔒

