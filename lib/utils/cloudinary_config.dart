/// Cloudinary credentials configuration.
/// Can be overridden at build time using `--dart-define=CLOUDINARY_CLOUD_NAME=...`
class CloudinaryConfig {
  static const String cloudName = String.fromEnvironment(
    'CLOUDINARY_CLOUD_NAME',
    defaultValue: 'dvsa4sxqa',
  );
  static const String apiKey = String.fromEnvironment(
    'CLOUDINARY_API_KEY',
    defaultValue: '338894747191195',
  );
  static const String apiSecret = String.fromEnvironment(
    'CLOUDINARY_API_SECRET',
    defaultValue: 'schhvg-iXJ-0p-p5FuGEpNSRu9Y',
  );
  static const String uploadPreset = String.fromEnvironment(
    'CLOUDINARY_UPLOAD_PRESET',
    defaultValue: 'cuqter_preset', // Used for unsigned uploads
  );
}
