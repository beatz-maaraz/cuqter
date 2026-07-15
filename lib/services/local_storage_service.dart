import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

class LocalStorageService {
  /// Map message type to subfolder name
  static String _getSubfolderName(String fileType) {
    switch (fileType) {
      case 'image':
        return 'Cuqter Photo';
      case 'video':
        return 'Cuqter Video';
      case 'audio':
        return 'Cuqter Audio';
      case 'document':
      default:
        return 'Cuqter Document';
    }
  }

  /// Helper to get the Beatz/Cuqter/[FileType] directory path
  static Future<String?> getLocalFolderPath(String fileType) async {
    if (kIsWeb) return null;
    try {
      Directory? baseDir;
      if (Platform.isAndroid) {
        // Get app-specific external files dir: /storage/emulated/0/Android/data/[packageName]/files
        final extDir = await getExternalStorageDirectory();
        if (extDir != null) {
          String path = extDir.path;
          if (path.contains('/Android/data/')) {
            path = path.replaceAll('/Android/data/', '/Android/media/');
            if (path.endsWith('/files')) {
              path = path.substring(0, path.length - 6);
            }
          }
          baseDir = Directory(path);
        }
      } else {
        // iOS/Desktop documents directory
        baseDir = await getApplicationDocumentsDirectory();
      }

      if (baseDir == null) return null;

      final subfolder = _getSubfolderName(fileType);
      final String folderPath = '${baseDir.path}/Beatz/Cuqter/$subfolder';
      final Directory dir = Directory(folderPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return folderPath;
    } catch (e) {
      debugPrint('Error getting local folder path: $e');
      return null;
    }
  }

  /// Helper to extract filename from URL
  static String _getFileNameFromUrl(String url) {
    try {
      // Handle the case where the URL has a size or metadata suffix
      final String cleanUrl = url.split('|')[0];
      final Uri uri = Uri.parse(cleanUrl);
      String filename = uri.pathSegments.last;

      // Clean up double extensions if any (e.g. "my_video.mp4.mp4" -> "my_video.mp4")
      final List<String> parts = filename.split('.');
      if (parts.length > 2 && parts[parts.length - 1].toLowerCase() == parts[parts.length - 2].toLowerCase()) {
        filename = parts.sublist(0, parts.length - 1).join('.');
      }

      final int underscoreIdx = filename.indexOf('_');
      if (underscoreIdx != -1 && underscoreIdx < 15) {
        final prefix = filename.substring(0, underscoreIdx);
        if (RegExp(r'^\d+$').hasMatch(prefix)) {
          return filename.substring(underscoreIdx + 1);
        }
      }
      return filename;
    } catch (_) {
      return 'Shared_File';
    }
  }

  /// Get the local absolute file path inside the corresponding subfolder
  static Future<String?> getLocalFilePath(String url, String fileType, {String? originalFileName}) async {
    if (kIsWeb) return null;
    final folderPath = await getLocalFolderPath(fileType);
    if (folderPath == null) return null;
    final fileName = originalFileName ?? _getFileNameFromUrl(url);
    return '$folderPath/$fileName';
  }

  /// Check if file is already saved locally on device
  static Future<String?> checkFileExists(String url, String fileType, {String? originalFileName}) async {
    if (kIsWeb) return null;
    try {
      final path = await getLocalFilePath(url, fileType, originalFileName: originalFileName);
      if (path != null && await File(path).exists()) {
        return path;
      }
    } catch (e) {
      debugPrint('Error checking local file: $e');
    }
    return null;
  }

  /// Save raw bytes locally in Beatz/Cuqter/[FileType] folder
  static Future<String?> saveFileLocally(String fileName, Uint8List bytes, String fileType) async {
    if (kIsWeb) return null;
    try {
      final folderPath = await getLocalFolderPath(fileType);
      if (folderPath == null) return null;
      // Strip underscore prefix if present to keep it clean
      String cleanName = fileName;
      final int underscoreIdx = fileName.indexOf('_');
      if (underscoreIdx != -1 && underscoreIdx < 15) {
        final prefix = fileName.substring(0, underscoreIdx);
        if (RegExp(r'^\d+$').hasMatch(prefix)) {
          cleanName = fileName.substring(underscoreIdx + 1);
        }
      }
      
      final String path = '$folderPath/$cleanName';
      final file = File(path);
      await file.writeAsBytes(bytes);
      debugPrint('File saved locally at: $path');
      return path;
    } catch (e) {
      debugPrint('Error saving file locally: $e');
      return null;
    }
  }

  /// Download file from URL with progress reporting and save to Beatz/Cuqter/[FileType] folder
  static Future<String?> downloadAndSaveFile(
    String url,
    String fileType,
    void Function(double progress) onProgress,
    {String? originalFileName}
  ) async {
    if (kIsWeb) return null;
    try {
      final localPath = await getLocalFilePath(url, fileType, originalFileName: originalFileName);
      if (localPath == null) return null;

      final cleanUrl = url.split('|')[0];
      // Decode and encode to handle raw spaces
      final String decodedUrl = Uri.decodeFull(cleanUrl.trim());
      final String encodedUrl = Uri.encodeFull(decodedUrl);

      final client = http.Client();
      final request = http.Request('GET', Uri.parse(encodedUrl));
      final response = await client.send(request);

      final total = response.contentLength ?? 0;
      int downloaded = 0;
      
      final file = File(localPath);
      final sink = file.openWrite();

      await response.stream.listen(
        (chunk) {
          downloaded += chunk.length;
          if (total > 0) {
            onProgress(downloaded / total);
          }
          sink.add(chunk);
        },
        onDone: () async {
          await sink.flush();
          await sink.close();
          debugPrint('File downloaded and saved at: $localPath');
        },
        onError: (e) {
          debugPrint('Stream error in download: $e');
        },
        cancelOnError: true,
      ).asFuture();

      // Check if file was written successfully
      if (await file.exists() && await file.length() > 0) {
        return localPath;
      }
      return null;
    } catch (e) {
      debugPrint('Error downloading and saving file: $e');
      return null;
    }
  }
}
