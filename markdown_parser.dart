import 'package:markdown/markdown.dart' as md;

import 'markdown_node.dart';

/// Parses inline Markdown into a tree of [MarkdownNode]s.
///
/// The parser is built on top of `package:markdown`'s [md.InlineParser], so it
/// inherits that package's well-tested emphasis/link/code resolution. On top of
/// it, [MarkdownParser] adds *streaming* support: it is safe to call [parse]
/// repeatedly with ever-growing prefixes of the same string (as an LLM emits
/// tokens) and get a sensible, flicker-free result at every step.
///
/// Streaming works by *optimistically closing* any delimiters that are still
/// open at the end of the input before handing the text to `package:markdown`.
/// So `"**bold wor"` is parsed as if it were `"**bold wor**"` and renders as
/// bold immediately, rather than showing literal asterisks until the closing
/// `**` arrives.
///
/// The parser only understands *inline* Markdown — bold, italic, strikethrough,
/// inline code and links. Block constructs (headings, lists, block quotes,
/// fenced code) are not interpreted; their markers are left as plain text.
///
/// ## Performance
///
/// Each [parse] call is O(n) in the input length (a few linear scans plus the
/// package's own inline parse). When streaming, you typically re-parse the
/// whole accumulated string on every token, which is O(n²) over the full
/// stream. That is fine for chat-message-sized text (a few KB). For very long
/// outputs, parse per finished line and only re-run the parser on the current,
/// still-growing line — inline spans never cross a line break — or debounce so
/// you parse at most once per animation frame rather than once per token.
class MarkdownParser {
  MarkdownParser({bool optimisticStreaming = true})
      : _optimisticStreaming = optimisticStreaming;

  /// Whether unterminated delimiters at the end of the input are auto-closed so
  /// partially-streamed spans render styled. See the class docs.
  final bool _optimisticStreaming;

  /// A [md.Document] configured for inline-only parsing. It carries the inline
  /// syntaxes (including GFM strikethrough) used to resolve spans. Block syntax
  /// is irrelevant because we only ever call the inline parser.
  ///
  /// Safe to reuse across every [parse] call: a [md.Document]'s mutable state
  /// (link reference / footnote maps) is only written by the *block* parser,
  /// which this class never invokes. The inline path only reads those maps, so
  /// no state leaks between successive streamed prefixes.
  final md.Document _document = md.Document(
    inlineSyntaxes: [md.StrikethroughSyntax()],
    encodeHtml: false,
  );

  /// Parses [input] and returns its inline nodes in document order.
  ///
  /// Returns an empty list for empty input. Never throws on malformed or
  /// partial input: anything it cannot interpret falls back to text.
  List<MarkdownNode> parse(String input) {
    if (input.isEmpty) return const [];

    final source = _optimisticStreaming ? _closeOpenDelimiters(input) : input;

    final astNodes = md.InlineParser(source, _document).parse();
    final result = <MarkdownNode>[];
    for (final node in astNodes) {
      _mapNode(node, result);
    }
    return _mergeAdjacentText(result);
  }

  // ---------------------------------------------------------------------------
  // AST -> MarkdownNode mapping
  // ---------------------------------------------------------------------------

  void _mapNode(md.Node node, List<MarkdownNode> out) {
    if (node is md.Text) {
      final text = node.textContent;
      if (text.isNotEmpty) out.add(MarkdownTextNode(text));
      return;
    }

    if (node is md.Element) {
      switch (node.tag) {
        case 'strong':
          out.add(MarkdownBoldNode(_mapChildren(node)));
        case 'em':
          out.add(MarkdownItalicNode(_mapChildren(node)));
        case 'del':
          out.add(MarkdownStrikethroughNode(_mapChildren(node)));
        case 'code':
          out.add(MarkdownCodeNode(node.textContent));
        case 'br':
          // A hard line break. It has no text content of its own, so emit an
          // explicit newline; otherwise the surrounding lines would be joined
          // when rendered into a single TextSpan.
          out.add(const MarkdownTextNode('\n'));
        case 'a':
          final href = node.attributes['href'];
          out.add(MarkdownLinkNode(
            _mapChildren(node),
            // An empty href means the URL hasn't been streamed yet.
            href: (href == null || href.isEmpty) ? null : href,
          ));
        // Any other element (e.g. an image, or a block tag that slipped
        // through) is flattened to its text content so nothing is dropped.
        default:
          final text = node.textContent;
          if (text.isNotEmpty) out.add(MarkdownTextNode(text));
      }
      return;
    }

    // Unknown node kind: preserve its text if it has any.
    final text = node.textContent;
    if (text.isNotEmpty) out.add(MarkdownTextNode(text));
  }

