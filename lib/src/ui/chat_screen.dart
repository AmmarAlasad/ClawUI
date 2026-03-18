import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart' as chat_core;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:gpt_markdown/gpt_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mime/mime.dart';

import '../app/app_scope.dart';
import '../app/app_controller.dart';
import '../core/models.dart' as app_models;

// ─────────────────────────────────────────────────────────────────────
// Slash-command definitions — full OpenClaw command set
// ─────────────────────────────────────────────────────────────────────
class _SlashCommand {
  const _SlashCommand(this.command, this.label, this.icon);
  final String command;
  final String label;
  final IconData icon;
}

const List<_SlashCommand> _slashCommands = <_SlashCommand>[
  _SlashCommand('/status', 'Gateway status & diagnostics', Icons.monitor_heart_outlined),
  _SlashCommand('/help', 'Show available commands', Icons.help_outline_rounded),
  _SlashCommand('/skill', 'Run a skill — /skill <name> [input]', Icons.extension_outlined),
  _SlashCommand('/sessions', 'List active sessions', Icons.forum_outlined),
  _SlashCommand('/devices', 'List connected & pending devices', Icons.devices_other_outlined),
  _SlashCommand('/cron', 'Show cron job summary', Icons.schedule_outlined),
  _SlashCommand('/approve', 'Approve a pending device', Icons.check_circle_outline),
  _SlashCommand('/reject', 'Reject a pending device', Icons.cancel_outlined),
  _SlashCommand('/config', 'View or patch gateway config', Icons.settings_outlined),
  _SlashCommand('/logs', 'Show recent gateway logs', Icons.article_outlined),
  _SlashCommand('/restart', 'Restart the gateway process', Icons.restart_alt_rounded),
  _SlashCommand('/update', 'Check for & apply updates', Icons.system_update_outlined),
  _SlashCommand('/whoami', 'Show current operator identity', Icons.badge_outlined),
  _SlashCommand('/ping', 'Ping the gateway for latency', Icons.network_ping_rounded),
  _SlashCommand('/clear', 'Clear current session messages', Icons.clear_all_rounded),
  _SlashCommand('/run', 'Execute a raw shell command', Icons.terminal_rounded),
  _SlashCommand('/search', 'Search indexed documents', Icons.search_rounded),
  _SlashCommand('/model', 'Show or switch AI model', Icons.psychology_outlined),
  _SlashCommand('/memory', 'Manage persistent memory', Icons.memory_rounded),
  _SlashCommand('/schedule', 'Schedule a deferred task', Icons.event_outlined),
];

// ─────────────────────────────────────────────────────────────────────
// Helpers to detect if a message is pure tool output
// ─────────────────────────────────────────────────────────────────────
bool _isToolOutput(app_models.ChatMessage msg) {
  if (msg.role != app_models.MessageRole.system) return false;
  final String c = msg.content.trim();
  // Heuristic: system messages that look like raw tool dumps
  if (c.startsWith('{') && c.endsWith('}')) return true;
  if (c.startsWith('==') || c.contains('systemd units')) return true;
  if (c.contains('"tool":') || c.contains('"status":')) return true;
  // Long system messages > 80 chars with no sentences are likely tool output
  if (c.length > 80 && !c.contains('. ')) return true;
  return false;
}

