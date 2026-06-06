import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Discord-style custom (non-unicode) emoji support for [SmartText].
///
/// A custom emoji is carried inside the message string as a self-contained
/// token:
///
///     <:name:https://cdn.example.com/pepe.webp>
///
/// The token embeds its own image URL. The trouble is that [SmartText] first
/// runs the text through the native classifier ([SmartTextFlutter.classifyText]),
/// which would detect the `https://…` *inside* the token and split it into
/// separate text/url spans — shredding the token.
///
/// So the renderer [protect]s every token into an inert private-use sentinel
/// (no `http`, no `<`/`>`, not a real glyph) *before* classification, then
/// [splitSpans] turns the surviving sentinels into inline image [WidgetSpan]s
/// when the final spans are built. The plain slices around the sentinels are
/// rebuilt by the caller so existing mention/style handling is preserved.
class CustomEmoji {
  CustomEmoji._();

  /// `<:name:url>` — name has no `:` `<` `>`; url has no `>`.
  static final RegExp pattern = RegExp(r'<:([^:<>]+):([^>]+)>');

  // Private-use Unicode sentinels — not a shortcode, not HTML, not a URL, so the
  // classifier leaves them untouched. Distinct from any app-side sentinels.
  static const String _open = '\u{F8FF}';
  static const String _close = '\u{F8FE}';
  static final RegExp _sentinelPattern = RegExp('$_open(\\d+)$_close');

  /// True when [text] contains at least one raw custom-emoji token.
  static bool hasToken(String text) =>
      text.contains('<:') && pattern.hasMatch(text);

  /// Replace every custom-emoji token with an inert sentinel, returning the
  /// rewritten text and the ordered list of URLs the sentinels map back to.
  /// Run this *before* the classifier.
  static (String text, List<String> urls) protect(String text) {
    if (!text.contains('<:')) return (text, const []);
    final urls = <String>[];
    final out = text.replaceAllMapped(pattern, (match) {
      final index = urls.length;
      urls.add(match.group(2)!);
      return '$_open$index$_close';
    });
    return (out, urls);
  }

  /// Split a (post-classification) text run containing sentinels into inline
  /// spans: emoji sentinels become image [WidgetSpan]s, and the surrounding text
  /// is passed back through [textSpanBuilder] so existing mention/link handling
  /// is preserved on the non-emoji slices.
  ///
  /// When [urls] is empty (no tokens were protected) this returns a single
  /// `textSpanBuilder(text)` so callers can use it unconditionally.
  static List<InlineSpan> splitSpans({
    required String text,
    required List<String> urls,
    required double size,
    required InlineSpan Function(String slice) textSpanBuilder,
  }) {
    if (urls.isEmpty || !text.contains(_open)) {
      return [textSpanBuilder(text)];
    }
    final spans = <InlineSpan>[];
    int last = 0;
    for (final match in _sentinelPattern.allMatches(text)) {
      if (match.start > last) {
        spans.add(textSpanBuilder(text.substring(last, match.start)));
      }
      final index = int.tryParse(match.group(1) ?? '');
      if (index != null && index >= 0 && index < urls.length) {
        spans.add(inlineEmoji(urls[index], size));
      }
      last = match.end;
    }
    if (last < text.length) {
      spans.add(textSpanBuilder(text.substring(last)));
    }
    return spans;
  }

  /// An inline image span sized to roughly the surrounding line height.
  static WidgetSpan inlineEmoji(String url, double size) {
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1),
        child: CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder: (context, _) => SizedBox(width: size, height: size),
          errorWidget: (context, _, __) => SizedBox(width: size, height: size),
        ),
      ),
    );
  }
}
