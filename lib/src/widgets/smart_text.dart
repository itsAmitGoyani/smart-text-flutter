import 'dart:ui' as ui show TextHeightBehavior;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:smart_text_flutter/src/custom_emoji.dart';
import 'package:smart_text_flutter/src/extensions/item_span_default_config.dart';
import 'package:smart_text_flutter/smart_text_flutter.dart';

// TODO: Merge the SmartText and SmartSelectableText widgets
/// The smart text which automatically detect links in text and renders them
class SmartText extends StatefulWidget {
  const SmartText(
    this.text, {
    super.key,
    required this.mentionedUsers,
    this.config,
    this.addressConfig,
    this.dateTimeConfig,
    this.emailConfig,
    this.phoneConfig,
    this.mentionConfig,
    this.urlConfig,
    this.strutStyle,
    this.locale,
    this.textAlign,
    this.textDirection,
    this.maxLines,
    this.overflow,
    this.selectionColor,
    this.semanticsLabel,
    this.softWrap,
    this.textHeightBehavior,
    this.textScaler,
    this.textWidthBasis,
    this.humanize = false,
  });

  /// The text to linkify
  /// This text will be classified and the links will be highlighted
  final String text;

  /// The list of mentioned users. This is used to highlight the mentioned users.
  final List<String> mentionedUsers;

  /// The configuration for setting the [TextStyle] and onClicked method
  /// This affects the whole text
  final ItemSpanConfig? config;

  /// The configuration for setting the [TextStyle] and what happens when the address link is clicked
  final ItemSpanConfig? addressConfig;

  /// The configuration for setting the [TextStyle] and what happens when the phone link is clicked
  final ItemSpanConfig? phoneConfig;

  /// The configuration for setting the [TextStyle] and what happens when the url is clicked
  final ItemSpanConfig? urlConfig;

  /// The configuration for setting the [TextStyle] and what happens when the date time is clicked
  final ItemSpanConfig? dateTimeConfig;

  /// The configuration for setting the [TextStyle] and what happens when the email link is clicked
  final ItemSpanConfig? emailConfig;

  /// The configuration for setting the [TextStyle] and what happens when the mention link is clicked
  final ItemSpanConfig? mentionConfig;

  final StrutStyle? strutStyle;

  final TextAlign? textAlign;

  final TextDirection? textDirection;

  final Locale? locale;

  final bool? softWrap;

  final TextOverflow? overflow;

  final TextScaler? textScaler;

  final int? maxLines;

  final String? semanticsLabel;

  final TextWidthBasis? textWidthBasis;

  final ui.TextHeightBehavior? textHeightBehavior;

  final Color? selectionColor;

  final bool humanize;

  @override
  State<SmartText> createState() => _SmartTextState();
}

class _SmartTextState extends State<SmartText> {
  late Future<List<ItemSpan>> classifyTextFuture;

  /// URLs for custom-emoji tokens swapped out of [widget.text] by
  /// [CustomEmoji.protect] before classification. Sentinels left in the
  /// classified spans are restored to inline images using this list.
  List<String> _emojiUrls = const [];

  /// Inline emoji size, derived from the configured text size.
  double get _emojiSize => widget.config?.textStyle?.fontSize ?? 16;

  @override
  void initState() {
    super.initState();

    classifyTextFuture = getItemSpans();
  }

  @override
  void didUpdateWidget(covariant SmartText oldWidget) {
    if (oldWidget.text != widget.text) classifyTextFuture = getItemSpans();

    super.didUpdateWidget(oldWidget);
  }

