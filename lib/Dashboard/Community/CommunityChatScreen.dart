import 'dart:ui';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:womensafteyhackfair/community_chat_service.dart';
import 'package:womensafteyhackfair/constants.dart';

class CommunityChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const CommunityChatScreen({
    Key? key,
    required this.groupId,
    required this.groupName,
  }) : super(key: key);

  @override
  State<CommunityChatScreen> createState() => _CommunityChatScreenState();
}

class _CommunityChatScreenState extends State<CommunityChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final CommunityChatService _chatService = CommunityChatService();

  bool _anonymous = false;
  bool _isSending = false;

  // Pulsing animation for emergency banner
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  // Pinned alert state
  Map<String, dynamic>? _groupData;
  StreamSubscription? _groupSub;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _listenToGroupData();
  }

  void _listenToGroupData() {
    _groupSub = FirebaseFirestore.instance
        .collection('community_groups')
        .doc(widget.groupId)
        .snapshots()
        .listen((snap) {
      if (mounted && snap.exists) {
        setState(() {
          _groupData = snap.data() as Map<String, dynamic>;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _msgController.dispose();
    _scrollController.dispose();
    _groupSub?.cancel();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty || _isSending) return;
    setState(() => _isSending = true);
    _msgController.clear();
    await _chatService.sendMessage(
      groupId: widget.groupId,
      content: text,
      anonymous: _anonymous,
    );
    setState(() => _isSending = false);
    _scrollToBottom();
  }

  Future<void> _launchMapLink(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatTime(dynamic timestamp) {
    if (timestamp == null) return '';
    DateTime dt;
    if (timestamp is Timestamp) {
      dt = timestamp.toDate();
    } else {
      return '';
    }
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final hasEmergency = _groupData?['hasActiveEmergency'] == true;

    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      appBar: _buildAppBar(hasEmergency),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.lightBackground, AppColors.mutedBlushLavender],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // ── Pinned Emergency Banner ──────────────────────────────────────
            if (hasEmergency) _buildPinnedEmergencyBanner(),

            // ── Message List ─────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _chatService.streamMessages(widget.groupId),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryDark,
                      ),
                    );
                  }
                  if (!snap.hasData || snap.data!.docs.isEmpty) {
                    return _buildEmptyState();
                  }

                  final docs = snap.data!.docs;
                  WidgetsBinding.instance
                      .addPostFrameCallback((_) => _scrollToBottom());

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: docs.length,
                    itemBuilder: (context, i) {
                      final data = docs[i].data() as Map<String, dynamic>;
                      final docId = docs[i].id;
                      final isOwn = data['senderId'] == currentUid;
                      final type = data['type'] as String? ?? 'text';

                      if (type == 'emergency') {
                        return _buildEmergencyCard(data, docId);
                      }
                      return _buildChatBubble(data, isOwn);
                    },
                  );
                },
              ),
            ),

            // ── Message Input ─────────────────────────────────────────────────
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // APP BAR
  // ────────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(bool hasEmergency) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.9),
            ),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.groupName,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (hasEmergency) ...[
                const SizedBox(width: 8),
                _buildLivePulse(),
              ],
            ],
          ),
          Text(
            hasEmergency ? '🚨 Active Emergency' : 'Community Safety Network',
            style: GoogleFonts.poppins(
              color: hasEmergency
                  ? const Color(0xFFFF9494)
                  : Colors.white.withOpacity(0.65),
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      actions: [
        // Anonymous toggle
        GestureDetector(
          onTap: () {
            setState(() => _anonymous = !_anonymous);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _anonymous
                      ? '🕵️ Anonymous mode ON'
                      : '👤 Sending as yourself',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                backgroundColor: AppColors.primaryDark,
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _anonymous
                  ? AppColors.softLavender.withOpacity(0.3)
                  : Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _anonymous
                    ? AppColors.softLavender
                    : Colors.white.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _anonymous
                      ? Icons.person_off_rounded
                      : Icons.person_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 4),
                Text(
                  _anonymous ? 'Anon' : 'You',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLivePulse() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFFFF4444).withOpacity(_pulseAnim.value),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // PINNED EMERGENCY BANNER
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildPinnedEmergencyBanner() {
    final mapLink = _groupData?['pinnedAlertMapLink'] as String? ?? '';
    final alertName = _groupData?['pinnedAlertUserName'] as String? ?? 'A user';

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3A004D), Color(0xFF8B1A4A)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFF4444).withOpacity(_pulseAnim.value),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF4444).withOpacity(_pulseAnim.value * 0.4),
              blurRadius: 16,
              spreadRadius: 2,
            ),
          ],
        ),
        child: child,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Text('🚨', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PINNED EMERGENCY',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFCCCC),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                    ),
                  ),
                  Text(
                    '$alertName needs help nearby',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if (mapLink.isNotEmpty)
              GestureDetector(
                onTap: () => _launchMapLink(mapLink),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.4)),
                  ),
                  child: Text(
                    'View Map',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // EMERGENCY CARD
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildEmergencyCard(Map<String, dynamic> data, String docId) {
    final content = data['content'] as String? ?? '';
    final mapLink = data['mapLink'] as String? ?? '';
    final responses = data['responses'] as Map<String, dynamic>? ?? {};
    final timeStr = _formatTime(data['timestamp']);

    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (_, child) => Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF3A004D), Color(0xFF8B1A4A), Color(0xFF6B0D3B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFFF4444).withOpacity(_pulseAnim.value),
            width: 2.5,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFAE4BB0).withOpacity(_pulseAnim.value * 0.5),
              blurRadius: 20,
              spreadRadius: 4,
            ),
          ],
        ),
        child: child,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                const Text('🚨', style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'EMERGENCY ALERT',
                    style: GoogleFonts.poppins(
                      color: const Color(0xFFFFCCCC),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF4444).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFFF4444).withOpacity(0.5)),
                  ),
                  child: Text(
                    'HIGH RISK',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              content,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.9),
                fontSize: 13,
                height: 1.6,
              ),
            ),
          ),

          // Map button
          if (mapLink.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: GestureDetector(
                onTap: () => _launchMapLink(mapLink),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'Open Live Location',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Response buttons
          _buildResponseButtons(data, docId),

          // Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Text(
              timeStr,
              style: GoogleFonts.poppins(
                color: Colors.white.withOpacity(0.45),
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponseButtons(Map<String, dynamic> data, String docId) {
    final responses = data['responses'] as Map<String, dynamic>? ?? {};

    final buttons = [
      _ResponseBtn(
        label: "I'm Safe",
        icon: '✅',
        key: 'im_safe',
        color: const Color(0xFF22C55E),
        count: (responses['im_safe'] as num?)?.toInt() ?? 0,
      ),
      _ResponseBtn(
        label: 'Going to Help',
        icon: '🏃',
        key: 'going_to_help',
        color: const Color(0xFFF59E0B),
        count: (responses['going_to_help'] as num?)?.toInt() ?? 0,
      ),
      _ResponseBtn(
        label: 'Notify Authorities',
        icon: '🚔',
        key: 'notified_authorities',
        color: const Color(0xFF3B82F6),
        count: (responses['notified_authorities'] as num?)?.toInt() ?? 0,
      ),
      _ResponseBtn(
        label: 'Share Alert',
        icon: '📢',
        key: 'shared',
        color: const Color(0xFFAE4BB0),
        count: (responses['shared'] as num?)?.toInt() ?? 0,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: buttons.map((btn) {
          return GestureDetector(
            onTap: () async {
              await _chatService.addResponse(
                groupId: widget.groupId,
                messageId: docId,
                responseType: btn.key,
              );
            },
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: btn.color.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: btn.color.withOpacity(0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(btn.icon, style: const TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(
                    '${btn.label}${btn.count > 0 ? ' (${btn.count})' : ''}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // CHAT BUBBLE
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildChatBubble(Map<String, dynamic> data, bool isOwn) {
    final name = data['senderName'] as String? ?? 'User';
    final content = data['content'] as String? ?? '';
    final isVerified = data['isVerified'] as bool? ?? false;
    final timeStr = _formatTime(data['timestamp']);

    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ClipRRect(
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isOwn ? 18 : 4),
            bottomRight: Radius.circular(isOwn ? 4 : 18),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isOwn
                    ? AppColors.primaryDark.withOpacity(0.82)
                    : Colors.white.withOpacity(0.58),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isOwn ? 18 : 4),
                  bottomRight: Radius.circular(isOwn ? 4 : 18),
                ),
                border: Border.all(
                  color: isOwn
                      ? AppColors.softLavender.withOpacity(0.35)
                      : Colors.white.withOpacity(0.6),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: isOwn
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  if (!isOwn)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.poppins(
                            color: AppColors.primaryDark,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 4),
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.softLavender,
                            size: 13,
                          ),
                        ],
                        const SizedBox(height: 2),
                      ],
                    ),
                  Text(
                    content,
                    style: GoogleFonts.poppins(
                      color: isOwn ? Colors.white : AppColors.textDark,
                      fontSize: 13.5,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeStr,
                    style: GoogleFonts.poppins(
                      color: isOwn
                          ? Colors.white.withOpacity(0.5)
                          : AppColors.mutedText,
                      fontSize: 9.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // INPUT BAR
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildInputBar() {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.65),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.5), width: 1),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.softLavender.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _msgController,
                          maxLines: 3,
                          minLines: 1,
                          textCapitalization: TextCapitalization.sentences,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: AppColors.textDark,
                          ),
                          decoration: InputDecoration(
                            hintText: _anonymous
                                ? 'Message anonymously...'
                                : 'Share a safety update...',
                            hintStyle: GoogleFonts.poppins(
                              color: AppColors.mutedText,
                              fontSize: 13,
                            ),
                            border: InputBorder.none,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _sendMessage,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryDark, AppColors.softLavender],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: _isSending
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ────────────────────────────────────────────────────────────────────────────

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.forum_rounded,
              size: 56,
              color: AppColors.primaryDark.withOpacity(0.4),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'No messages yet',
            style: GoogleFonts.poppins(
              color: AppColors.primaryDark,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share a safety update\nin your community.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.mutedText,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper model
class _ResponseBtn {
  final String label;
  final String icon;
  final String key;
  final Color color;
  final int count;

  const _ResponseBtn({
    required this.label,
    required this.icon,
    required this.key,
    required this.color,
    required this.count,
  });
}
