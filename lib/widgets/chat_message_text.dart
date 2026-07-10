import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// A custom widget that displays chat message text.
/// It renders emoji-only messages at a larger size, and parses
/// links (URLs) in standard messages to make them clickable.
class ChatMessageText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Color linkColor;
  final Widget? trailing;

  const ChatMessageText({
    Key? key,
    required this.text,
    required this.baseStyle,
    required this.linkColor,
    this.trailing,
  }) : super(key: key);

  /// Checks if a single grapheme cluster is an emoji.
  bool _isEmoji(String character) {
    for (final rune in character.runes) {
      // Standard alphanumeric or basic keyboard symbols are not emojis
      if ((rune >= 48 && rune <= 57) || // 0-9
          (rune >= 65 && rune <= 90) || // A-Z
          (rune >= 97 && rune <= 122) || // a-z
          rune == 46 || rune == 63 || rune == 33 || // . ? !
          rune == 44 || rune == 58 || rune == 59 || // , : ;
          rune == 45 || rune == 95 || rune == 47 || // - _ /
          rune == 64 || rune == 35 || rune == 36 || // @ # $
          rune == 37 || rune == 38 || rune == 42 || // % & *
          rune == 40 || rune == 41 || rune == 43 || // ( ) +
          rune == 61) { // =
        return false;
      }
    }

    // Check against common Unicode emoji blocks
    for (final rune in character.runes) {
      if (rune >= 0x1F000 && rune <= 0x1FAFF) return true;
      if (rune >= 0x2600 && rune <= 0x27BF) return true;
      if (rune >= 0x2300 && rune <= 0x23FF) return true;
      if (rune >= 0x2B50 && rune <= 0x2B55) return true;
      if (rune >= 0x1F00 && rune <= 0x1F1FF) return true;
    }
    return false;
  }

  /// Determines if the message text consists entirely of emojis.
  /// If so, returns the number of emojis. Otherwise, returns null.
  int? _emojiOnlyCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return null;

    final chars = trimmed.characters;
    int emojiCount = 0;
    for (final char in chars) {
      if (char.trim().isEmpty) continue; // Skip whitespace spaces

      if (_isEmoji(char)) {
        emojiCount++;
      } else {
        return null; // Contains non-emoji content
      }
    }

    return emojiCount > 0 ? emojiCount : null;
  }

  /// Returns the customized font size for emoji-only messages
  /// depending on how many emojis are present.
  double _getEmojiFontSize(int emojiCount) {
    switch (emojiCount) {
      case 1:
        return 48.0;
      case 2:
        return 40.0;
      case 3:
        return 32.0;
      case 4:
      case 5:
        return 26.0;
      default:
        return 20.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final emojiCount = _emojiOnlyCount(text);
    if (emojiCount != null) {
      final double size = _getEmojiFontSize(emojiCount);
      return SelectableText.rich(
        TextSpan(
          text: text,
          style: baseStyle.copyWith(
            fontSize: size,
            height: 1.1,
          ),
          children: trailing != null
              ? [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.bottom,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: trailing!,
                    ),
                  )
                ]
              : null,
        ),
      );
    }

    return _LinkText(
      text: text,
      style: baseStyle,
      linkColor: linkColor,
      trailing: trailing,
    );
  }
}

/// Helper widget to parse text and render clickable links.
class _LinkText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final Color linkColor;
  final Widget? trailing;

  const _LinkText({
    Key? key,
    required this.text,
    required this.style,
    required this.linkColor,
    this.trailing,
  }) : super(key: key);

  @override
  State<_LinkText> createState() => _LinkTextState();
}

class _LinkTextState extends State<_LinkText> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _launchURL(String urlString) async {
    String formattedUrl = urlString;
    if (formattedUrl.startsWith('www.')) {
      formattedUrl = 'https://$formattedUrl';
    }
    final Uri uri = Uri.parse(formattedUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('Could not launch $urlString: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Clear previous recognizers on rebuild
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    // Regex for detecting URLs
    final RegExp urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+|www\.[^\s]+)',
      caseSensitive: false,
    );

    final matches = urlRegExp.allMatches(widget.text);
    if (matches.isEmpty) {
      return SelectableText.rich(
        TextSpan(
          text: widget.text,
          style: widget.style,
          children: widget.trailing != null
              ? [
                  WidgetSpan(
                    alignment: PlaceholderAlignment.bottom,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: widget.trailing!,
                    ),
                  )
                ]
              : null,
        ),
      );
    }

    final List<InlineSpan> spans = [];
    int lastMatchEnd = 0;

    for (final match in matches) {
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: widget.text.substring(lastMatchEnd, match.start),
          style: widget.style,
        ));
      }

      final urlString = match.group(0)!;
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _launchURL(urlString);
      _recognizers.add(recognizer);

      spans.add(TextSpan(
        text: urlString,
        style: widget.style.copyWith(
          color: widget.linkColor,
          decoration: TextDecoration.underline,
          fontWeight: FontWeight.w600,
        ),
        recognizer: recognizer,
      ));

      lastMatchEnd = match.end;
    }

    if (lastMatchEnd < widget.text.length) {
      spans.add(TextSpan(
        text: widget.text.substring(lastMatchEnd),
        style: widget.style,
      ));
    }

    if (widget.trailing != null) {
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.bottom,
        child: Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: widget.trailing!,
        ),
      ));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
    );
  }
}