  Future<List<ItemSpan>> getItemSpans() async {
    // Protect custom-emoji tokens before classification — otherwise the native
    // classifier detects the URL inside `<:name:url>` and shreds the token.
    final (protectedText, urls) = CustomEmoji.protect(widget.text);
    _emojiUrls = urls;
    return SmartTextFlutter.classifyText(protectedText);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ItemSpan>>(
      future: classifyTextFuture,
      builder: (context, snapshot) {
        List<InlineSpan> inlineSpanList = [];
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          // Classification unavailable — still protect tokens so custom emoji
          // render (and the raw `<:name:url>` never leaks through).
          final (protectedText, _) = CustomEmoji.protect(widget.text);
          inlineSpanList.addAll(getTextInlineSpans(ItemSpan(
            text: protectedText,
            type: ItemSpanType.text,
            rawValue: protectedText,
          )));
        } else {
          for (final span in snapshot.data!) {
            switch (span.type) {
              case ItemSpanType.text:
                inlineSpanList.addAll(getTextInlineSpans(span));
              case ItemSpanType.address:
                inlineSpanList.add(TextSpan(
                  text: span.text,
                  style: span.defaultConfig.textStyle?.merge(
                    widget.addressConfig?.textStyle,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap =
                        () => _handleItemSpanTap(span, widget.addressConfig),
                ));
              case ItemSpanType.email:
                inlineSpanList.add(TextSpan(
                  text: span.text,
                  style: span.defaultConfig.textStyle?.merge(
                    widget.emailConfig?.textStyle,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap =
                        () => _handleItemSpanTap(span, widget.emailConfig),
                ));
              case ItemSpanType.phone:
                inlineSpanList.add(TextSpan(
                  text: span.text,
                  style: span.defaultConfig.textStyle?.merge(
                    widget.phoneConfig?.textStyle,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap =
                        () => _handleItemSpanTap(span, widget.phoneConfig),
                ));
              case ItemSpanType.datetime:
                inlineSpanList.add(TextSpan(
                  text: span.text,
                  style: span.defaultConfig.textStyle?.merge(
                    widget.dateTimeConfig?.textStyle,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap =
                        () => _handleItemSpanTap(span, widget.dateTimeConfig),
                ));
              case ItemSpanType.url:
                inlineSpanList.add(TextSpan(
                  text: span.text,
                  style: span.defaultConfig.textStyle?.merge(
                    widget.urlConfig?.textStyle,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _handleItemSpanTap(span, widget.urlConfig),
                ));
            }
          }
        }
        return Text.rich(
          TextSpan(
            children: inlineSpanList,
            style: const TextStyle().merge(widget.config?.textStyle),
          ),
          strutStyle: widget.strutStyle,
          locale: widget.locale,
          textAlign: widget.textAlign,
          maxLines: widget.maxLines,
          overflow: widget.overflow,
          selectionColor: widget.selectionColor,
          semanticsLabel: widget.semanticsLabel,
          softWrap: widget.softWrap,
          textDirection: widget.textDirection,
          textHeightBehavior: widget.textHeightBehavior,
          textScaler: widget.textScaler,
          textWidthBasis: widget.textWidthBasis,
        );
      },
    );
  }

  void _handleItemSpanTap(ItemSpan span, ItemSpanConfig? config) {
    if (config?.onClicked != null) {
      config?.onClicked?.call(span.rawValue);
    } else {
      span.defaultConfig.onClicked?.call(span.rawValue);
    }
  }

  List<String> splitMentioned(String input) {
    RegExp regex = RegExp(
        r"((^)|(( )+))@[\w._]+(($)|(( )+))"); // old RegExp(r"((^)|(( )+))@\w+(($)|(( )+))");
    Iterable<Match> matches = regex.allMatches(input);
    List<String> parts = [];
    int lastEnd = 0;
    for (Match match in matches) {
      int start = match.start;
      int end = match.end;
      if (start > lastEnd) {
        parts.add(input.substring(lastEnd, start));
      }
      parts.add(input.substring(start, end));
      lastEnd = end;
    }
    if (lastEnd < input.length) {
      parts.add(input.substring(lastEnd));
    }
    return parts;
  }

  List<InlineSpan> getTextInlineSpans(ItemSpan span) {
    final List<InlineSpan> result = [];
    for (final text in splitMentioned(span.text)) {
      if (text.trim().startsWith('@')) {
        final int leftPadding = text.length - text.trimLeft().length;
        final int rightPadding = text.length - text.trimRight().length;
        final String username = text.trim().substring(1); // Remove @ symbol

        // Only highlight if username is in mentionedUsers list
        if (widget.mentionedUsers.contains(username)) {
          result.add(TextSpan(
            text: List.generate(leftPadding, (_) => " ").join(),
            children: [
              TextSpan(
                text: text.trim(),
                style: span.defaultConfig.textStyle?.merge(
                  widget.mentionConfig?.textStyle,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => _handleItemSpanTap(
                        ItemSpan(
                          text: text.trim(),
                          type: span.type,
                          rawValue: text.trim(),
                        ),
                        widget.mentionConfig,
                      ),
              ),
              TextSpan(
                text: List.generate(rightPadding, (_) => " ").join(),
              )
            ],
            style: span.defaultConfig.textStyle?.merge(
              widget.config?.textStyle,
            ),
          ));
          continue;
        }
      }
      // Plain text slice — restore any protected custom-emoji sentinels to
      // inline images. When there are no emoji this yields a single TextSpan.
      result.addAll(
        CustomEmoji.splitSpans(
          text: text,
          urls: _emojiUrls,
          size: _emojiSize,
          textSpanBuilder: (slice) => TextSpan(
            text: slice,
            style: span.defaultConfig.textStyle?.merge(
              widget.config?.textStyle,
            ),
          ),
        ),
      );
    }
    return result;
  }
}
