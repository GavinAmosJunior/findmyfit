import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A tab's large title. It sits big and bold above the content and
/// shrinks into a slim bar as you scroll, like large titles on iPhone.
class LargeTitle extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const LargeTitle({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SliverAppBar(
      pinned: true,
      expandedHeight: 112,
      backgroundColor: context.colors.surface,
      surfaceTintColor: Colors.transparent,
      actions: [...?actions, const SizedBox(width: 8)],
      flexibleSpace: FlexibleSpaceBar(
        // A faint blue wash behind the title that fades into the page
        // before the content starts, and fades out as the title shrinks.
        background: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? [const Color(0xFF13254A), const Color(0xFF0A1428), context.colors.surface]
                  : [const Color(0xFFD6E4FD), const Color(0xFFEAF1FE), context.colors.surface],
              stops: const [0, 0.55, 1],
            ),
          ),
        ),
        centerTitle: false,
        titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
        expandedTitleScale: 1.75,
        title: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4),
        ),
      ),
    );
  }
}

/// A large title for a screen that doesn't scroll: the same look as
/// [LargeTitle] at rest, with its blue wash, without the collapsing.
class StaticTitle extends StatelessWidget {
  final String title;
  final List<Widget>? actions;

  const StaticTitle({super.key, required this.title, this.actions});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [const Color(0xFF13254A), const Color(0xFF0A1428), context.colors.surface]
              : [const Color(0xFFD6E4FD), const Color(0xFFEAF1FE), context.colors.surface],
          stops: const [0, 0.55, 1],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 52,
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [...?actions, const SizedBox(width: 8)]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium?.copyWith(fontSize: 31.5, fontWeight: FontWeight.w700, letterSpacing: -0.9),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The title of a pushed screen: a name, and a quiet line under it.
class BarTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const BarTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.titleMedium),
        if (subtitle != null)
          Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
      ],
    );
  }
}

/// A bold section heading inside a scroll view ("At the laundry now").
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;

  const SectionTitle(this.text, {super.key, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 12, 10),
      child: Row(
        children: [
          Expanded(child: Text(text, style: context.text.titleLarge)),
          ?trailing,
        ],
      ),
    );
  }
}
