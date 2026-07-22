import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

pickImage(ImageSource source) async {
  final ImagePicker _picker = ImagePicker();
  
  final XFile? image = await _picker.pickImage(source: source);
  if (image != null) {
    return await image.readAsBytes();
  }
  print('No image selected');
}

Future<XFile?> pickVideoFile(ImageSource source) async {
  final ImagePicker _picker = ImagePicker();
  
  final XFile? video = await _picker.pickVideo(source: source);
  if (video != null) {
    return video;
  }
  print('No video selected');
  return null;
}

Future<XFile?> pickMediaFile() async {
  final ImagePicker _picker = ImagePicker();
  
  final XFile? media = await _picker.pickMedia();
  if (media != null) {
    return media;
  }
  print('No media selected');
  return null;
}

showSnackBar(String content, context) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(content)),
  );
}
