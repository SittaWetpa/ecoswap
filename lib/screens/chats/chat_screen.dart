import 'dart:async';

import 'package:flutter/material.dart';
import 'package:ecoswap/models/message.dart';
import '../../services/chat_service.dart';
import '../../widgets/qr_role_pick_modal.dart';

// ---------------------------------------------------------------------------
// Design tokens (EcoSwap Style Guide)
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kGreenDark = Color(0xFF0F6E56);
const _kGreenSoft = Color(0xFFE1F5EE);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

// ---------------------------------------------------------------------------
// Timestamp formatting
// ---------------------------------------------------------------------------

/// Formats a message's [sentAt] as a 24-hour `HH:mm` label for the bubble.
///
/// Returns '' when the timestamp is null — which is the case for a freshly
/// written message before Firestore resolves the server `sentAt`, so no
/// placeholder time is shown until the real value arrives.
String _formatMessageTime(DateTime? t) {
  if (t == null) return '';
  final local = t.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

// ---------------------------------------------------------------------------
// OptimisticMessage — WBS 9.4
// ---------------------------------------------------------------------------

/// Represents a locally-queued optimistic message that has not yet received
/// a Firestore acknowledgement.
///
/// [isSending] is `true` while the write is in-flight; it becomes `false`
/// once the [Future] returned by [onSend] completes successfully.
/// On error the message is removed from the list entirely.
class OptimisticMessage {
  final String id;
  final String text;
  final bool isSending;

  const OptimisticMessage({
    required this.id,
    required this.text,
    this.isSending = true,
  });

  OptimisticMessage copyWith({bool? isSending}) {
    return OptimisticMessage(
      id: id,
      text: text,
      isSending: isSending ?? this.isSending,
    );
  }
}

// ---------------------------------------------------------------------------
// ChatScreen
// ---------------------------------------------------------------------------

/// WBS 9.2 / 9.3 / 9.4 / 9.5 — Chat Screen UI with real-time listener,
/// optimistic send, and read receipts.
///
/// Displays message bubbles, a text input, and a sticky header with the
/// agreed-trade pill.  The "Ready to swap" CTA is gated:
/// it only appears once both parties have sent ≥ 3 messages each.
///
/// **WBS 9.3:** The screen subscribes to [messageStream] (or builds one from
/// [matchId] via [ChatService]) on init and cancels the subscription in
/// [dispose()] to avoid memory leaks. Messages are capped at 50 by the
/// service query.
///
/// All dependencies are injectable so the screen can be tested without
/// Firebase.
class ChatScreen extends StatefulWidget {
  /// The display name of the other party in the chat.
  final String otherDisplayName;

  /// Photo URL for the other party's avatar. Empty string shows initials.
  final String otherPhotoUrl;

  /// Human-readable name of the item the current user is giving.
  final String myItemName;

  /// Human-readable name of the item the current user will receive.
  final String theirItemName;

  /// The UID of the current user. Used to determine message alignment.
  final String currentUserId;

  /// The UID of the other party in this chat.
  ///
  /// Required for WBS 9.5 read-receipt logic: message bubbles check whether
  /// this UID appears in a message's `readBy` list to show the read indicator.
  /// Defaults to empty string so existing call sites remain backward compatible.
  final String otherUserId;

  /// Static message list — used by WBS 9.2 widget tests and as the initial
  /// display before the live stream emits its first batch.
  ///
  /// When [messageStream] is also provided, the stream takes over once it
  /// emits. When neither [messageStream] nor [matchId] is provided the screen
  /// stays with this static list (test-only mode).
  final List<Message> messages;

  /// Injectable live message stream (WBS 9.3).
  ///
  /// If provided, [_ChatScreenState] subscribes on init and cancels in
  /// dispose().  Takes priority over [matchId].
  ///
  /// In widget tests, pass a [StreamController.stream] here to feed messages
  /// without touching Firebase.
  final Stream<List<Message>>? messageStream;

  /// Match ID used to build a live stream via [ChatService] when
  /// [messageStream] is not provided. Optional — omit in tests.
  final String? matchId;

  /// True when this match's swap has already completed (status='completed').
  ///
  /// The chat is kept as the durable trade record and post-swap coordination
  /// channel — it is NOT deleted. When true the screen shows a "Swap
  /// completed" banner and replaces the Exchange CTA with a done indicator
  /// (re-scanning a completed match would fail server validation anyway:
  /// the token is single-use and the match is no longer 'active').
  final bool isCompleted;

  /// Injectable [ChatService]. Defaults to the production singleton.
  final ChatService? chatService;

  /// Called when the user taps the send button with non-empty text.
  /// Receives the trimmed message text.
  ///
  /// If this returns a [Future], the chat screen shows an optimistic
  /// "sending" indicator on the message until the Future resolves.
  final Future<void> Function(String text)? onSend;

  /// Called when the user taps the "Ready to swap" / Exchange button.
  final VoidCallback? onReadyExchange;

  /// Called when the user taps the back arrow.
  final VoidCallback? onBack;

  /// WBS 9.5 — called with the IDs of messages that need to be marked read.
  ///
  /// Triggered in [initState] and [didUpdateWidget] with every message whose
  /// [senderId] is not [currentUserId] and whose [readBy] does not yet contain
  /// [currentUserId].  Keeping Firestore out of the widget makes it testable.
  final void Function(List<String> messageIds)? onMarkRead;

  const ChatScreen({
    super.key,
    required this.otherDisplayName,
    this.otherPhotoUrl = '',
    required this.myItemName,
    required this.theirItemName,
    required this.currentUserId,
    this.otherUserId = '',
    this.messages = const [],
    this.messageStream,
    this.matchId,
    this.isCompleted = false,
    this.chatService,
    this.onSend,
    this.onReadyExchange,
    this.onBack,
    this.onMarkRead,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  // WBS 9.3 — live message list driven by Firestore stream.
  List<Message>? _liveMessages;
  StreamSubscription<List<Message>>? _messageSubscription;

  /// Locally-queued optimistic messages (WBS 9.4 optimistic UI).
  final List<OptimisticMessage> _optimisticMessages = [];
  int _optimisticIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    _subscribeToMessages();
    _triggerMarkRead(widget.messages);
  }

  @override
  void didUpdateWidget(ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageStream != widget.messageStream ||
        oldWidget.matchId != widget.matchId) {
      _messageSubscription?.cancel();
      _messageSubscription = null;
      _liveMessages = null;
      _subscribeToMessages();
    }
    if (oldWidget.messages != widget.messages) {
      _triggerMarkRead(widget.messages);
    }
  }

  /// Subscribe to the message stream, if one is available.
  ///
  /// Priority order:
  ///   1. [widget.messageStream] — caller-provided (tests or parent widget).
  ///   2. Build one from [widget.matchId] via [ChatService].
  ///   3. Nothing — stay with the static [widget.messages] list.
  void _subscribeToMessages() {
    Stream<List<Message>>? stream = widget.messageStream;

    if (stream == null && widget.matchId != null) {
      final service = widget.chatService ?? ChatService();
      stream = service.messageStream(widget.matchId!);
    }

    if (stream == null) return;

    _messageSubscription = stream.listen((msgs) {
      if (mounted) {
        setState(() {
          _liveMessages = msgs;
          _reconcileOptimistic(msgs);
        });
        _triggerMarkRead(msgs);
      }
    });
  }

  /// Drops optimistic messages once their real counterpart shows up in the
  /// live stream, so a just-sent message never renders twice (once as the
  /// local optimistic bubble, once from Firestore).
  ///
  /// Matches by text against the current user's messages in [liveMessages],
  /// consuming one match per optimistic entry so two identical texts sent in
  /// a row each reconcile against a distinct stream message.
  void _reconcileOptimistic(List<Message> liveMessages) {
    if (_optimisticMessages.isEmpty) return;
    final ownTexts = <String>[
      for (final m in liveMessages)
        if (m.senderId == widget.currentUserId) m.text,
    ];
    _optimisticMessages.removeWhere((opt) {
      final i = ownTexts.indexOf(opt.text);
      if (i != -1) {
        ownTexts.removeAt(i);
        return true;
      }
      return false;
    });
  }

  /// Collects IDs of incoming messages not yet read by [currentUserId] and
  /// fires [onMarkRead] if the list is non-empty.
  void _triggerMarkRead(List<Message> messages) {
    if (widget.onMarkRead == null) return;
    final unreadIds = messages
        .where(
          (m) =>
              m.senderId != widget.currentUserId &&
              !m.readBy.contains(widget.currentUserId),
        )
        .map((m) => m.id)
        .toList();
    if (unreadIds.isNotEmpty) {
      widget.onMarkRead!(unreadIds);
    }
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _messageSubscription = null;
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Handles the send action with optimistic UI (WBS 9.4).
  ///
  /// 1. Immediately appends an [OptimisticMessage] with `isSending = true`.
  /// 2. Clears the input field.
  /// 3. Awaits [onSend] — on completion marks the message as `isSending = false`.
  /// 4. On any error the optimistic message is silently removed.
  Future<void> _handleSend() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();

    final optimisticId = 'opt-${_optimisticIdCounter++}';

    setState(() {
      _optimisticMessages.add(
        OptimisticMessage(id: optimisticId, text: text, isSending: true),
      );
    });

    try {
      await widget.onSend?.call(text);

      if (mounted) {
        setState(() {
          final index = _optimisticMessages.indexWhere(
            (m) => m.id == optimisticId,
          );
          if (index != -1) {
            _optimisticMessages[index] = _optimisticMessages[index].copyWith(
              isSending: false,
            );
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == optimisticId);
        });
      }
    }
  }

  /// The effective message list: live stream data when available, otherwise
  /// the static list passed via [widget.messages].
  List<Message> get _effectiveMessages => _liveMessages ?? widget.messages;

  /// The "Ready to swap" CTA is visible until the swap completes. The exchange
  /// is an in-person action — both parties meet to scan each other's QR — so
  /// there is no value in gating the button behind a chat-volume threshold.
  /// (The earlier "both sides ≥ 3 messages" engagement gate was dropped by
  /// product decision; see WBS 9.2 / 9.6.) Once the match is completed the CTA
  /// is replaced by a "Swapped" indicator instead.
  bool get _readyVisible => !widget.isCompleted;

  /// WBS 9.6 — Called when the "Exchange" CTA is tapped.
  ///
  /// If [widget.onReadyExchange] is provided the caller handles navigation
  /// (used in tests to intercept routing without a real Navigator map).
  ///
  /// Otherwise, when [widget.matchId] is available, the QR role-pick modal is
  /// shown so the user can choose to show or scan the QR code.  The matchId is
  /// passed as the route argument to [kQRShowRoute] or [kQRScanRoute].
  void _handleReadyExchange(BuildContext context) {
    if (widget.onReadyExchange != null) {
      widget.onReadyExchange!();
      return;
    }
    final mid = widget.matchId;
    if (mid != null && mid.isNotEmpty) {
      QrRolePickModal.show(context, matchId: mid);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              otherDisplayName: widget.otherDisplayName,
              otherPhotoUrl: widget.otherPhotoUrl,
              myItemName: widget.myItemName,
              theirItemName: widget.theirItemName,
              showReadyCta: _readyVisible,
              isCompleted: widget.isCompleted,
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              onReadyExchange: () => _handleReadyExchange(context),
            ),
            if (widget.isCompleted) const _CompletedBanner(),
            Expanded(
              child: _MessageList(
                messages: _effectiveMessages,
                currentUserId: widget.currentUserId,
                otherUserId: widget.otherUserId,
                optimisticMessages: _optimisticMessages,
              ),
            ),
            _InputBar(
              controller: _controller,
              hasText: _hasText,
              onSend: _handleSend,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Header
// ---------------------------------------------------------------------------

class _Header extends StatelessWidget {
  final String otherDisplayName;
  final String otherPhotoUrl;
  final String myItemName;
  final String theirItemName;
  final bool showReadyCta;
  final bool isCompleted;
  final VoidCallback onBack;
  final VoidCallback? onReadyExchange;

  const _Header({
    required this.otherDisplayName,
    required this.otherPhotoUrl,
    required this.myItemName,
    required this.theirItemName,
    required this.showReadyCta,
    required this.isCompleted,
    required this.onBack,
    this.onReadyExchange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(bottom: BorderSide(color: _kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back arrow + avatar + name row
          Row(
            children: [
              // Back arrow (icon-only button: 40×40 tap area, 24px icon)
              SizedBox(
                width: 40,
                height: 40,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.arrow_back, size: 24),
                  color: _kTextPrimary,
                  onPressed: onBack,
                  tooltip: 'Back',
                ),
              ),
              // Avatar
              _Avatar(
                photoUrl: otherPhotoUrl,
                displayName: otherDisplayName,
                size: 36,
              ),
              const SizedBox(width: 8),
              // Name only — no "Active now" (out of scope per CLAUDE.md)
              Expanded(
                child: Text(
                  otherDisplayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _kTextPrimary,
                    height: 1.4,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          // Trade pill
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 0, 0),
            child: _TradePill(
              myItemName: myItemName,
              theirItemName: theirItemName,
              showReadyCta: showReadyCta,
              isCompleted: isCompleted,
              onReadyExchange: onReadyExchange,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _TradePill
// ---------------------------------------------------------------------------

class _TradePill extends StatelessWidget {
  final String myItemName;
  final String theirItemName;
  final bool showReadyCta;
  final bool isCompleted;
  final VoidCallback? onReadyExchange;

  const _TradePill({
    required this.myItemName,
    required this.theirItemName,
    required this.showReadyCta,
    this.isCompleted = false,
    this.onReadyExchange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _kSurfaceAlt,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // "Trade" label
          const Text(
            'Trade',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _kTextSecondary,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 6),
          // My item name
          Flexible(
            child: Text(
              myItemName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Swap arrow
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: Icon(Icons.swap_horiz, size: 14, color: _kGreenPrimary),
          ),
          // Their item name
          Flexible(
            child: Text(
              theirItemName,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kTextPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Exchange CTA while the swap is still open; once completed it is
          // replaced by a static "Swapped" indicator.
          if (showReadyCta) ...[
            const SizedBox(width: 8),
            _ReadyToSwapButton(onPressed: onReadyExchange),
          ] else if (isCompleted) ...[
            const SizedBox(width: 8),
            const _SwappedIndicator(),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SwappedIndicator — replaces the Exchange CTA once the swap is completed
// ---------------------------------------------------------------------------

class _SwappedIndicator extends StatelessWidget {
  const _SwappedIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _kGreenSoft,
        borderRadius: BorderRadius.circular(9999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 12, color: _kGreenDark),
          SizedBox(width: 4),
          Text(
            'Swapped',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kGreenDark,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _CompletedBanner — full-width strip shown at the top of a completed chat
// ---------------------------------------------------------------------------

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _kGreenSoft,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 16, color: _kGreenDark),
          SizedBox(width: 8),
          Flexible(
            child: Text(
              'Swap completed — this trade is done.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _kGreenDark,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ReadyToSwapButton
// ---------------------------------------------------------------------------

class _ReadyToSwapButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _ReadyToSwapButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        backgroundColor: _kGreenPrimary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: const StadiumBorder(),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: const Icon(Icons.qr_code, size: 12),
      label: const Text(
        'Exchange',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _MessageList
// ---------------------------------------------------------------------------

class _MessageList extends StatelessWidget {
  final List<Message> messages;
  final String currentUserId;
  final String otherUserId;

  /// Optimistic messages appended locally while Firestore writes are in-flight.
  /// Each entry carries an [isSending] flag that drives the status indicator.
  final List<OptimisticMessage> optimisticMessages;

  const _MessageList({
    required this.messages,
    required this.currentUserId,
    required this.otherUserId,
    this.optimisticMessages = const [],
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = messages.length + optimisticMessages.length;

    if (totalCount == 0) {
      return const SizedBox.expand();
    }

    // reverse: true renders item index 0 at the BOTTOM of the viewport and
    // keeps the list anchored there, which is the standard chat layout
    // (newest message at the bottom, visible without manual scrolling).
    //
    // The live [messages] arrive newest-first (the stream is ordered by
    // sentAt descending), so index 0 == newest maps directly onto the
    // bottom slot. Optimistic (in-flight) messages are newer still, so they
    // occupy the lowest indices — reversed among themselves so the most
    // recently sent sits at the very bottom.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < optimisticMessages.length) {
          // Optimistic message — always "own" (current user sent it).
          final opt = optimisticMessages[optimisticMessages.length - 1 - index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MessageBubble(
              key: ValueKey(opt.id),
              text: opt.text,
              isOwn: true,
              isSending: opt.isSending,
            ),
          );
        } else {
          final msg = messages[index - optimisticMessages.length];
          final isOwn = msg.senderId == currentUserId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MessageBubble(
              text: msg.text,
              isOwn: isOwn,
              readBy: msg.readBy,
              otherUserId: otherUserId,
              timeLabel: _formatMessageTime(msg.sentAt),
            ),
          );
        }
      },
    );
  }
}

// ---------------------------------------------------------------------------
// MessageBubble (public so tests can find it by type)
// ---------------------------------------------------------------------------

/// A single chat message bubble.
///
/// Own messages: right-aligned, green background, white text.
/// Other messages: left-aligned, surface-alt background, primary text.
///
/// Per the Style Guide:
/// - Max width 75% of screen
/// - Radius 12px, with the corner closest to the sender clipped to 6px
/// - Padding: 10px × 14px
///
/// WBS 9.4: own messages show a clock icon while the Firestore write is
/// in-flight, replaced by a checkmark once acknowledged.
///
/// WBS 9.5: own messages show a small "Read" indicator below the bubble once
/// [otherUserId] appears in [readBy].
class MessageBubble extends StatelessWidget {
  final String text;

  /// True when the message was sent by the current user.
  final bool isOwn;

  /// WBS 9.5 — the list of UIDs that have read this message.
  /// Defaults to empty so existing call sites remain backward compatible.
  final List<String> readBy;

  /// WBS 9.5 — UID of the other party; used to decide whether to show the
  /// read indicator.  Defaults to empty string for backward compat.
  final String otherUserId;

  /// WBS 9.4 — true while the Firestore write is in-flight (optimistic UI).
  /// Shows a clock icon; resolves to a checkmark once the write completes.
  final bool isSending;

  /// `HH:mm` timestamp shown at the bottom of the bubble. Empty string hides
  /// it (e.g. optimistic messages with no server timestamp yet).
  final String timeLabel;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isOwn,
    this.readBy = const [],
    this.otherUserId = '',
    this.isSending = false,
    this.timeLabel = '',
  });

  /// Whether the read indicator should be visible on this bubble.
  bool get _showReadIndicator =>
      isOwn && otherUserId.isNotEmpty && readBy.contains(otherUserId);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: isOwn
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOwn ? _kGreenPrimary : _kSurfaceAlt,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(14),
                  topRight: const Radius.circular(14),
                  // The corner nearest the sender is clipped (radius-sm = 6px)
                  bottomRight: Radius.circular(isOwn ? 6 : 14),
                  bottomLeft: Radius.circular(isOwn ? 14 : 6),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isOwn ? Colors.white : _kTextPrimary,
                    ),
                  ),
                  // Timestamp + (own only) optimistic status indicator:
                  // clock while sending, checkmark once acknowledged.
                  if (isOwn || timeLabel.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (timeLabel.isNotEmpty)
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 10,
                                height: 1.0,
                                color: isOwn
                                    ? Colors.white.withValues(alpha: 0.7)
                                    : _kTextTertiary,
                              ),
                            ),
                          if (isOwn) ...[
                            if (timeLabel.isNotEmpty) const SizedBox(width: 4),
                            Icon(
                              key: isSending
                                  ? const ValueKey('sending')
                                  : const ValueKey('sent'),
                              isSending ? Icons.access_time : Icons.check,
                              size: 10,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // WBS 9.5 — read indicator: only on own messages when the other
            // user has read this message. No presence/typing indicators.
            if (_showReadIndicator)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Read',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _kGreenPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _InputBar
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final bool hasText;
  final Future<void> Function() onSend;

  const _InputBar({
    required this.controller,
    required this.hasText,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kBorder)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Text input
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              style: const TextStyle(fontSize: 14, color: _kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Message...',
                hintStyle: const TextStyle(fontSize: 14, color: _kTextTertiary),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                filled: true,
                fillColor: _kSurfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9999),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9999),
                  borderSide: const BorderSide(color: _kBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9999),
                  borderSide: const BorderSide(color: _kGreenPrimary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button — 40×40 circle, disabled when empty
          _SendButton(hasText: hasText, onSend: onSend),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _SendButton
// ---------------------------------------------------------------------------

class _SendButton extends StatelessWidget {
  final bool hasText;
  final Future<void> Function() onSend;

  const _SendButton({required this.hasText, required this.onSend});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
      child: Material(
        color: hasText ? _kGreenPrimary : _kSurfaceAlt,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          // Disabled (null callback) when there is no text
          onTap: hasText ? onSend : null,
          child: Center(
            child: Icon(
              Icons.send,
              size: 18,
              color: hasText ? Colors.white : _kTextTertiary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _Avatar
// ---------------------------------------------------------------------------

class _Avatar extends StatelessWidget {
  final String photoUrl;
  final String displayName;
  final double size;

  const _Avatar({
    required this.photoUrl,
    required this.displayName,
    required this.size,
  });

  String get _initials {
    final parts = displayName.trim().split(' ');
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundImage: NetworkImage(photoUrl),
        backgroundColor: const Color(0xFFE1F5EE),
      );
    }
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: const Color(0xFFE1F5EE),
      child: Text(
        _initials,
        style: TextStyle(
          fontSize: size * 0.35,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF0F6E56),
        ),
      ),
    );
  }
}
