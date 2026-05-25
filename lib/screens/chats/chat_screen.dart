import 'package:flutter/material.dart';
import '../../models/message.dart';

// ---------------------------------------------------------------------------
// Design tokens (EcoSwap Style Guide)
// ---------------------------------------------------------------------------

const _kGreenPrimary = Color(0xFF1D9E75);
const _kSurface = Color(0xFFFFFFFF);
const _kSurfaceAlt = Color(0xFFF7F5F0);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);
const _kTextTertiary = Color(0xFFA0A09B);

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

/// WBS 9.2 — Chat Screen UI.
///
/// Displays message bubbles, a text input, and a sticky header with the
/// agreed-trade pill.  The "Ready to swap" CTA is gated:
/// it only appears once both parties have sent ≥ 3 messages each.
///
/// The screen accepts injectable dependencies so it can be tested without
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

  /// Pre-loaded list of messages to display.  In production this will come
  /// from a [StreamBuilder] wrapping [ChatService.messageStream] (WBS 9.3).
  final List<Message> messages;

  /// Called when the user taps the send button with non-empty text.
  /// Receives the trimmed message text.
  ///
  /// If this returns a [Future], the chat screen shows an optimistic
  /// "sending" indicator on the message until the Future resolves.
  /// Pass a synchronous `void Function(String)` or an async one —
  /// both are accepted.
  final Future<void> Function(String text)? onSend;

  /// Called when the user taps the "Ready to swap" / Exchange button.
  final VoidCallback? onReadyExchange;

  /// Called when the user taps the back arrow.
  final VoidCallback? onBack;

  const ChatScreen({
    super.key,
    required this.otherDisplayName,
    this.otherPhotoUrl = '',
    required this.myItemName,
    required this.theirItemName,
    required this.currentUserId,
    this.messages = const [],
    this.onSend,
    this.onReadyExchange,
    this.onBack,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _hasText = false;

  /// Locally-queued optimistic messages.  A message is added here immediately
  /// on send (WBS 9.4 optimistic UI requirement) and removed once the
  /// Firestore write is acknowledged via [onSend].
  final List<OptimisticMessage> _optimisticMessages = [];

  // Monotonically increasing counter for generating stable widget keys for
  // optimistic messages within this widget instance.
  int _optimisticIdCounter = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  /// Handles the send action with optimistic UI (WBS 9.4).
  ///
  /// 1. Immediately appends an [OptimisticMessage] with `isSending = true`.
  /// 2. Clears the input field.
  /// 3. Awaits [onSend] — on completion marks the message as `isSending = false`
  ///    (the "sent" state).
  /// 4. On any error the optimistic message is silently removed (in a real app
  ///    an error toast would follow, but that is out of scope for WBS 9.4).
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
      // On error, remove the optimistic message.
      if (mounted) {
        setState(() {
          _optimisticMessages.removeWhere((m) => m.id == optimisticId);
        });
      }
    }
  }

  /// Count how many messages were sent by [currentUserId].
  int get _myMessageCount =>
      widget.messages.where((m) => m.senderId == widget.currentUserId).length;

  /// Count how many messages were sent by anyone else.
  int get _theirMessageCount =>
      widget.messages.where((m) => m.senderId != widget.currentUserId).length;

  /// The "Ready to swap" CTA is visible only when both sides have ≥ 3 messages.
  bool get _readyVisible => _myMessageCount >= 3 && _theirMessageCount >= 3;

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
              onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
              onReadyExchange: widget.onReadyExchange,
            ),
            Expanded(
              child: _MessageList(
                messages: widget.messages,
                currentUserId: widget.currentUserId,
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
  final VoidCallback onBack;
  final VoidCallback? onReadyExchange;

  const _Header({
    required this.otherDisplayName,
    required this.otherPhotoUrl,
    required this.myItemName,
    required this.theirItemName,
    required this.showReadyCta,
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
  final VoidCallback? onReadyExchange;

  const _TradePill({
    required this.myItemName,
    required this.theirItemName,
    required this.showReadyCta,
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
          // "Ready to swap" CTA — gated by message count
          if (showReadyCta) ...[
            const SizedBox(width: 8),
            _ReadyToSwapButton(onPressed: onReadyExchange),
          ],
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

  /// Optimistic messages appended locally while Firestore writes are in-flight.
  /// Each entry carries an [isSending] flag that drives the status indicator.
  final List<OptimisticMessage> optimisticMessages;

  const _MessageList({
    required this.messages,
    required this.currentUserId,
    this.optimisticMessages = const [],
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = messages.length + optimisticMessages.length;

    if (totalCount == 0) {
      return const SizedBox.expand();
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: totalCount,
      itemBuilder: (context, index) {
        if (index < messages.length) {
          final msg = messages[index];
          final isOwn = msg.senderId == currentUserId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MessageBubble(text: msg.text, isOwn: isOwn),
          );
        } else {
          // Optimistic message — always "own" (current user sent it).
          final opt = optimisticMessages[index - messages.length];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: MessageBubble(
              key: ValueKey(opt.id),
              text: opt.text,
              isOwn: true,
              isSending: opt.isSending,
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
class MessageBubble extends StatelessWidget {
  final String text;

  /// True when the message was sent by the current user.
  final bool isOwn;

  /// True while the Firestore write is in-flight (optimistic UI, WBS 9.4).
  /// Shows a clock icon; resolves to a checkmark once the write completes.
  final bool isSending;

  const MessageBubble({
    super.key,
    required this.text,
    required this.isOwn,
    this.isSending = false,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Container(
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
              // Optimistic status indicator (WBS 9.4): clock while sending,
              // checkmark once acknowledged. Only shown on own messages.
              if (isOwn)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Icon(
                    key: isSending
                        ? const ValueKey('sending')
                        : const ValueKey('sent'),
                    isSending ? Icons.access_time : Icons.check,
                    size: 10,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
            ],
          ),
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
