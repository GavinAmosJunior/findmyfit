import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// An inset group of rows with an optional header and footer, like the
/// grouped lists in iOS Settings.
class GroupedSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const GroupedSection({super.key, this.header, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(indent: 16));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(header!, style: context.text.bodySmall),
            ),
          Card(clipBehavior: Clip.antiAlias, child: Column(children: rows)),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(footer!, style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}

/// A screen section title inside a scroll view ("At the laundry now").
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
      child: Row(
        children: [
          // Small spaced capitals, like the lettering on a laundromat window.
          Expanded(child: Text(text.toUpperCase(), style: context.text.labelMedium?.copyWith(letterSpacing: 1.2))),
          ?trailing,
        ],
      ),
    );
  }
}
