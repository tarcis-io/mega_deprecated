import 'package:flutter/foundation.dart';

@immutable
sealed class MarkdownNode {
  const MarkdownNode();
}

@immutable
sealed class MarkdownParentNode extends MarkdownNode {
  const MarkdownParentNode(this.children);

  /// The inline nodes wrapped by this span, in document order.
  final List<MarkdownNode> children;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownParentNode &&
          runtimeType == other.runtimeType &&
          listEquals(children, other.children);

  @override
  int get hashCode => Object.hash(runtimeType, Object.hashAll(children));
}

final class MarkdownTextNode extends MarkdownNode {
  const MarkdownTextNode(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownTextNode && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MarkdownTextNode(${_truncate(text)})';
}

final class MarkdownBoldNode extends MarkdownParentNode {
  const MarkdownBoldNode(super.children);

  @override
  String toString() => 'MarkdownBoldNode($children)';
}

final class MarkdownItalicNode extends MarkdownParentNode {
  const MarkdownItalicNode(super.children);

  @override
  String toString() => 'MarkdownItalicNode($children)';
}

final class MarkdownStrikethroughNode extends MarkdownParentNode {
  const MarkdownStrikethroughNode(super.children);

  @override
  String toString() => 'MarkdownStrikethroughNode($children)';
}

final class MarkdownCodeNode extends MarkdownNode {
  const MarkdownCodeNode(this.text);

  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownCodeNode && text == other.text;

  @override
  int get hashCode => text.hashCode;

  @override
  String toString() => 'MarkdownCodeNode(${_truncate(text)})';
}

final class MarkdownLinkNode extends MarkdownParentNode {
  const MarkdownLinkNode(super.children, {this.href});

  final String? href;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MarkdownLinkNode &&
          href == other.href &&
          listEquals(children, other.children);

  @override
  int get hashCode => Object.hash(href, Object.hashAll(children));

  @override
  String toString() => 'MarkdownLinkNode(href: $href, $children)';
}

String _truncate(String value, [int max = 24]) {
  final escaped = value.replaceAll('\n', r'\n');
  if (escaped.length <= max) return "'$escaped'";
  return "'${escaped.substring(0, max)}…'";
}
