const functions = require("firebase-functions");
const admin = require("firebase-admin");
const axios = require("axios");

// Load environment variables from .env file in development
// In production, use Firebase Functions config or Cloud Secret Manager
if (process.env.NODE_ENV !== 'production') {
  require('dotenv').config();
}

if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Agora configuration - Load from environment variables
// For Firebase Functions, you can also use: firebase functions:config:set agora.app_id="YOUR_APP_ID"
const AGORA_APP_ID = process.env.AGORA_APP_ID || functions.config().agora?.app_id || '';
const AGORA_TOKEN = process.env.AGORA_TOKEN || functions.config().agora?.token || '';
const AGORA_CERTIFICATE = process.env.AGORA_CERTIFICATE || functions.config().agora?.certificate || '';
const AGORA_AI_BASE_URL = process.env.AGORA_AI_BASE_URL || 'https://api.agora.io/v1/ai';

// Save conversation transcript to Firestore
exports.saveConversation = functions.https.onCall(async (data, context) => {
  const { messages, userId } = data;

  // Validate input
  if (!messages || !Array.isArray(messages) || messages.length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Messages must be a non-empty array."
    );
  }

  if (!userId) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "User ID is required."
    );
  }

  try {
    const conversationRef = db.collection("conversations").doc();
    const conversationData = {
      userId: userId,
      messages: messages,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: new Date().toISOString(),
    };

    await conversationRef.set(conversationData);

    console.log(`Conversation saved: ${conversationRef.id}`);
    return { 
      success: true, 
      conversationId: conversationRef.id,
      message: "Conversation saved successfully"
    };
  } catch (error) {
    console.error("Error saving conversation:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to save conversation."
    );
  }
});

// Generate AI response using Agora AI API
exports.generateAIResponse = functions.https.onCall(async (data, context) => {
  const { userInput, conversationHistory } = data;

  if (!userInput || typeof userInput !== 'string') {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "User input must be a non-empty string."
    );
  }

  try {
    // Prepare conversation context
    const messages = [
      {
        role: 'system',
        content: 'You are a helpful AI assistant in a voice conversation app. Keep responses natural, concise, and conversational. Limit responses to 1-2 sentences for better voice experience.'
      },
      ...(conversationHistory || []).slice(-10), // Keep last 10 messages for context
      {
        role: 'user',
        content: userInput
      }
    ];

    // Call Agora AI API (placeholder - replace with actual Agora AI endpoint)
    const aiResponse = await callAgoraAI(messages);

    return {
      success: true,
      response: aiResponse,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    console.error("Error generating AI response:", error);
    
    // Return fallback response
    const fallbackResponse = generateFallbackResponse(userInput);
    return {
      success: true,
      response: fallbackResponse,
      timestamp: new Date().toISOString(),
      isFallback: true
    };
  }
});

// Synthesize speech using Agora TTS
exports.synthesizeSpeech = functions.https.onCall(async (data, context) => {
  const { text, voice, speechRate, volume } = data;

  if (!text || typeof text !== 'string') {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Text must be a non-empty string."
    );
  }

  try {
    const audioUrl = await callAgoraTTS({
      text: text,
      voice: voice || 'en-US-AriaNeural',
      speed: speechRate || 1.0,
      volume: volume || 1.0
    });

    return {
      success: true,
      audioUrl: audioUrl,
      text: text,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    console.error("Error synthesizing speech:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to synthesize speech."
    );
  }
});

// Process speech-to-text
exports.processSpeechToText = functions.https.onCall(async (data, context) => {
  const { audioData, format, sampleRate, language } = data;

  if (!audioData) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Audio data is required."
    );
  }

  try {
    const transcription = await callAgoraSTT({
      audioData: audioData,
      format: format || 'wav',
      sampleRate: sampleRate || 16000,
      language: language || 'en-US'
    });

    return {
      success: true,
      transcription: transcription,
      timestamp: new Date().toISOString()
    };
  } catch (error) {
    console.error("Error processing speech to text:", error);
    throw new functions.https.HttpsError(
      "internal",
      "Failed to process speech to text."
    );
  }
});

// Helper function to call Agora AI API
async function callAgoraAI(messages) {
  try {
    const response = await axios.post(`${AGORA_AI_BASE_URL}/chat/completions`, {
      model: 'agora-conversational-v1',
      messages: messages,
      max_tokens: 150,
      temperature: 0.7,
      stream: false
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AGORA_TOKEN}`,
        'X-Agora-App-ID': AGORA_APP_ID
      }
    });

    return response.data.choices[0].message.content.trim();
  } catch (error) {
    console.error('Agora AI API error:', error.response?.data || error.message);
    throw error;
  }
}

// Helper function to call Agora TTS API
async function callAgoraTTS(params) {
  try {
    const response = await axios.post(`${AGORA_AI_BASE_URL}/tts/synthesize`, {
      text: params.text,
      voice: params.voice,
      speed: params.speed,
      volume: params.volume,
      format: 'wav',
      sample_rate: 16000
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AGORA_TOKEN}`,
        'X-Agora-App-ID': AGORA_APP_ID
      },
      responseType: 'arraybuffer'
    });

    // In production, you would upload this to Cloud Storage and return the URL
    // For now, return a placeholder URL
    return 'https://example.com/synthesized-audio.wav';
  } catch (error) {
    console.error('Agora TTS API error:', error.response?.data || error.message);
    throw error;
  }
}

// Helper function to call Agora STT API
async function callAgoraSTT(params) {
  try {
    const response = await axios.post(`${AGORA_AI_BASE_URL}/stt/transcribe`, {
      audio_data: params.audioData,
      format: params.format,
      sample_rate: params.sampleRate,
      language: params.language
    }, {
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${AGORA_TOKEN}`,
        'X-Agora-App-ID': AGORA_APP_ID
      }
    });

    return response.data.transcript || '';
  } catch (error) {
    console.error('Agora STT API error:', error.response?.data || error.message);
    throw error;
  }
}

// Generate fallback response when AI API is unavailable
function generateFallbackResponse(userInput) {
  const input = userInput.toLowerCase();
  
  if (input.includes('hello') || input.includes('hi')) {
    return "Hello! It's great to chat with you. How are you doing today?";
  }
  
  if (input.includes('weather')) {
    return "I'd love to help with weather information, but I don't have access to current weather data. Is there something else I can help you with?";
  }
  
  if (input.includes('time')) {
    return "I don't have access to the current time, but I'm here to chat about other things. What's on your mind?";
  }
  
  if (input.includes('joke')) {
    return "Here's one for you: Why don't scientists trust atoms? Because they make up everything!";
  }
  
  const fallbackResponses = [
    "I understand what you're saying. Could you tell me more about that?",
    "That's interesting. What would you like to know?",
    "I'm here to help. How can I assist you today?",
    "Thanks for sharing that with me. What else is on your mind?",
    "I see. Is there anything specific you'd like to discuss?"
  ];
  
  const randomIndex = Math.floor(Math.random() * fallbackResponses.length);
  return fallbackResponses[randomIndex];
}
