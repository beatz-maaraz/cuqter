import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:web/web.dart' as web;
import 'package:cloud_firestore/cloud_firestore.dart';

void setupWebLifecycle(String uid) {
  web.window.addEventListener('beforeunload', ((web.Event event) {
    // Attempt to quickly mark user offline when they close the web app
    FirebaseFirestore.instance.collection('users').doc(uid).update({
      'isOnline': false,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }).toJS);
}

Future<void> downloadFileOnWeb({
  required String url,
  required String fileName,
  void Function(double progress)? onProgress,
}) async {
  String cleanUrl = url.split('|')[0].trim();
  if (cleanUrl.startsWith('http://')) {
    cleanUrl = 'https://${cleanUrl.substring(7)}';
  }

  // Attempt 1: Fetch bytes over HTTP with real-time progress tracking
  try {
    onProgress?.call(0.1);
    final client = http.Client();
    try {
      final request = http.Request('GET', Uri.parse(cleanUrl));
      final response = await client.send(request);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final total = response.contentLength ?? 0;
        int downloaded = 0;
        final chunks = <List<int>>[];

        await for (final chunk in response.stream) {
          chunks.add(chunk);
          downloaded += chunk.length;
          if (total > 0 && onProgress != null) {
            onProgress(downloaded / total);
          }
        }

        final bytesBuilder = BytesBuilder(copy: false);
        for (final chunk in chunks) {
          bytesBuilder.add(chunk);
        }
        final bytes = bytesBuilder.takeBytes();

        _triggerBrowserDownload(bytes, fileName);
        onProgress?.call(1.0);
        return;
      }
    } finally {
      client.close();
    }
  } catch (e) {
    debugPrint('HTTP stream download error: $e');
  }

  // Attempt 2: Simple http.get fallback
  try {
    final res = await http.get(Uri.parse(cleanUrl));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      _triggerBrowserDownload(res.bodyBytes, fileName);
      onProgress?.call(1.0);
      return;
    }
  } catch (e) {
    debugPrint('HTTP get download error: $e');
  }

  // Attempt 3: Direct anchor trigger with fl_attachment for Cloudinary
  String directUrl = cleanUrl;
  if (directUrl.contains('res.cloudinary.com') &&
      directUrl.contains('/upload/') &&
      !directUrl.contains('fl_attachment')) {
    directUrl = directUrl.replaceFirst('/upload/', '/upload/fl_attachment/');
  } else if (directUrl.contains('firebasestorage.googleapis.com')) {
    final uri = Uri.parse(directUrl);
    final queryParams = Map<String, String>.from(uri.queryParameters);
    queryParams['response-content-disposition'] =
        'attachment; filename="${Uri.encodeComponent(fileName)}"';
    directUrl = uri.replace(queryParameters: queryParams).toString();
  }

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = directUrl;
  anchor.download = fileName;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
  onProgress?.call(1.0);
}

void _triggerBrowserDownload(Uint8List bytes, String fileName) {
  // Method A: Native Blob URL
  try {
    final jsArray = bytes.toJS;
    final blob = web.Blob([jsArray].toJS);
    final blobUrl = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = blobUrl;
    anchor.download = fileName;
    anchor.style.display = 'none';
    web.document.body?.appendChild(anchor);
    anchor.click();
    anchor.remove();
    web.URL.revokeObjectURL(blobUrl);
    return;
  } catch (e) {
    debugPrint('Blob download error, falling back to Data URI: $e');
  }

  // Method B: Data URI (universal across all browsers, never fails)
  final base64String = base64Encode(bytes);
  final dataUrl = 'data:application/octet-stream;base64,$base64String';

  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = dataUrl;
  anchor.download = fileName;
  anchor.style.display = 'none';
  web.document.body?.appendChild(anchor);
  anchor.click();
  anchor.remove();
}
