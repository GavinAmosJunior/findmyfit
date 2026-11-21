import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A group of rows on one gray tile, with an optional header and footer,
/// like the grouped lists in iOS Settings.
class GroupedSection extends StatelessWidget {
  final String? header;
  final String? footer;
  final List<Widget> children;

  const GroupedSection({super.key, this.header, this.footer, required this.children});

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) rows.add(const Divider(indent: 18));
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
              child: Text(header!, style: context.text.labelMedium),
            ),
          Card(clipBehavior: Clip.antiAlias, child: Column(children: rows)),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
              child: Text(footer!, style: context.text.bodySmall),
            ),
        ],
      ),
    );
  }
}
