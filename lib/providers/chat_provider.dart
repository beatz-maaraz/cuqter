import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_generative_ai/google_generative_ai.dart';

class ChatProvider extends ChangeNotifier {
  final List<Map<String, String>> _messages = [];
  bool _isLoading = false;

  // TOGGLE THIS: 
  // - useDirectApiKey = true: Talks to Google AI (Online)
  // - useDirectApiKey = false: Talks to Your Computer (Online)
  // - isOfflineMode = true: Talks to Local AI (Offline via Ollama)
  static const bool useDirectApiKey = true;
  static const bool isOfflineMode = false;

  // Configuration for Your Python Server
  // Using physical IP of this Windows machine makes it accessible to Mobiles via Wi-Fi as well as Windows
  static const String _serverUrl = "http://192.168.217.1:8000"; 
  // static const String _serverUrl = "http://10.0.2.2:8000"; 

  // Configuration for Direct Gemini API
  static const String _geminiApiKey = "AIzaSyBRTAHDq_EltmgEo030MzDMj85QVxYv_Jw";
  GenerativeModel? _directModel;
  
  GenerativeModel _getDirectModel() {
    return _directModel ??= GenerativeModel(
      model: 'gemini-1.5-pro',
      apiKey: _geminiApiKey,
    );
  }

  List<Map<String, String>> get messages => _messages;
  bool get isLoading => _isLoading;

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    _messages.add({'role': 'user', 'text': text});
    _isLoading = true;
    notifyListeners();

    try {
      if (isOfflineMode) {
        await _sendOfflineServerMessage(text);
      } else if (useDirectApiKey) {
        await _sendDirectMessage(text);
      } else {
        await _sendServerMessage(text);
      }
    } catch (e) {
      _messages.add({
        'role': 'bot',
        'text': 'Error: Failed to connect. ($e)',
      });
      if (kDebugMode) print('Error sending message: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _sendDirectMessage(String text) async {
    try {
      final content = [Content.text(text)];
      final response = await _getDirectModel().generateContent(content);
      
      final responseText = response.text;
      if (responseText != null && responseText.trim().isNotEmpty) {
        _messages.add({'role': 'bot', 'text': responseText});
      } else {
        _messages.add({
          'role': 'bot', 
          'text': 'Empty response. This might happen if the prompt was blocked or could not be processed.'
        });
      }
    } catch (e) {
      if (e.toString().contains('API_KEY_INVALID')) {
        _messages.add({
          'role': 'bot',
          'text': 'Error: Invalid Gemini API Key. Please check the _geminiApiKey in chat_provider.dart.',
        });
      } else {
        rethrow; // Let sendMessage handle generic errors
      }
    }
  }

  Future<void> _sendServerMessage(String text) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/chat'),
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
      body: jsonEncode({'message': text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _messages.add({'role': 'bot', 'text': data['response']});
    } else {
      _messages.add({'role': 'bot', 'text': 'Backend Error: ${response.statusCode}'});
    }
  }

  Future<void> _sendOfflineServerMessage(String text) async {
    final response = await http.post(
      Uri.parse('$_serverUrl/offline-chat'),
      headers: {
        'Content-Type': 'application/json',
        'Cache-Control': 'no-cache, no-store, must-revalidate',
        'Pragma': 'no-cache',
        'Expires': '0',
      },
      body: jsonEncode({'message': text}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _messages.add({'role': 'bot', 'text': data['response']});
    } else {
      _messages.add({'role': 'bot', 'text': 'Offline AI Error: ${response.statusCode}'});
    }
  }

  void clearMessages() {
    _messages.clear();
    notifyListeners();
  }
}
