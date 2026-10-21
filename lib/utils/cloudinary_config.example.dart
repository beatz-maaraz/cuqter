/// Template Cloudinary Configuration.
/// Copy this file to `cloudinary_config.dart` or supply variables via `--dart-define`.
class CloudinaryConfig {
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'YOUR_CLOUD_NAME_HERE',
  );
  static const String apiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: 'YOUR_API_KEY_HERE',
  );
  static const String apiSecret = String.fromEnvironment(
    'CLOUDINARY_API_SECRET',
    defaultValue: 'YOUR_API_SECRET_HERE',
  );
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'YOUR_UPLOAD_PRESET_HERE',
  );
}
