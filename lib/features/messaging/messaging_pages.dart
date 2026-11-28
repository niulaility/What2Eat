import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../student/theme/what2eat_theme.dart';
import 'messaging_models.dart';
import 'messaging_repository.dart';

const _green = What2EatTheme.forestGreen;
const _ink = What2EatTheme.darkGreenText;
const _cream = What2EatTheme.creamBackground;

ThemeData _chatTheme(BuildContext context) => Theme.of(context).copyWith(
  scaffoldBackgroundColor: _cream,
  colorScheme: ColorScheme.fromSeed(seedColor: _green),
  appBarTheme: const AppBarTheme(
    backgroundColor: _cream,
    foregroundColor: _ink,
    surfaceTintColor: Colors.transparent,
  ),
);

MessagingRepository _repository(MessagingRepository? supplied) =>
    supplied ?? SupabaseMessagingRepository(Supabase.instance.client);

String _time(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _day(DateTime date) => '${date.day}/${date.month}/${date.year}';

class _ChatNotice extends StatelessWidget {
  const _ChatNotice(this.message, {this.retry});
  final String message;
  final VoidCallback? retry;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: What2EatTheme.mutedText, height: 1.4),
        ),
        if (retry != null)
          TextButton(onPressed: retry, child: const Text('Try again')),
      ],
    ),
  );
}

class MessagesPage extends StatefulWidget {
  const MessagesPage({super.key, this.repository});
  final MessagingRepository? repository;
  @override
  State<MessagesPage> createState() => _MessagesPageState();
}

class _MessagesPageState extends State<MessagesPage>
    with WidgetsBindingObserver {
  MessagingRepository? _repo;
  ChatIdentity? _identity;
  List<ChatConversation> _threads = [];
  String? _error, _liveNotice;
  bool _loading = true, _fetching = false;
  bool _hasMore = false, _moreLoading = false, _covered = false;
  StreamSubscription<void>? _subscription;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _load();
      _watch();
    } else {
      _stop();
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _repo = _repository(widget.repository);
      _identity = await _repo!.identity();
      if (!mounted) return;
      await _load(reset: true);
      if (mounted) _watch();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = chatFailureText(error);
          _loading = false;
        });
      }
    }
  }

  void _mergeThreads(List<ChatConversation> rows, {bool reset = false}) {
    final combined = <String, ChatConversation>{
      if (!reset)
        for (final thread in _threads) thread.id: thread,
      for (final thread in rows) thread.id: thread,
    };
    _threads = combined.values.toList()
      ..sort((a, b) {
        final compare = b.updatedAt.compareTo(a.updatedAt);
        return compare == 0 ? b.id.compareTo(a.id) : compare;
      });
  }

  Future<void> _load({bool reset = false}) async {
    if (_repo == null || _fetching || _moreLoading) return;
    _fetching = true;
    try {
      final rows = await _repo!.conversations();
      if (mounted) {
        setState(() {
          _mergeThreads(rows, reset: reset);
          if (reset) {
            _hasMore = rows.length == SupabaseMessagingRepository.pageSize;
          }
          _error = null;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = chatFailureText(error);
          _loading = false;
        });
      }
    } finally {
      _fetching = false;
    }
  }

  Future<void> _more() async {
    if (_repo == null || _threads.isEmpty || _moreLoading || _fetching) return;
    setState(() => _moreLoading = true);
    try {
      final rows = await _repo!.conversations(before: _threads.last);
      if (mounted) {
        setState(() {
          _mergeThreads(rows);
          _hasMore = rows.length == SupabaseMessagingRepository.pageSize;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = chatFailureText(error));
    } finally {
      if (mounted) setState(() => _moreLoading = false);
    }
  }

  void _watch() {
    if (_repo == null ||
        _identity == null ||
        _subscription != null ||
        _covered) {
      return;
    }
    _subscription = _repo!.changes().listen(
      (_) {
        if (mounted) {
          setState(() => _liveNotice = null);
          _load();
        }
      },
      onError: (Object error) {
        if (mounted) setState(() => _liveNotice = chatFailureText(error));
      },
    );
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _load());
  }

  Future<void> _open(ChatConversation thread) async {
    if (_covered) return;
    _covered = true;
    _stop();
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            ConversationPage(conversation: thread, repository: _repo),
      ),
    );
    if (mounted) {
      _covered = false;
      await _load();
      _watch();
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: _chatTheme(context),
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh messages',
            onPressed: _loading ? null : _initialize,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _threads.isEmpty
          ? Center(child: _ChatNotice(_error!, retry: _initialize))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                key: const ValueKey('conversation-list'),
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                children: [
                  if (_liveNotice != null || _error != null)
                    _ChatNotice(_error ?? _liveNotice!, retry: _load),
                  if (_threads.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 64),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.chat_bubble_outline,
                            size: 40,
                            color: _green,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No conversations yet',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _identity?.role == ChatRole.vendor
                                ? 'Customer messages will appear here.'
                                : 'Open a vendor’s page and tap Message vendor to start.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: What2EatTheme.mutedText,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final thread in _threads)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Material(
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: const BorderSide(color: What2EatTheme.border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: ListTile(
                          key: ValueKey('conversation-${thread.id}'),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          leading: CircleAvatar(
                            backgroundColor: What2EatTheme.softSurfaceAlt,
                            child: Icon(
                              _identity?.role == ChatRole.vendor
                                  ? Icons.person_outline
                                  : Icons.storefront_outlined,
                              color: _green,
                            ),
                          ),
                          title: Text(
                            thread.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: _ink,
                            ),
                          ),
                          subtitle: Text(
                            thread.lastMessage?.content ??
                                'Start the conversation',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _day(thread.updatedAt),
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: What2EatTheme.mutedText,
                                ),
                              ),
                              if (thread.hasUnread(_identity!.userId))
                                Padding(
                                  padding: EdgeInsets.only(top: 4),
                                  child: Semantics(
                                    label: 'Unread message',
                                    child: Icon(
                                      Icons.circle,
                                      color: _green,
                                      size: 10,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onTap: () => _open(thread),
                        ),
                      ),
                    ),
                  if (_hasMore)
                    TextButton(
                      onPressed: _moreLoading ? null : _more,
                      child: Text(
                        _moreLoading ? 'Loading…' : 'Load more conversations',
                      ),
                    ),
                ],
              ),
            ),
    ),
  );
}

