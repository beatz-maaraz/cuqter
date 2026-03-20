import 'dart:convert';
import 'package:http/http.dart' as http;

class ChatService {
  // Replace with your actual Python server URL
  static const String _baseUrl = 'http://localhost:8000';

  /// Send a chat message to the Python server
  static Future<String> sendMessage({
    required String message,
    required String apiKey,
    String model = 'gemini-pro',
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'message': message,
          'api_key': apiKey,
          'model': model,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['reply'] ?? 'No response';
      } else if (response.statusCode == 401) {
        throw 'Invalid or expired API key';
      } else if (response.statusCode == 400) {
        final data = jsonDecode(response.body);
        throw data['detail'] ?? 'Bad request';
      } else if (response.statusCode == 429) {
        throw 'Rate limit exceeded. Please try again later.';
      } else {
        throw 'Server error: ${response.statusCode}';
      }
    } catch (e) {
      throw 'Error: $e';
    }
  }

  /// Check server health
  static Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
