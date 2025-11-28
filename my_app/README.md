# ConvoAI - Voice Conversation App

A Flutter-based AI voice conversation application powered by Google Gemini LLM, Firebase, and Agora for real-time voice communication.

## 🚀 Features

- 🎤 **Voice Conversations**: Real-time voice input and AI responses
- 🤖 **AI-Powered**: Integrated with Google Gemini 2.0 Flash LLM
- 💬 **Chat History**: Persistent conversation storage with Firebase Firestore
- 🔊 **Text-to-Speech**: AI responses converted to natural speech
- 🎨 **Modern UI**: Clean, intuitive interface with smooth animations
- 🔐 **Secure**: All credentials managed via environment variables

## 📋 Prerequisites

Before you begin, ensure you have:

- **Flutter SDK** (>=3.0.0)
- **Firebase Project** - [Create one here](https://console.firebase.google.com/)
- **Gemini API Key** - [Get it free here](https://makersuite.google.com/app/apikey)
- **Agora Credentials** (for backend) - [Sign up here](https://console.agora.io/)

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

📚 **For detailed setup instructions**, see [ENV_SETUP_GUIDE.md](./ENV_SETUP_GUIDE.md)

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

## 🔐 Security Best Practices

- ✅ **Never commit `.env` files** to version control
- ✅ All sensitive credentials are in `.env` and `.gitignore`d
- ✅ Use `.env.example` as a template for team members
- ✅ Rotate API keys regularly
- ✅ Use Firebase security rules in production

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
- Agora SDK
- Axios

## 📝 Environment Variables

All sensitive data is managed through environment variables:

| Variable | Description | Required |
|----------|-------------|----------|
| `GEMINI_API_KEY` | Google Gemini API key | ✅ |
| `FIREBASE_WEB_API_KEY` | Firebase Web API key | ✅ |
| `FIREBASE_ANDROID_API_KEY` | Firebase Android API key | ✅ |
| `FIREBASE_IOS_API_KEY` | Firebase iOS API key | ✅ |
| `AGORA_APP_ID` | Agora application ID | Backend only |
| `AGORA_TOKEN` | Agora auth token | Backend only |

See [ENV_SETUP_GUIDE.md](./ENV_SETUP_GUIDE.md) for the complete list and setup instructions.

## 🐛 Troubleshooting

### "Could not load .env file" Error
- Ensure `.env` file exists in the root directory
- Verify it's named exactly `.env` (with the dot)
- Check that it contains all required variables

### Firebase Initialization Failed
- Verify all Firebase environment variables are correct
- Check Firebase console for correct credentials
- Ensure the Firebase project is properly configured

### API Key Issues
- Make sure API keys have no extra spaces
- Verify the keys are valid and active
- Check API key restrictions in Google Cloud Console

For more troubleshooting help, see [ENV_SETUP_GUIDE.md](./ENV_SETUP_GUIDE.md#-troubleshooting)

## 📚 Documentation

- [Environment Setup Guide](./ENV_SETUP_GUIDE.md) - Detailed setup instructions
- [Flutter Documentation](https://docs.flutter.dev/)
- [Firebase Documentation](https://firebase.google.com/docs)
- [Gemini API Documentation](https://ai.google.dev/docs)

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. **Never commit `.env` files or credentials**
4. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
5. Push to the branch (`git push origin feature/AmazingFeature`)
6. Open a Pull Request

## 📄 License

This project is licensed under the MIT License.

## 🆘 Support

If you encounter any issues or have questions:
1. Check the [ENV_SETUP_GUIDE.md](./ENV_SETUP_GUIDE.md)
2. Review existing issues in the repository
3. Create a new issue with detailed information

---

**Remember**: Keep your credentials safe and never commit sensitive data! 🔒