// ─────────────────────────────────────────────────────────────────────
// ChatScreen
// ─────────────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final chat_core.InMemoryChatController _chatController =
      chat_core.InMemoryChatController();
  final TextEditingController _textController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<chat_core.Message> _lastMessages = const <chat_core.Message>[];
  AppController? _appController;

  bool _showAutocomplete = false;
  List<_SlashCommand> _filteredCommands = const <_SlashCommand>[];
  bool _showAttachMenu = false;
  bool _isPickerActive = false;
  bool _sendingInProgress = false;
  final List<XFile> _pendingAttachments = <XFile>[];

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AppController next = AppScope.of(context);
    if (next != _appController) {
      _appController?.removeListener(_onControllerChanged);
      _appController = next;
      _appController!.addListener(_onControllerChanged);
      _syncMessages(_appController!);
    }
  }

  @override
  void dispose() {
    _appController?.removeListener(_onControllerChanged);
    _chatController.dispose();
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) _syncMessages(_appController!);
  }

  void _onTextChanged() {
    final String text = _textController.text;
    if (text.startsWith('/') && !text.contains(' ')) {
      final String typed = text.toLowerCase();
      final List<_SlashCommand> matches = _slashCommands
          .where((_SlashCommand c) => c.command.startsWith(typed))
          .toList();
      if (matches.isNotEmpty) {
        setState(() {
          _showAutocomplete = true;
          _filteredCommands = matches;
        });
        return;
      }
    }
    if (_showAutocomplete) {
      setState(() {
        _showAutocomplete = false;
        _filteredCommands = const <_SlashCommand>[];
      });
    }
  }

  void _selectCommand(_SlashCommand cmd) {
    final bool needsArg =
        cmd.command == '/skill' || cmd.command == '/run' ||
        cmd.command == '/search' || cmd.command == '/schedule';
    _textController.text = needsArg ? '${cmd.command} ' : cmd.command;
    _textController.selection = TextSelection.fromPosition(
      TextPosition(offset: _textController.text.length),
    );
    setState(() {
      _showAutocomplete = false;
    });
    _focusNode.requestFocus();
  }

  Future<app_models.ChatAttachment> _toChatAttachment(XFile file) async {
    final List<int> bytes = await file.readAsBytes();
    final String base64String = base64Encode(bytes);
    final String mimeType = lookupMimeType(file.path) ?? 'application/octet-stream';
    return app_models.ChatAttachment(
      name: file.name,
      mimeType: mimeType,
      media: 'data:$mimeType;base64,$base64String',
    );
  }

  void _handleSend() async {
    if (_sendingInProgress) return;
    final String text = _textController.text.trim();
    if (text.isEmpty && _pendingAttachments.isEmpty) return;

    _sendingInProgress = true;

    // Snapshot attachments and clear UI immediately so a second tap can't race.
    final List<XFile> toEncode = List<XFile>.from(_pendingAttachments);
    _textController.clear();
    setState(() {
      _pendingAttachments.clear();
      _showAutocomplete = false;
      _showAttachMenu = false;
    });

    List<app_models.ChatAttachment> attachments = const <app_models.ChatAttachment>[];
    try {
      if (toEncode.isNotEmpty) {
        attachments = await Future.wait(
          toEncode.map((XFile f) => _toChatAttachment(f)),
        );
      }
    } catch (_) {
      // Encoding failed — send without attachments rather than silently dropping the message.
    } finally {
      _sendingInProgress = false;
    }

    unawaited(_appController?.sendMessage(text, attachments: attachments));
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickerActive) return;
    setState(() => _isPickerActive = true);
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 85,
      );
      if (image != null && mounted) {
        setState(() {
          _pendingAttachments.add(image);
          _showAttachMenu = false;
        });
      }
    } catch (e) {
      // Swallow already_active and other picker errors gracefully
    } finally {
      if (mounted) setState(() => _isPickerActive = false);
    }
  }

  Future<void> _pickFile() async {
    if (_isPickerActive) return;
    setState(() => _isPickerActive = true);
    try {
      final FilePickerResult? result = await FilePicker.platform.pickFiles(
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final PlatformFile file = result.files.first;
        if (file.path != null) {
          setState(() {
            _pendingAttachments.add(XFile(file.path!, name: file.name));
            _showAttachMenu = false;
          });
        } else if (file.bytes != null) {
          final Directory tempDir = Directory.systemTemp;
          final File tempFile = File('${tempDir.path}/${file.name}');
          await tempFile.writeAsBytes(file.bytes!);
          if (mounted) {
            setState(() {
              _pendingAttachments.add(XFile(tempFile.path, name: file.name));
              _showAttachMenu = false;
            });
          }
        }
      }
    } catch (e) {
      // Swallow already_active and other picker errors gracefully
    } finally {
      if (mounted) setState(() => _isPickerActive = false);
    }
  }

  // ─── Sync messages from AppController ─────────────────────────
  void _syncMessages(AppController app) {
    // Combine confirmed messages with the in-progress streaming message (if any).
    final List<app_models.ChatMessage> allMessages = <app_models.ChatMessage>[
      ...app.messages,
      if (app.streamingMessage != null) app.streamingMessage!,
    ];
    // Build the UI message list, merging consecutive tool-output system
    // messages into the preceding assistant message as metadata.
    final List<chat_core.Message> next = _buildMergedMessageList(
      allMessages,
      app.activeSessionKey,
    );
    if (_sameMessages(next, _lastMessages)) return;
    _lastMessages = next;
    unawaited(_chatController.setMessages(next, animated: false));
  }

  /// Merges consecutive system-role tool output messages into the
  /// preceding assistant message's metadata so they render as a
  /// compact tool icon instead of a separate orange bubble.
  List<chat_core.Message> _buildMergedMessageList(
    List<app_models.ChatMessage> raw,
    String sessionKey,
  ) {
    final List<chat_core.Message> out = <chat_core.Message>[];
    for (int i = 0; i < raw.length; i++) {
      final app_models.ChatMessage msg = raw[i];

      // If this system message looks like tool output, try to merge
      // it into the previous assistant message.
      if (_isToolOutput(msg) && out.isNotEmpty) {
        final chat_core.Message prev = out.last;
        if (prev is chat_core.TextMessage) {
          final Map<String, dynamic> meta =
              Map<String, dynamic>.from(prev.metadata ?? <String, dynamic>{});
          final List<dynamic> existingTools =
              List<dynamic>.from(meta['toolCalls'] as List<dynamic>? ?? <dynamic>[]);
          existingTools.add(<String, dynamic>{
            'name': 'Tool output',
            'summary': '',
            'output': msg.content,
          });
          meta['toolCalls'] = existingTools;
          // Replace the last message with updated metadata
          out[out.length - 1] = chat_core.Message.text(
            id: '${prev.id}-tc${existingTools.length}',
            authorId: prev.authorId,
            createdAt: prev.createdAt,
            sentAt: prev.sentAt,
            metadata: meta,
            text: prev.text,
          );
          continue; // skip adding this as a separate message
        }
      }

      out.add(_toUiMessage(msg, i, sessionKey));
    }
    return out;
  }

  bool _sameMessages(
    List<chat_core.Message> a,
    List<chat_core.Message> b,
  ) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
      // For streaming messages, also compare text so the bubble updates live.
      final chat_core.Message ma = a[i];
      final chat_core.Message mb = b[i];
      if (ma is chat_core.TextMessage && mb is chat_core.TextMessage) {
        if (ma.text != mb.text) return false;
      }
    }
    return true;
  }

  chat_core.Message _toUiMessage(
    app_models.ChatMessage message,
    int index,
    String sessionKey,
  ) {
    final DateTime ts = _tsFromLabel(message.timestampLabel, index);
    final String authorId = switch (message.role) {
      app_models.MessageRole.user => _currentUser.id,
      app_models.MessageRole.assistant => _ivyUser.id,
      app_models.MessageRole.system => _systemUser.id,
    };
    if (message.role == app_models.MessageRole.system) {
      return chat_core.Message.system(
        id: '$sessionKey-sys-$index-${message.content.hashCode}',
        authorId: authorId,
        createdAt: ts,
        text: message.content,
      );
    }
    String finalContent = message.content;
    if (message.attachments.isNotEmpty) {
      for (final app_models.ChatAttachment a in message.attachments) {
        finalContent += '\n[Attached ${a.mimeType.startsWith('image/') ? 'image' : 'file'}: ${a.name}]';
      }
    }

    // For streaming messages, use a time-based ID so the bubble updates
    // in-place as chunks arrive without creating new entries.
    final String msgId = message.isStreaming
        ? '$sessionKey-streaming-${message.role.name}'
        : '$sessionKey-${message.role.name}-$index-${message.content.hashCode}-${message.attachments.length}-${message.summary.hashCode}-${message.toolCalls.length}';

    return chat_core.Message.text(
      id: msgId,
      authorId: authorId,
      createdAt: ts,
      sentAt: ts,
      metadata: <String, dynamic>{
        'role': message.role.name,
        'summary': message.summary,
        'isStreaming': message.isStreaming,
        'attachments': <Map<String, dynamic>>[
          for (final app_models.ChatAttachment a in message.attachments)
            <String, dynamic>{
              'name': a.name,
              'mimeType': a.mimeType,
              'media': a.media,
            },
        ],
        'toolCalls': <Map<String, dynamic>>[
          for (final app_models.ChatToolCall tc in message.toolCalls)
            <String, dynamic>{
              'name': tc.name,
              'summary': tc.summary,
              'output': tc.output,
            },
        ],
      },
      text: finalContent,
    );
  }

  DateTime _tsFromLabel(String label, int index) {
    final String n = label.trim().toLowerCase();
    final DateTime now = DateTime.now();
    if (n == 'now' || n == 'just now') return now.subtract(Duration(seconds: index));
    final RegExpMatch? m = RegExp(r'^(\d+)m ago$').firstMatch(n);
    if (m != null) return now.subtract(Duration(minutes: int.parse(m.group(1)!)));
    final RegExpMatch? h = RegExp(r'^(\d+)h ago$').firstMatch(n);
    if (h != null) return now.subtract(Duration(hours: int.parse(h.group(1)!)));
    final RegExpMatch? d = RegExp(r'^(\d+)d ago$').firstMatch(n);
    if (d != null) return now.subtract(Duration(days: int.parse(d.group(1)!)));
    return now.subtract(Duration(minutes: index));
  }

  Future<chat_core.User> _resolveUser(String id) async {
    if (id == _currentUser.id) return _currentUser;
    if (id == _ivyUser.id) return _ivyUser;
    return _systemUser;
  }

  // ─── Build ───────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final AppController app = AppScope.of(context);
    final ThemeData theme = Theme.of(context);
    final List<app_models.SessionInfo> sessions =
        app.dashboard?.sessions ?? const <app_models.SessionInfo>[];
    final bool hasSelected = sessions.any(
      (app_models.SessionInfo s) => s.key == app.activeSessionKey,
    );
    final String? selectedKey = hasSelected
        ? app.activeSessionKey
        : (sessions.isNotEmpty ? sessions.first.key : null);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: theme.brightness == Brightness.dark
              ? const <Color>[Color(0xFF0E1016), Color(0xFF131720), Color(0xFF171B25)]
              : const <Color>[Color(0xFFF7F4F3), Color(0xFFF3EFEE), Color(0xFFF8F6F5)],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: <Widget>[
            _ChatHeader(
              sessions: sessions,
              selectedSessionKey: selectedKey,
              isSending: app.sendingMessage,
              onSessionChanged: (String k) => app.setActiveSessionKey(k),
              unreadKeys: app.sessionsWithUnread,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Chat(
                    currentUserId: _currentUser.id,
                    resolveUser: _resolveUser,
                    chatController: _chatController,
                    onMessageSend: (String t) => unawaited(app.sendMessage(t)),
                    builders: chat_core.Builders(
                      textMessageBuilder: _buildTextMessage,
                      systemMessageBuilder: _buildSystemMessage,
                      emptyChatListBuilder: _buildEmptyState,
                      composerBuilder: (_) => const SizedBox.shrink(),
                    ),
                    theme: chat_core.ChatTheme.fromThemeData(theme).copyWith(
                      shape: BorderRadius.circular(16),
                      colors: chat_core.ChatColors(
                        primary: theme.colorScheme.primary,
                        onPrimary: theme.colorScheme.onPrimary,
                        surface: Colors.transparent,
                        onSurface: theme.colorScheme.onSurface,
                        surfaceContainer: theme.cardTheme.color ?? theme.colorScheme.surface,
                        surfaceContainerLow: theme.colorScheme.surface,
                        surfaceContainerHigh: theme.colorScheme.surfaceContainerHigh,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            _buildComposer(theme),
          ],
        ),
      ),
    );
  }

  // ─── Custom Composer ────────────────────────────────────────────
  Widget _buildComposer(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // Slash autocomplete
          if (_showAutocomplete && _filteredCommands.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 240),
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
                boxShadow: <BoxShadow>[
                  BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, -4)),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: _filteredCommands.length,
                itemBuilder: (_, int i) {
                  final _SlashCommand cmd = _filteredCommands[i];
                  return InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _selectCommand(cmd),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(cmd.icon, size: 16, color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(cmd.command, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
                                Text(cmd.label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

          // Attachment preview
          if (_pendingAttachments.isNotEmpty)
            Container(
              height: 64,
              margin: const EdgeInsets.only(bottom: 8, left: 4, right: 4),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _pendingAttachments.length,
                itemBuilder: (BuildContext ctx, int i) {
                  final XFile file = _pendingAttachments[i];
                  final String? mime = lookupMimeType(file.path);
                  final bool isImage = mime?.startsWith('image/') ?? false;
                  return Container(
                    width: 60,
                    height: 60,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Stack(
                      children: <Widget>[
                        if (isImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.file(
                              File(file.path),
                              fit: BoxFit.cover,
                              width: 60,
                              height: 60,
                            ),
                          )
                        else
                          Center(
                            child: Icon(
                              Icons.insert_drive_file_rounded,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _pendingAttachments.removeAt(i)),
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.black54,
                                shape: BoxShape.circle,
                              ),
                              padding: const EdgeInsets.all(2),
                              child: const Icon(
                                Icons.close_rounded,
                                size: 10,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),

          // Attachment menu
          if (_showAttachMenu)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: <Widget>[
                  _AttachOption(icon: Icons.camera_alt_rounded, label: 'Camera', color: theme.colorScheme.primary, onTap: () => _pickImage(ImageSource.camera)),
                  _AttachOption(icon: Icons.photo_library_rounded, label: 'Gallery', color: Colors.orange, onTap: () => _pickImage(ImageSource.gallery)),
                  _AttachOption(icon: Icons.insert_drive_file_rounded, label: 'File', color: Colors.blueAccent, onTap: _pickFile),
                ],
              ),
            ),

          // Input row
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.12)),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
              ],
            ),
            child: Row(
              children: <Widget>[
                IconButton(
                  onPressed: () => setState(() => _showAttachMenu = !_showAttachMenu),
                  icon: AnimatedRotation(
                    turns: _showAttachMenu ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.add_circle_outline_rounded,
                      color: _showAttachMenu ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      size: 22,
                    ),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    style: theme.textTheme.bodyMedium,
                    maxLines: 4,
                    minLines: 1,
                    decoration: InputDecoration(
                      hintText: 'Message or / for commands',
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: _handleSend,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                      child: Icon(Icons.arrow_upward_rounded, size: 20, color: theme.colorScheme.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Text message builder ─────────────────────────────────────
  Widget _buildTextMessage(
    BuildContext context,
    chat_core.TextMessage message,
    int index, {
    required bool isSentByMe,
    chat_core.MessageGroupStatus? groupStatus,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isAssistant = message.authorId == _ivyUser.id;
    final Map<String, dynamic> meta = message.metadata ?? <String, dynamic>{};
    final String summary = (meta['summary'] as String? ?? '').trim();
    final List<dynamic> rawTools = meta['toolCalls'] as List<dynamic>? ?? const <dynamic>[];
    final List<dynamic> rawAttachments = meta['attachments'] as List<dynamic>? ?? const <dynamic>[];
    final bool isStreaming = meta['isStreaming'] as bool? ?? false;
    final String roleLabel = isSentByMe ? 'You' : (isAssistant ? 'Ivy' : 'OpenClaw');
    final IconData roleIcon = isSentByMe
        ? Icons.person_rounded
        : (isAssistant ? Icons.auto_awesome_rounded : Icons.hub_rounded);

    return RepaintBoundary(
      child: Align(
        alignment: isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
            decoration: BoxDecoration(
              color: isSentByMe
                  ? theme.colorScheme.primary
                  : (theme.cardTheme.color ?? theme.colorScheme.surface),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(20),
                topRight: const Radius.circular(20),
                bottomLeft: Radius.circular(isSentByMe ? 20 : 4),
                bottomRight: Radius.circular(isSentByMe ? 4 : 20),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(roleIcon, size: 13, color: isSentByMe ? theme.colorScheme.onPrimary.withValues(alpha: 0.7) : theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(roleLabel, style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: isSentByMe ? theme.colorScheme.onPrimary.withValues(alpha: 0.7) : theme.colorScheme.primary,
                    )),
                  ],
                ),
                const SizedBox(height: 6),
                if (!isSentByMe && summary.isNotEmpty) ...<Widget>[
                  _SummaryNote(summary: summary),
                  const SizedBox(height: 6),
                ],
                if (isStreaming && message.text.isEmpty)
                  const _TypingDots()
                else if (isSentByMe)
                  Text(message.text, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimary, height: 1.4))
                else if (isStreaming)
                  _StreamingText(text: message.text)
                else
                  GptMarkdown(message.text, style: theme.textTheme.bodyMedium?.copyWith(height: 1.45)),
                // Image attachments
                for (final dynamic att in rawAttachments)
                  if (att is Map<String, dynamic> &&
                      (att['mimeType'] as String? ?? '').startsWith('image/') &&
                      (att['media'] as String? ?? '').isNotEmpty) ...<Widget>[
                    const SizedBox(height: 8),
                    _AttachmentImage(media: att['media'] as String),
                  ],
                // Tool calls — ICON ONLY — tap to open bottom sheet
                if (!isSentByMe && rawTools.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  _ToolCallIcon(
                    count: rawTools.whereType<Map<String, dynamic>>().length,
                    toolCalls: rawTools.whereType<Map<String, dynamic>>().toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(
    BuildContext context,
    chat_core.SystemMessage message,
    int index, {
    required bool isSentByMe,
    chat_core.MessageGroupStatus? groupStatus,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(message.text, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('No messages yet.')));
  }
}

// ─────────────────────────────────────────────────────────────────────
// Attachment image widget — renders base64 data URIs and http(s) URLs
// ─────────────────────────────────────────────────────────────────────
class _AttachmentImage extends StatelessWidget {
  const _AttachmentImage({required this.media});
  final String media;

  @override
  Widget build(BuildContext context) {
    Widget img;
    if (media.startsWith('data:')) {
      final int commaIdx = media.indexOf(',');
      if (commaIdx < 0) return const SizedBox.shrink();
      final bytes = base64Decode(media.substring(commaIdx + 1));
      img = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (media.startsWith('http://') || media.startsWith('https://')) {
      img = Image.network(media, fit: BoxFit.cover);
    } else {
      return const SizedBox.shrink();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 260),
        child: img,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Typing / streaming indicators
// ─────────────────────────────────────────────────────────────────────
class _TypingDots extends StatefulWidget {
  const _TypingDots();
  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: 18,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List<Widget>.generate(3, (int i) {
          return AnimatedBuilder(
            animation: _ctrl,
            builder: (_, __) {
              final double phase = ((_ctrl.value * 3) - i).clamp(0.0, 1.0);
              final double opacity = 0.3 + 0.7 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: opacity),
                  shape: BoxShape.circle,
                ),
              );
            },
          );
        }),
      ),
    );
  }
}

/// Shows plain text while streaming (GptMarkdown needs complete Markdown).
class _StreamingText extends StatelessWidget {
  const _StreamingText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.45),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
const chat_core.User _currentUser = chat_core.User(id: 'operator', name: 'You');
const chat_core.User _ivyUser = chat_core.User(id: 'ivy', name: 'Ivy');
const chat_core.User _systemUser = chat_core.User(id: 'system', name: 'OpenClaw');

// ─────────────────────────────────────────────────────────────────────
// Header
// ─────────────────────────────────────────────────────────────────────
class _ChatHeader extends StatelessWidget {
  const _ChatHeader({
    required this.sessions,
    required this.selectedSessionKey,
    required this.isSending,
    required this.onSessionChanged,
    required this.unreadKeys,
  });
  final List<app_models.SessionInfo> sessions;
  final String? selectedSessionKey;
  final bool isSending;
  final ValueChanged<String> onSessionChanged;
  final Set<String> unreadKeys;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: sessions.isNotEmpty
                ? _SessionPicker(sessions: sessions, selectedKey: selectedSessionKey, onChanged: onSessionChanged, unreadKeys: unreadKeys)
                : Text('Chat', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          if (isSending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 1.5, color: theme.colorScheme.primary)),
                  const SizedBox(width: 6),
                  Text('Working…', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Session picker
// ─────────────────────────────────────────────────────────────────────
class _SessionPicker extends StatelessWidget {
  const _SessionPicker({
    required this.sessions,
    required this.selectedKey,
    required this.onChanged,
    this.unreadKeys = const <String>{},
  });
  final List<app_models.SessionInfo> sessions;
  final String? selectedKey;
  final ValueChanged<String> onChanged;
  final Set<String> unreadKeys;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final app_models.SessionInfo selected = sessions.firstWhere(
      (app_models.SessionInfo s) => s.key == selectedKey,
      orElse: () => sessions.first,
    );
    final bool anyUnread = sessions.any((app_models.SessionInfo s) =>
        s.key != selectedKey && unreadKeys.contains(s.key));
    return PopupMenuButton<String>(
      onSelected: onChanged,
      offset: const Offset(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 3,
      itemBuilder: (_) => sessions.map((app_models.SessionInfo s) {
        final bool hasUnread = s.key != selectedKey && unreadKeys.contains(s.key);
        return PopupMenuItem<String>(
          value: s.key,
          child: Row(
            children: <Widget>[
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: 14,
                color: s.key == selectedKey
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: s.key == selectedKey ? FontWeight.w700 : FontWeight.w400,
                    color: s.key == selectedKey ? theme.colorScheme.primary : null,
                  ),
                ),
              ),
              if (hasUnread)
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                )
              else if (s.key == selectedKey)
                Icon(Icons.check_rounded, size: 14, color: theme.colorScheme.primary),
            ],
          ),
        );
      }).toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: <Widget>[
            Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                Icon(Icons.chat_bubble_outline_rounded, size: 14, color: theme.colorScheme.primary),
                if (anyUnread)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: theme.colorScheme.surface, width: 1),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                selected.title,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(Icons.expand_more_rounded, size: 18, color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Attachment option
// ─────────────────────────────────────────────────────────────────────
class _AttachOption extends StatelessWidget {
  const _AttachOption({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 4),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Summary note (inline with message)
// ─────────────────────────────────────────────────────────────────────
class _SummaryNote extends StatelessWidget {
  const _SummaryNote({required this.summary});
  final String summary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF191D26) : const Color(0xFFF5F0EB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.summarize_rounded, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Expanded(child: Text(summary, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tool Call Icon — JUST an icon. Tap → bottom sheet with details.
// ─────────────────────────────────────────────────────────────────────
class _ToolCallIcon extends StatelessWidget {
  const _ToolCallIcon({required this.count, required this.toolCalls});
  final int count;
  final List<Map<String, dynamic>> toolCalls;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _openSheet(context),
      child: Tooltip(
        message: '$count tool call${count == 1 ? '' : 's'} — tap to view',
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: <Widget>[
              Center(child: Icon(Icons.account_tree_rounded, size: 17, color: theme.colorScheme.primary)),
              if (count > 1)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(color: theme.colorScheme.primary, shape: BoxShape.circle),
                    child: Center(
                      child: Text('$count', style: TextStyle(fontSize: 8, fontWeight: FontWeight.w800, color: theme.colorScheme.onPrimary)),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _openSheet(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.25,
        maxChildSize: 0.85,
        expand: false,
        builder: (_, ScrollController scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: theme.colorScheme.onSurface.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 14),
              Text('Tool Calls', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  controller: scroll,
                  itemCount: toolCalls.length,
                  itemBuilder: (_, int i) => _ToolCard(raw: toolCalls[i]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Tool card inside bottom sheet
// ─────────────────────────────────────────────────────────────────────
class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.raw});
  final Map<String, dynamic> raw;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String title = (raw['name'] as String? ?? raw['tool'] as String? ?? 'Tool call').trim();
    final String summary = (raw['summary'] as String? ?? '').trim();
    final String output = (raw['output'] as String? ?? raw['result'] as String? ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark ? const Color(0xFF14171F) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(color: theme.colorScheme.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.terminal_rounded, size: 15, color: theme.colorScheme.primary),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800))),
            ],
          ),
          if (summary.isNotEmpty) ...<Widget>[
            const SizedBox(height: 6),
            Text(summary, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.6))),
          ],
          if (output.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark ? const Color(0xFF0A0D14) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(output, style: theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace', fontSize: 11)),
            ),
          ],
        ],
      ),
    );
  }
}
