import 'package:shared_preferences/shared_preferences.dart';

class NetworkUsageService {
  static Future<void> trackMessageSent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('net_messages_sent') ?? 0;
      await prefs.setInt('net_messages_sent', current + 1);
    } catch (_) {}
  }

  static Future<void> trackMessageReceived() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('net_messages_received') ?? 0;
      await prefs.setInt('net_messages_received', current + 1);
    } catch (_) {}
  }

  static Future<void> trackMediaSent(int bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('net_media_sent_bytes') ?? 0;
      await prefs.setInt('net_media_sent_bytes', current + bytes);
    } catch (_) {}
  }

  static Future<void> trackMediaReceived(int bytes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('net_media_received_bytes') ?? 0;
      await prefs.setInt('net_media_received_bytes', current + bytes);
    } catch (_) {}
  }

  static Future<void> trackCall({int durationMinutes = 1}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = prefs.getInt('net_calls_count') ?? 0;
      final duration = prefs.getInt('net_calls_duration') ?? 0;
      await prefs.setInt('net_calls_count', count + 1);
      await prefs.setInt('net_calls_duration', duration + durationMinutes);
    } catch (_) {}
  }

  static Future<void> trackDbSync() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final current = prefs.getInt('net_db_syncs') ?? 0;
      await prefs.setInt('net_db_syncs', current + 1);
    } catch (_) {}
  }
}
