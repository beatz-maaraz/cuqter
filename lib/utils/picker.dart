import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

Future<Uint8List?> pickImage(ImageSource source) async {
  final ImagePicker picker = ImagePicker();

  final XFile? image = await picker.pickImage(source: source);
  if (image != null) {
    return await image.readAsBytes();
  }
  print('No image selected');
  return null;
}

Future<XFile?> pickVideoFile(ImageSource source) async {
  final ImagePicker picker = ImagePicker();

  final XFile? video = await picker.pickVideo(source: source);
  if (video != null) {
    return video;
  }
  print('No video selected');
  return null;
}

Future<XFile?> pickMediaFile() async {
  final ImagePicker picker = ImagePicker();

  final XFile? media = await picker.pickMedia();
  if (media != null) {
    return media;
  }
  print('No media selected');
  return null;
}

void showSnackBar(String content, context) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(content)));
}