class MessageVendorButton extends StatelessWidget {
  const MessageVendorButton({
    super.key,
    required this.vendorId,
    required this.vendorName,
    this.repository,
  });
  final String vendorId, vendorName;
  final MessagingRepository? repository;
  @override
  Widget build(BuildContext context) => FilledButton.icon(
    key: const ValueKey('message-vendor'),
    style: FilledButton.styleFrom(
      backgroundColor: _green,
      foregroundColor: _cream,
      minimumSize: const Size(0, 48),
    ),
    onPressed: !isChatEntityId(vendorId)
        ? null
        : () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => ConversationPage(
                vendorId: vendorId,
                vendorName: vendorName,
                repository: repository,
              ),
            ),
          ),
    icon: const Icon(Icons.chat_bubble_outline),
    label: const Text('Message vendor'),
  );
}

class _PendingMessage {
  _PendingMessage(this.id, this.content) : createdAt = DateTime.now();
  final String id, content;
  final DateTime createdAt;
  String? failure;
}

class ConversationPage extends StatefulWidget {
  const ConversationPage({
    super.key,
    this.conversation,
    this.vendorId,
    this.vendorName,
    this.repository,
  }) : assert(conversation != null || vendorId != null);
  final ChatConversation? conversation;
  final String? vendorId, vendorName;
  final MessagingRepository? repository;
  @override
  State<ConversationPage> createState() => _ConversationPageState();
}

