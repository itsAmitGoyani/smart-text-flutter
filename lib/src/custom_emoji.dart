import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';

/// Discord-style custom (non-unicode) emoji support for [SmartText].
///
/// Two wire forms are supported:
///   * NEW id form `:id:` (e.g. `:29538:`) — carries only an id; the image URL
///     is resolved by a caller-supplied `resolver(id)` (the package itself has
///     no catalog/CDN knowledge);
///   * LEGACY form `<:name:https://cdn.example.com/pepe.webp>` — embeds its own
///     URL.
///
/// The trouble is that [SmartText] first runs the text through the native
/// classifier ([SmartTextFlutter.classifyText]), which would detect a `https://…`
/// inside the legacy token (or split a bare `:id:`) and shred it. So the renderer
/// [protect]s every token into an inert private-use sentinel *before*
/// classification, then [splitSpans] turns the surviving sentinels into inline
/// image [WidgetSpan]s. The plain slices around the sentinels are rebuilt by the
/// caller so existing mention/style handling is preserved.
class CustomEmoji {
  CustomEmoji._();

  /// `<:name:url>` — name has no `:` `<` `>`; url has no `>`. (legacy)
  static final RegExp pattern = RegExp(r'<:([^:<>]+):([^>]+)>');

  /// `:id:` — digits only, so it never matches `:)`-style faces or shortcodes.
  static final RegExp idPattern = RegExp(r':(\d+):');

  // Private-use Unicode sentinels — not a shortcode, not HTML, not a URL, so the
  // classifier leaves them untouched. Distinct from any app-side sentinels.
  static const String _open = '\u{F8FF}';
  static const String _close = '\u{F8FE}';
  static final RegExp _sentinelPattern = RegExp('$_open(\\d+)$_close');

  /// True when [text] contains at least one custom-emoji token — a legacy
  /// `<:name:url>`, or (when a [resolver] is provided) a new `:id:`.
  static bool hasToken(String text, {String Function(String id)? resolver}) {
    if (text.contains('<:') && pattern.hasMatch(text)) return true;
    return resolver != null && idPattern.hasMatch(text);
  }

  /// Replace every custom-emoji token with an inert sentinel, returning the
  /// rewritten text and the ordered list of URLs the sentinels map back to.
  /// Run this *before* the classifier.
  ///
  /// Legacy `<:name:url>` tokens take their URL from the token itself. New
  /// `:id:` tokens are only protected when a [resolver] is supplied (it maps the
  /// id to an image URL); without one, `:id:` is left as plain text.
  static (String text, List<String> urls) protect(String text, {String Function(String id)? resolver}) {
    final bool hasLegacy = text.contains('<:');
    final bool hasId = resolver != null && idPattern.hasMatch(text);
    if (!hasLegacy && !hasId) return (text, const []);

    final urls = <String>[];
    String out = text;

    if (hasLegacy) {
      out = out.replaceAllMapped(pattern, (match) {
        final index = urls.length;
        urls.add(match.group(2)!);
        return '$_open$index$_close';
      });
    }

    if (hasId) {
      out = out.replaceAllMapped(idPattern, (match) {
        final index = urls.length;
        urls.add(resolver(match.group(1)!));
        return '$_open$index$_close';
      });
    }

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
