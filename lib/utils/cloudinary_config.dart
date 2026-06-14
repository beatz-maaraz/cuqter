/// Configuration settings for Cloudinary integration.
/// Replace placeholder values with your Cloudinary credentials.
class CloudinaryConfig {
  /// Your Cloudinary Cloud Name.
  static const String cloudName = 'dvsa4sxqa';

  /// Your Cloudinary Unsigned Upload Preset name.
  /// Ensure the preset is configured for "unsigned" upload in your Cloudinary Settings -> Upload tab.
  static const String uploadPreset = 'cuqter_preset';

  /// Optional: Your Cloudinary API Key.
  /// Unsigned uploads generally do not require an API key, but you can configure it here if needed.
  static const String apiKey = '338894747191195';

  /// Optional: Your Cloudinary API Secret.
  /// Required ONLY if you wish to delete old images automatically from Cloudinary.
  /// WARNING: Exposing the API secret in a client-side app is a security risk.
  static const String apiSecret = 'schhvg-iXJ-0p-p5FuGEpNSRu9Y';
}