class _ConversationPageState extends State<ConversationPage>
    with WidgetsBindingObserver {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  final Map<String, ChatMessage> _messages = {};
  final Map<String, _PendingMessage> _pending = {};
  MessagingRepository? _repo;
  ChatIdentity? _identity;
  ChatConversation? _thread;
  StreamSubscription<void>? _subscription;
  Timer? _poll;
  bool _loading = true,
      _fetching = false,
      _sending = false,
      _olderLoading = false,
      _hasOlder = false,
      _marking = false;
  String? _error, _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _stop() {
    _poll?.cancel();
    _poll = null;
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refresh();
      _watch();
    } else {
      _stop();
    }
  }

  Future<void> _initialize() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      _repo = _repository(widget.repository);
      _identity = await _repo!.identity();
      final thread = widget.conversation == null
          ? await _repo!.startConversation(widget.vendorId!)
          : await _repo!.conversation(widget.conversation!.id);
      if (!mounted) return;
      _thread = thread;
      final rows = await _repo!.messages(thread.id);
      if (!mounted) return;
      setState(() {
        _merge(rows);
        _hasOlder = rows.length == SupabaseMessagingRepository.pageSize;
        _loading = false;
      });
      _read();
      _watch();
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = chatFailureText(error);
          _loading = false;
        });
      }
    }
  }

  void _merge(List<ChatMessage> rows) {
    for (final message in rows) {
      _messages[message.id] = message;
      _pending.remove(message.id);
    }
  }

  Future<void> _refresh() async {
    if (_repo == null || _thread == null || _fetching || _loading) return;
    _fetching = true;
    try {
      final thread = await _repo!.conversation(_thread!.id);
      final rows = await _repo!.messages(thread.id);
      if (!mounted) return;
      setState(() {
        _thread = thread;
        _merge(rows);
        _error = null;
      });
      _read();
      _watch();
    } catch (error) {
      if (mounted) setState(() => _error = chatFailureText(error));
    } finally {
      _fetching = false;
    }
  }

  Future<void> _read() async {
    if (_repo == null || _thread == null || _marking) return;
    _marking = true;
    try {
      await _repo!.markRead(_thread!.id);
    } catch (_) {
      if (mounted) {
        setState(
          () => _notice =
              'Messages loaded, but read status could not be updated.',
        );
      }
    } finally {
      _marking = false;
    }
  }

  void _watch() {
    if (_repo == null || _thread == null || _subscription != null) return;
    _subscription = _repo!
        .changes(conversationId: _thread!.id)
        .listen(
          (_) {
            if (mounted) {
              setState(() => _notice = null);
              _refresh();
            }
          },
          onError: (Object error) {
            if (mounted) setState(() => _notice = chatFailureText(error));
          },
        );
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => _refresh());
  }

  Future<void> _older() async {
    if (_olderLoading ||
        _messages.isEmpty ||
        _repo == null ||
        _thread == null) {
      return;
    }
    setState(() => _olderLoading = true);
    final ordered = _messages.values.toList()
      ..sort((a, b) {
        final compare = a.createdAt.compareTo(b.createdAt);
        return compare == 0 ? a.id.compareTo(b.id) : compare;
      });
    try {
      final rows = await _repo!.messages(_thread!.id, before: ordered.first);
      if (mounted) {
        setState(() {
          _merge(rows);
          _hasOlder = rows.length == SupabaseMessagingRepository.pageSize;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = chatFailureText(error));
    } finally {
      if (mounted) setState(() => _olderLoading = false);
    }
  }

  void _send() {
    if (_sending || _thread?.canSend != true || _repo == null) return;
    final validation = validateChatMessage(_composer.text);
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    final pending = _PendingMessage(newChatMessageId(), _composer.text.trim());
    setState(() {
      _pending[pending.id] = pending;
      _error = null;
    });
    _composer.clear();
    if (_scroll.hasClients) _scroll.jumpTo(0);
    _deliver(pending);
  }

  Future<void> _deliver(_PendingMessage pending) async {
    if (_sending || _repo == null || _thread?.canSend != true) return;
    setState(() {
      _sending = true;
      pending.failure = null;
    });
    try {
      final sent = await _repo!.send(
        _thread!.id,
        pending.content,
        clientId: pending.id,
      );
      if (mounted) setState(() => _merge([sent]));
    } catch (error) {
      if (mounted && !_messages.containsKey(pending.id)) {
        setState(() => pending.failure = chatFailureText(error));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Widget _bubble(ChatMessage message, {_PendingMessage? pending}) {
    final own = message.senderId == _identity!.userId;
    return Align(
      alignment: own ? Alignment.centerRight : Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: .88,
        child: Container(
          key: ValueKey('chat-message-${message.id}'),
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: own ? _green : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: own ? null : Border.all(color: What2EatTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                message.content,
                style: TextStyle(
                  color: own ? _cream : _ink,
                  fontSize: 16,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_day(message.createdAt)} · ${_time(message.createdAt)}${own
                    ? pending != null
                          ? pending.failure == null
                                ? ' · Sending…'
                                : ' · Not sent'
                          : message.isRead
                          ? ' · Read'
                          : ' · Sent'
                    : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: own ? _cream : What2EatTheme.mutedText,
                ),
              ),
              if (pending?.failure != null) ...[
                const SizedBox(height: 8),
                Text(
                  pending!.failure!,
                  style: const TextStyle(color: _cream, height: 1.4),
                ),
                TextButton(
                  key: ValueKey('retry-message-${pending.id}'),
                  style: TextButton.styleFrom(foregroundColor: _cream),
                  onPressed: _sending || _thread?.canSend != true
                      ? null
                      : () => _deliver(pending),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _history() {
    final rows =
        <ChatMessage>[
          ..._messages.values,
          for (final draft in _pending.values)
            ChatMessage(
              id: draft.id,
              conversationId: _thread!.id,
              senderId: _identity!.userId,
              content: draft.content,
              createdAt: draft.createdAt,
            ),
        ]..sort((a, b) {
          final compare = b.createdAt.compareTo(a.createdAt);
          return compare == 0 ? b.id.compareTo(a.id) : compare;
        });
    if (rows.isEmpty) {
      return const Center(
        child: SingleChildScrollView(
          child: _ChatNotice(
            'Start the conversation. Ask about the menu, an order or pickup.',
          ),
        ),
      );
    }
    return ListView.builder(
      key: const ValueKey('chat-history'),
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.all(16),
      itemCount: rows.length + (_hasOlder ? 1 : 0),
      itemBuilder: (_, index) => index == rows.length
          ? TextButton(
              key: const ValueKey('load-older-messages'),
              onPressed: _olderLoading ? null : _older,
              child: Text(_olderLoading ? 'Loading…' : 'Load earlier messages'),
            )
          : _bubble(rows[index], pending: _pending[rows[index].id]),
    );
  }

  Widget _input() => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: _thread?.canSend != true
          ? const _ChatNotice(
              'This conversation is read-only while the vendor or customer is unavailable.',
            )
          : ValueListenableBuilder<TextEditingValue>(
              valueListenable: _composer,
              builder: (_, value, _) => Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('message-composer'),
                      controller: _composer,
                      minLines: 1,
                      maxLines:
                          (((MediaQuery.sizeOf(context).height -
                                          MediaQuery.viewInsetsOf(context)
                                              .bottom -
                                          104) *
                                      .4) /
                                  MediaQuery.textScalerOf(context).scale(24))
                              .floor()
                              .clamp(1, 5),
                      maxLength: maxChatMessageLength,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: 'Message',
                        hintText: 'Write a message…',
                        counterText: value.text.length > 1800 ? null : '',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    key: const ValueKey('send-message'),
                    tooltip: 'Send message',
                    style: IconButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: _cream,
                      minimumSize: const Size(48, 48),
                    ),
                    onPressed: value.text.trim().isEmpty || _sending
                        ? null
                        : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: _cream,
                            ),
                          )
                        : const Icon(Icons.send_outlined),
                  ),
                ],
              ),
            ),
    ),
  );

  @override
  Widget build(BuildContext context) => Theme(
    data: _chatTheme(context),
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          _thread?.name ??
              widget.conversation?.name ??
              widget.vendorName ??
              'Conversation',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh conversation',
            onPressed: _loading
                ? null
                : _thread == null
                ? _initialize
                : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _thread == null || _identity == null
          ? Center(
              child: _ChatNotice(
                _error ?? 'Could not open conversation.',
                retry: _initialize,
              ),
            )
          : LayoutBuilder(
              builder: (_, constraints) => Column(
                children: [
                  if (_error != null || _notice != null)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: (constraints.maxHeight - 112).clamp(0, 120),
                      ),
                      child: SingleChildScrollView(
                        child: _ChatNotice(_error ?? _notice!, retry: _refresh),
                      ),
                    ),
                  Expanded(child: _history()),
                  _input(),
                ],
              ),
            ),
    ),
  );
}