  List<MarkdownNode> _mapChildren(md.Element element) {
    final children = element.children;
    if (children == null || children.isEmpty) return const [];
    final out = <MarkdownNode>[];
    for (final child in children) {
      _mapNode(child, out);
    }
    return _mergeAdjacentText(out);
  }

  /// Collapses consecutive [MarkdownTextNode]s into one. `package:markdown`
  /// can emit text in several fragments (around escapes, entities, etc.);
  /// merging keeps the output tidy and equality-stable across stream steps.
  List<MarkdownNode> _mergeAdjacentText(List<MarkdownNode> nodes) {
    if (nodes.length < 2) return nodes;

    // Fast path: if no two adjacent text nodes exist there is nothing to merge,
    // so return the original list and skip rebuilding it.
    var hasAdjacentText = false;
    for (var k = 1; k < nodes.length; k++) {
      if (nodes[k] is MarkdownTextNode && nodes[k - 1] is MarkdownTextNode) {
        hasAdjacentText = true;
        break;
      }
    }
    if (!hasAdjacentText) return nodes;

    final out = <MarkdownNode>[];
    for (final node in nodes) {
      if (node is MarkdownTextNode &&
          out.isNotEmpty &&
          out.last is MarkdownTextNode) {
        final prev = out.removeLast() as MarkdownTextNode;
        out.add(MarkdownTextNode(prev.text + node.text));
      } else {
        out.add(node);
      }
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Streaming: optimistically close dangling delimiters
  // ---------------------------------------------------------------------------

  /// Scans [input] and appends the closing markers needed to terminate any
  /// span left open at the end, so partial streamed text renders as styled.
  ///
  /// Two steps:
  ///  1. If a backtick run opened an inline code span that never closed, close
  ///     it. Code wins over everything: emphasis inside it does not apply, so
  ///     no further scanning is needed.
  ///  2. Otherwise, delegate to [_pendingSpanClosers], which handles emphasis,
  ///     strikethrough and links together (backslash escapes and closed code
  ///     spans are masked out first so they can't produce false matches).
  ///
  /// This is deliberately a heuristic, not a full CommonMark delimiter matcher:
  /// it only needs to produce something that `package:markdown` then parses
  /// correctly, and to err toward *not* changing already-balanced input.
  String _closeOpenDelimiters(String input) {
    // 1) Inline code. If a backtick run opened a code span that never closed,
    //    close it. Everything after an open run is code, so emphasis inside it
    //    does not apply and nothing else needs appending.
    final codeCloser = _pendingCodeCloser(input);
    if (codeCloser != null) return input + codeCloser;

    // 2) Emphasis, strikethrough and links share one stack so nested spans are
    //    closed innermost-first regardless of kind (e.g. `[**lab` -> `**]()`).
    //    Scan a copy with code spans and escapes masked out so their contents
    //    can't produce false delimiter matches. Balanced input yields '', so
    //    `input + ''` leaves already well-formed text untouched.
    return input + _pendingSpanClosers(_maskCodeAndEscapes(input));
  }

  /// If an inline code span is currently open, returns the backtick run that
  /// would close it; otherwise returns null.
  String? _pendingCodeCloser(String input) {
    int i = 0;
    String? openRun;
    while (i < input.length) {
      final char = input[i];
      if (char == '\\' && openRun == null) {
        // Escapes only matter outside code; inside code backslash is literal.
        i += 2;
        continue;
      }
      if (char == '`') {
        int j = i;
        while (j < input.length && input[j] == '`') {
          j++;
        }
        final run = '`' * (j - i);
        if (openRun == null) {
          openRun = run;
        } else if (run == openRun) {
          openRun = null;
        }
        i = j;
        continue;
      }
      i++;
    }
    return openRun;
  }

  /// Replaces the contents of (closed) code spans and escaped characters with
  /// spaces, so later delimiter scanning ignores them. Length is preserved so
  /// indices still line up with the original string.
  ///
  /// Operates on a single code-unit buffer to avoid allocating a per-character
  /// string list — this runs on every streamed prefix, so it is a hot path.
  String _maskCodeAndEscapes(String input) {
    const backslash = 0x5C; // '\'
    const backtick = 0x60; // '`'
    const space = 0x20; // ' '

    // Fast path: most streamed text has neither backticks nor escapes, so skip
    // the copy entirely and avoid allocating on every token.
    if (!input.contains('`') && !input.contains(r'\')) return input;

    final units = input.codeUnits.toList(growable: false);
    int i = 0;
    while (i < units.length) {
      final unit = units[i];
      if (unit == backslash) {
        units[i] = space;
        if (i + 1 < units.length) units[i + 1] = space;
        i += 2;
        continue;
      }
      if (unit == backtick) {
        int j = i;
        while (j < units.length && units[j] == backtick) {
          j++;
        }
        final runLen = j - i;
        // Find a matching closing run of exactly the same length.
        int k = j;
        int closeStart = -1;
        while (k < units.length) {
          if (units[k] == backtick) {
            int m = k;
            while (m < units.length && units[m] == backtick) {
              m++;
            }
            if (m - k == runLen) {
              closeStart = k;
              break;
            }
            k = m;
          } else {
            k++;
          }
        }
        if (closeStart != -1) {
          for (int p = i; p < closeStart + runLen; p++) {
            units[p] = space;
          }
          i = closeStart + runLen;
        } else {
          // Unterminated here shouldn't happen (handled earlier), but be safe.
          i = j;
        }
        continue;
      }
      i++;
    }
    return String.fromCharCodes(units);
  }

  /// Returns the concatenated closing markers for every span (emphasis,
  /// strikethrough, link) left open at the end of [masked], ordered so the
  /// most recently opened span closes first.
  ///
  /// Emphasis/strikethrough runs are classified with the same CommonMark
  /// *flanking* rules that `package:markdown` applies (see [_DelimiterFlank]),
  /// so a run is only treated as an opener when the real parser would also let
  /// it open. This prevents appending stray closers for runs that are actually
  /// literal — e.g. the whitespace-flanked `*` in `"a * b"`, or the intra-word
  /// `_` in `"snake_case"`, which underscore emphasis disallows.
  ///
  /// Delimiter units, by the package's tag table:
  ///  * `*` / `_` → `*`/`__` give strong, single give emphasis;
  ///  * `~`       → single or double give strikethrough (`del`);
  ///  * `[`       → link label, closed with `]()` (empty, streaming href);
  ///  * `](`      → link destination opened, closed with `)`.
  ///
  /// Fully-balanced input leaves the stack empty and yields `''`, so already
  /// well-formed text is never altered.
  String _pendingSpanClosers(String masked) {
    // Each entry is the run string that would close that opener (e.g. '**').
    final stack = <String>[];

    int i = 0;
    while (i < masked.length) {
      final c = masked[i];

      if (c == '*' || c == '_' || c == '~') {
        int j = i;
        while (j < masked.length && masked[j] == c) {
          j++;
        }
        final run = masked.substring(i, j);
        final flank = _DelimiterFlank.of(masked, i, j, c);

        // Try to close the nearest matching opener this run could close.
        if (flank.canClose) {
          final idx = stack.lastIndexOf(run);
          if (idx != -1) {
            // Close it and discard anything opened inside it that is now
            // orphaned (it cannot cross the closing boundary).
            while (stack.length > idx) {
              stack.removeLast();
            }
            i = j;
            continue;
          }
          // A pure closer (can close but not open) with no opener is literal.
          if (!flank.canOpen) {
            i = j;
            continue;
          }
        }

        // Otherwise, if it can open, remember it as a dangling opener.
        if (flank.canOpen) {
          stack.add(run);
        }
        // A run that can neither open nor close (e.g. ' * ') is literal: skip.
        i = j;
        continue;
      }

      // Link label open.
      if (c == '[') {
        stack.add(']()');
        i++;
        continue;
      }

      // Link label close, possibly opening a destination.
      if (c == ']') {
        final idx = stack.lastIndexOf(']()');
        if (idx != -1) {
          if (i + 1 < masked.length && masked[i + 1] == '(') {
            // Destination opened: this opener now closes with ')'.
            stack[idx] = ')';
            while (stack.length > idx + 1) {
              stack.removeLast();
            }
            i += 2;
            continue;
          }
          // Bare '[...]' with no destination: not a link, drop the opener.
          while (stack.length > idx) {
            stack.removeLast();
          }
        }
        i++;
        continue;
      }

      // Destination close.
      if (c == ')') {
        final idx = stack.lastIndexOf(')');
        if (idx != -1) {
          while (stack.length > idx) {
            stack.removeLast();
          }
        }
        i++;
        continue;
      }

      i++;
    }

    if (stack.isEmpty) return '';
    final buffer = StringBuffer();
    for (int k = stack.length - 1; k >= 0; k--) {
      buffer.write(stack[k]);
    }
    return buffer.toString();
  }
}

/// Whether a delimiter run can open and/or close emphasis, computed with the
/// CommonMark left/right-flanking rules that `package:markdown` uses. Mirrors
/// `DelimiterRun.tryParse` so this parser's streaming heuristic agrees with the
/// real parser about which runs are openers, closers, both, or literal.
///
/// See https://spec.commonmark.org/0.30/#can-open-emphasis.
class _DelimiterFlank {
  const _DelimiterFlank({required this.canOpen, required this.canClose});

  final bool canOpen;
  final bool canClose;

  /// Classifies the run `text[start..end)` of delimiter character [char].
  /// Positions at the string edges are treated as whitespace, matching the
  /// package (`runStart == 0` / `runEnd == length`).
  factory _DelimiterFlank.of(String text, int start, int end, String char) {
    // `*` and `~` allow intra-word runs; `_` does not.
    final allowIntraWord = char == '*' || char == '~';

    final bool precededByWhitespace;
    final bool precededByPunctuation;
    if (start == 0) {
      precededByWhitespace = true;
      precededByPunctuation = false;
    } else {
      final before = text[start - 1];
      precededByWhitespace = _isUnicodeWhitespace(before);
      precededByPunctuation =
          !precededByWhitespace && _isAsciiPunctuation(before);
    }

    final bool followedByWhitespace;
    final bool followedByPunctuation;
    if (end == text.length) {
      followedByWhitespace = true;
      followedByPunctuation = false;
    } else {
      final after = text[end];
      followedByWhitespace = _isUnicodeWhitespace(after);
      followedByPunctuation =
          !followedByWhitespace && _isAsciiPunctuation(after);
    }

    final isLeftFlanking = !followedByWhitespace &&
        (!followedByPunctuation ||
            precededByWhitespace ||
            precededByPunctuation);
    final isRightFlanking = !precededByWhitespace &&
        (!precededByPunctuation ||
            followedByWhitespace ||
            followedByPunctuation);

    return _DelimiterFlank(
      canOpen: isLeftFlanking &&
          (!isRightFlanking || allowIntraWord || precededByPunctuation),
      canClose: isRightFlanking &&
          (!isLeftFlanking || allowIntraWord || followedByPunctuation),
    );
  }

  // The package tests the full Unicode punctuation/whitespace sets. For an
  // inline streaming heuristic the ASCII subset covers the cases that actually
  // occur (code, prose, URLs); a rare non-ASCII punctuation neighbour at most
  // mis-styles the final streamed character for one frame before the real
  // parser corrects it on the next token.
  static bool _isUnicodeWhitespace(String ch) {
    if (ch.isEmpty) return false;
    switch (ch.codeUnitAt(0)) {
      case 0x20: // space
      case 0x09: // tab
      case 0x0A: // newline
      case 0x0D: // carriage return
      case 0x0C: // form feed
      case 0xA0: // non-breaking space
        return true;
      default:
        return false;
    }
  }

  static bool _isAsciiPunctuation(String ch) {
    if (ch.isEmpty) return false;
    final code = ch.codeUnitAt(0);
    return (code >= 0x21 && code <= 0x2F) || // ! " # $ % & ' ( ) * + , - . /
        (code >= 0x3A && code <= 0x40) || //    : ; < = > ? @
        (code >= 0x5B && code <= 0x60) || //    [ \ ] ^ _ `
        (code >= 0x7B && code <= 0x7E); //      { | } ~
  }
}
