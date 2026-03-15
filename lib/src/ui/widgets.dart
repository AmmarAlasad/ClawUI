import 'package:flutter/material.dart';

class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({
    required this.title,
    required this.child,
    this.actions = const <Widget>[],
    super.key,
  });

  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: Theme.of(context).brightness == Brightness.dark
              ? const <Color>[
                  Color(0xFF090D12),
                  Color(0xFF0E1720),
                  Color(0xFF08131A),
                ]
              : const <Color>[
                  Color(0xFFE8EEF5),
                  Color(0xFFDCE8F4),
                  Color(0xFFF5F9FC),
                ],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: <Widget>[
            SliverAppBar(
              pinned: true,
              title: Text(title),
              actions: actions,
              backgroundColor: Colors.transparent,
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
              sliver: SliverToBoxAdapter(child: child),
            ),
          ],
        ),
      ),
    );
  }
}

class ClawCard extends StatelessWidget {
  const ClawCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class MetricChip extends StatelessWidget {
  const MetricChip({required this.label, required this.value, super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return ClawCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(message),
          if (action != null) ...<Widget>[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}
