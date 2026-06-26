import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:cuqter/utils/cloudinary_config.dart';

class CloudinaryService {
  /// Upload image to Cloudinary (unsigned upload)
  /// Returns a Map containing:
  /// - 'url': the secure URL of the uploaded image
  /// - 'public_id': the public ID of the uploaded image
  static Future<Map<String, String>?> uploadImage(Uint8List fileBytes) async {
    try {
      final String cloudName = CloudinaryConfig.cloudName;
      final String uploadPreset = CloudinaryConfig.uploadPreset;

      if (cloudName == 'YOUR_CLOUD_NAME' ||
          cloudName.isEmpty ||
          uploadPreset == 'YOUR_UPLOAD_PRESET' ||
          uploadPreset.isEmpty) {
        debugPrint('Cloudinary credentials/preset not set. Please update lib/utils/cloudinary_config.dart.');
        return null;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = 'profile';
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: 'profile_picture.jpg',
        ),
      );

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        return {
          'url': json['secure_url'] as String,
          'public_id': json['public_id'] as String,
        };
      } else {
        var errorResponse = await response.stream.bytesToString();
        debugPrint('Cloudinary upload failed: $errorResponse');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
      return null;
    }
  }


  /// Upload any file to Cloudinary with custom folder and resource type
  /// resourceType can be 'image', 'video', or 'raw'
  static Future<Map<String, String>?> uploadFile({
    required Uint8List fileBytes,
    required String folderPath,
    required String fileName,
    required String resourceType,
    void Function(double progress)? onProgress,
  }) async {
    try {
      final String cloudName = CloudinaryConfig.cloudName;
      final String uploadPreset = CloudinaryConfig.uploadPreset;

      if (cloudName == 'YOUR_CLOUD_NAME' ||
          cloudName.isEmpty ||
          uploadPreset == 'YOUR_UPLOAD_PRESET' ||
          uploadPreset.isEmpty) {
        debugPrint('Cloudinary credentials/preset not set. Please update lib/utils/cloudinary_config.dart.');
        return null;
      }

      var request = MultipartRequestWithProgress(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/$resourceType/upload'),
        onProgress: (sent, total) {
          if (onProgress != null && total > 0) {
            onProgress(sent / total);
          }
        },
      );

      request.fields['upload_preset'] = uploadPreset;
      request.fields['folder'] = folderPath;
      
      String publicId = fileName;
      if (resourceType != 'raw') {
        final int lastDot = fileName.lastIndexOf('.');
        if (lastDot != -1) {
          publicId = fileName.substring(0, lastDot);
        }
      }
      request.fields['public_id'] = publicId;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          fileBytes,
          filename: fileName,
        ),
      );

      var response = await request.send();
      if (response.statusCode == 200 || response.statusCode == 201) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);
        return {
          'url': json['secure_url'] as String,
          'public_id': json['public_id'] as String,
        };
      } else {
        var errorResponse = await response.stream.bytesToString();
        debugPrint('Cloudinary file upload failed: $errorResponse');
        return null;
      }
    } catch (e) {
      debugPrint('Cloudinary file upload error: $e');
      return null;
    }
  }

  /// Delete image from Cloudinary using the Admin/Upload destroy API with signature
  static Future<bool> deleteImage(String publicId) async {
    try {
      final String cloudName = CloudinaryConfig.cloudName;
      final String apiKey = CloudinaryConfig.apiKey;
      final String apiSecret = CloudinaryConfig.apiSecret;

      if (cloudName == 'YOUR_CLOUD_NAME' || apiKey == 'YOUR_API_KEY' || apiSecret == 'YOUR_API_SECRET') {
        debugPrint('Cloudinary credentials not set, skipping deletion.');
        return false;
      }

      final int timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      
      // Parameters to sign (sorted alphabetically)
      final Map<String, dynamic> params = {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
      };

      // Generate signature
      final String signature = _generateSignature(params, apiSecret);

      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy'),
        body: {
          'public_id': publicId,
          'timestamp': timestamp.toString(),
          'api_key': apiKey,
          'signature': signature,
        },
      );

      if (response.statusCode == 200) {
        var responseData = jsonDecode(response.body);
        if (responseData['result'] == 'ok') {
          debugPrint('Cloudinary deletion successful for $publicId');
          return true;
        } else {
          debugPrint('Cloudinary deletion result not ok: ${response.body}');
          return false;
        }
      } else {
        debugPrint('Cloudinary deletion failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('Cloudinary deletion error: $e');
      return false;
    }
  }

  static String _generateSignature(Map<String, dynamic> params, String apiSecret) {
    var sortedKeys = params.keys.toList()..sort();
    List<String> parts = [];
    for (var key in sortedKeys) {
      parts.add("$key=${params[key]}");
    }
    String parameterString = parts.join("&");
    String stringToSign = "$parameterString$apiSecret";
    
    var bytes = utf8.encode(stringToSign);
    return sha1.convert(bytes).toString();
  }
}

class MultipartRequestWithProgress extends http.MultipartRequest {
  final void Function(int bytesSent, int totalBytes) onProgress;

  MultipartRequestWithProgress(
    String method,
    Uri url, {
    required this.onProgress,
  }) : super(method, url);

  @override
  http.ByteStream finalize() {
    final byteStream = super.finalize();
    final totalBytes = contentLength;
    int bytesSent = 0;

    final transformer = StreamTransformer<List<int>, List<int>>.fromHandlers(
      handleData: (data, sink) {
        bytesSent += data.length;
        onProgress(bytesSent, totalBytes);
        sink.add(data);
      },
    );

    return http.ByteStream(byteStream.transform(transformer));
  }
}
