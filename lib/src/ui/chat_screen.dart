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
    final ThemeData theme = Theme.of(context);
    final List<SessionInfo> sessions = app.dashboard?.sessions ?? const <SessionInfo>[];
    final bool hasSelectedSession = sessions.any(
      (SessionInfo item) => item.key == app.activeSessionKey,
    );
    final String? selectedSessionKey = hasSelectedSession
        ? app.activeSessionKey
        : (sessions.isNotEmpty ? sessions.first.key : null);
    final List<ChatMessage> visibleMessages = app.messages.length > 30
        ? app.messages.sublist(app.messages.length - 30)
        : app.messages;
    const List<String> prompts = <String>[
      'Show gateway status',
      'List pending device approvals',
      'Summarize cron issues',
    ];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
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
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Chat',
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  if (sessions.isNotEmpty) ...<Widget>[
                    DropdownButtonFormField<String>(
                      key: ValueKey<String>(selectedSessionKey ?? 'no-session'),
                      initialValue: selectedSessionKey,
                      items: sessions.map((SessionInfo item) {
                        return DropdownMenuItem<String>(
                          value: item.key,
                          child: Text(
                            item.title,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (String? value) {
                        if (value != null) {
                          app.setActiveSessionKey(value);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Chat session',
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: prompts.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (BuildContext context, int index) {
                        final String prompt = prompts[index];
                        return ActionChip(
                          label: Text(prompt),
                          onPressed: () => app.sendQuickPrompt(prompt),
                        );
                      },
                    ),
                  ),
                  if (app.messages.length > visibleMessages.length) ...<Widget>[
                    const SizedBox(height: 12),
                    const ClawCard(
                      padding: EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Text(
                        'Showing the latest 30 messages to keep chat responsive.',
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                itemCount: visibleMessages.length,
                itemBuilder: (BuildContext context, int index) {
                  final ChatMessage item =
                      visibleMessages[visibleMessages.length - 1 - index];
                  final bool isUser = item.role == MessageRole.user;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Align(
                      alignment: isUser
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 320),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isUser
                                ? theme.colorScheme.primary.withValues(
                                    alpha: 0.16,
                                  )
                                : theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                isUser ? 'You' : 'ClawUI',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(item.content),
                              const SizedBox(height: 6),
                              Text(
                                item.timestampLabel,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 3,
                      textInputAction: TextInputAction.send,
                      onSubmitted: app.sendingMessage
                          ? null
                          : (String value) async {
                              _controller.clear();
                              await app.sendMessage(value);
                            },
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
            ),
          ],
        ),
      ),
    );
  }
}
