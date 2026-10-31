/// Inline Markdown parsing for streamed (LLM) text.
///
/// Import this barrel to get the parser and its node model together:
///
/// ```dart
/// import 'package:d_society/core/parsers/markdown.dart';
///
/// final nodes = MarkdownParser().parse('**hello**');
/// ```
library;

export 'markdown_node.dart';
export 'markdown_parser.dart';
