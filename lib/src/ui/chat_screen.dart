import 'package:flutter/material.dart';

import '../app/app_scope.dart';
import '../core/models.dart';
import 'widgets.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return ScreenScaffold(
      title: 'Chat',
      child: Column(
        children: <Widget>[
          const ClawCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SectionTitle('Quick prompts'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    Chip(label: Text('Show gateway status')),
                    Chip(label: Text('List pending device approvals')),
                    Chip(label: Text('Summarize cron issues')),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final ChatMessage item in app.messages)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Align(
                alignment: item.role == MessageRole.user
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: item.role == MessageRole.user
                          ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.16)
                          : Theme.of(context).cardTheme.color,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(item.content),
                        const SizedBox(height: 6),
                        Text(
                          item.timestampLabel,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText: 'Ask OpenClaw for status, jobs, or devices',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: app.sendingMessage
                    ? null
                    : () async {
                        final String value = _controller.text;
                        _controller.clear();
                        await app.sendMessage(value);
                      },
                child: app.sendingMessage
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
