
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickImage(ImageSource source) async {
  final ImagePicker picker = ImagePicker();

  final XFile? image = await picker.pickImage(source: source);
  if (image != null) {
    return await image.readAsBytes();
  }
  debugPrint('No image selected');
  return null;
}

Future<XFile?> pickVideoFile(ImageSource source) async {
  final ImagePicker picker = ImagePicker();

  final XFile? video = await picker.pickVideo(source: source);
  if (video != null) {
    return video;
  }
  debugPrint('No video selected');
  return null;
}

Future<XFile?> pickMediaFile() async {
  final ImagePicker picker = ImagePicker();

  final XFile? media = await picker.pickMedia();
  if (media != null) {
    return media;
  }
  debugPrint('No media selected');
  return null;
}

void showSnackBar(String content, dynamic context) {
  if (context is BuildContext) {
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      content: Text(
        content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    ));
  }
}
