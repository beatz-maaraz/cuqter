import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:cuqter/utils/cloudinary_config.dart';

/// Service class responsible for handling file uploads to Cloudinary.
class CloudinaryService {
  /// Uploads image bytes directly to Cloudinary using an unsigned upload preset.
  /// Returns the secure URL of the uploaded image if successful, or null otherwise.
  static Future<String?> uploadImage(Uint8List imageBytes, {String? folder}) async {
    try {
      final String cloudName = CloudinaryConfig.cloudName;
      final String uploadPreset = CloudinaryConfig.uploadPreset;
      final String apiKey = CloudinaryConfig.apiKey;

      if (cloudName.isEmpty || cloudName == 'your_cloud_name') {
        debugPrint('[CloudinaryService] Error: Cloud name is not configured.');
        return null;
      }

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      if (apiKey.isNotEmpty) {
        request.fields['api_key'] = apiKey;
      }

      if (folder != null && folder.isNotEmpty) {
        request.fields['folder'] = folder;
      }

      debugPrint('[CloudinaryService] Uploading image to Cloudinary ($cloudName)...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final String? secureUrl = jsonResponse['secure_url'] as String?;
        debugPrint('[CloudinaryService] Upload success! URL: $secureUrl');
        return secureUrl;
      } else {
        debugPrint('[CloudinaryService] Upload failed. Status Code: ${response.statusCode}');
        debugPrint('[CloudinaryService] Error Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[CloudinaryService] Exception during upload: $e');
      return null;
    }
  }

  /// Deletes an image from Cloudinary using its secure URL or public ID.
  /// Requires apiKey and apiSecret to be configured.
  static Future<bool> deleteImage(String imageUrl) async {
    try {
      final String cloudName = CloudinaryConfig.cloudName;
      final String apiKey = CloudinaryConfig.apiKey;
      final String apiSecret = CloudinaryConfig.apiSecret;

      if (cloudName.isEmpty || apiKey.isEmpty || apiSecret.isEmpty) {
        debugPrint('[CloudinaryService] Cannot delete image: Credentials not fully configured.');
        return false;
      }

      // Extract public ID from the Cloudinary URL
      final String? publicId = _extractPublicId(imageUrl);
      if (publicId == null) {
        debugPrint('[CloudinaryService] Cannot delete image: Could not extract public ID from URL.');
        return false;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final Map<String, String> params = {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
      };

      final signature = _generateSignature(params, apiSecret);

      final url = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/destroy');
      
      final response = await http.post(url, body: {
        'public_id': publicId,
        'timestamp': timestamp.toString(),
        'api_key': apiKey,
        'signature': signature,
      });

      if (response.statusCode == 200) {
        final Map<String, dynamic> jsonResponse = jsonDecode(response.body);
        final String? result = jsonResponse['result'] as String?;
        if (result == 'ok') {
          debugPrint('[CloudinaryService] Image deleted successfully: $publicId');
          return true;
        } else {
          debugPrint('[CloudinaryService] Image deletion returned result: $result');
          return false;
        }
      } else {
        debugPrint('[CloudinaryService] Image deletion failed. Status: ${response.statusCode}, Body: ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('[CloudinaryService] Exception during deletion: $e');
      return false;
    }
  }

  /// Extracts the public ID of a Cloudinary image from its URL.
  static String? _extractPublicId(String url) {
    try {
      if (!url.startsWith('http')) return null;
      
      final uri = Uri.parse(url);
      final pathSegments = uri.pathSegments;
      if (pathSegments.isEmpty) return null;

      final uploadIndex = pathSegments.indexOf('upload');
      if (uploadIndex == -1 || uploadIndex >= pathSegments.length - 1) return null;

      int startIndex = uploadIndex + 1;
      if (startIndex < pathSegments.length && pathSegments[startIndex].startsWith('v') && RegExp(r'^v\d+$').hasMatch(pathSegments[startIndex])) {
        startIndex++;
      }

      final publicIdWithFormat = pathSegments.sublist(startIndex).join('/');
      final dotIndex = publicIdWithFormat.lastIndexOf('.');
      if (dotIndex != -1) {
        return publicIdWithFormat.substring(0, dotIndex);
      }
      return publicIdWithFormat;
    } catch (e) {
      debugPrint('[CloudinaryService] Error extracting public ID: $e');
      return null;
    }
  }

  /// Generates the SHA-1 signature required for secure/signed API requests on Cloudinary.
  static String _generateSignature(Map<String, String> params, String apiSecret) {
    final sortedKeys = params.keys.toList()..sort();
    final paramString = sortedKeys.map((key) => '$key=${params[key]}').join('&');
    final stringToSign = '$paramString$apiSecret';
    final bytes = utf8.encode(stringToSign);
    final digest = sha1.convert(bytes);
    return digest.toString();
  }
}
