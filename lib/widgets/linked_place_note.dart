import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Existing place notes may contain URLs in any sentence, not only a special
/// reservation-link field. Display them as selectable, actionable text.
class LinkedPlaceNote extends StatefulWidget {
  const LinkedPlaceNote({super.key, required this.text});
  final String text;

  static final _urlPattern =
      RegExp(r'https?:\/\/[^\s<>"“”]+', caseSensitive: false);
  static final _trailingPunctuation = RegExp(r'[.,;:!?)\]]+$');

  static List<String> findLinks(String text) {
    return _urlPattern
        .allMatches(text)
        .map((match) => match.group(0)!.replaceFirst(_trailingPunctuation, ''))
        .where((url) => Uri.tryParse(url)?.hasAuthority ?? false)
        .toSet()
        .toList(growable: false);
  }

  @override
  State<LinkedPlaceNote> createState() => _LinkedPlaceNoteState();
}

class _LinkedPlaceNoteState extends State<LinkedPlaceNote> {
  final List<TapGestureRecognizer> _recognizers = [];

  @override
  void dispose() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    super.dispose();
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !['http', 'https'].contains(uri.scheme)) return;
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {
      // Allow users to copy the link when the device cannot open a browser.
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('링크를 열 수 없습니다. 주소를 복사해 사용해 주세요.')),
    );
  }

  void _linkActions(String url) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: SelectableText(url, style: const TextStyle(fontSize: 13)),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('링크 열기'),
              onTap: () {
                Navigator.pop(sheetContext);
                _open(url);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('링크 주소 복사'),
              onTap: () async {
                Navigator.pop(sheetContext);
                await Clipboard.setData(ClipboardData(text: url));
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('링크 주소를 복사했습니다.')),
                );
              },
            ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    final text = widget.text;
    final spans = <InlineSpan>[];
    var index = 0;
    final baseStyle = const TextStyle(fontSize: 14, height: 1.65);
    final linkStyle = baseStyle.copyWith(
      color: Theme.of(context).colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationColor: Theme.of(context).colorScheme.primary,
    );

    for (final match in LinkedPlaceNote._urlPattern.allMatches(text)) {
      final found = match.group(0)!;
      final url = found.replaceFirst(LinkedPlaceNote._trailingPunctuation, '');
      if (url.isEmpty || !(Uri.tryParse(url)?.hasAuthority ?? false)) continue;
      if (match.start > index) {
        spans.add(TextSpan(text: text.substring(index, match.start)));
      }
      final recognizer = TapGestureRecognizer()
        ..onTap = () => _linkActions(url);
      _recognizers.add(recognizer);
      spans.add(TextSpan(
        text: url,
        style: linkStyle,
        recognizer: recognizer,
      ));
      final after = match.start + url.length;
      if (after < match.end) {
        spans.add(TextSpan(text: text.substring(after, match.end)));
      }
      index = match.end;
    }
    if (index < text.length) spans.add(TextSpan(text: text.substring(index)));
    if (spans.isEmpty) spans.add(TextSpan(text: text));

    return SelectableText.rich(
      TextSpan(style: baseStyle, children: spans),
    );
  }
}
