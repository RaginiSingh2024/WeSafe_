import 'dart:ui';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/community_chat_service.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:womensafteyhackfair/Dashboard/Community/CommunityChatScreen.dart';

class CommunityGroupsScreen extends StatefulWidget {
  const CommunityGroupsScreen({Key? key}) : super(key: key);

  @override
  State<CommunityGroupsScreen> createState() => _CommunityGroupsScreenState();
}

class _CommunityGroupsScreenState extends State<CommunityGroupsScreen>
    with SingleTickerProviderStateMixin {
  final CommunityChatService _chatService = CommunityChatService();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();

  Set<String> _joinedGroupIds = {};
  bool _isCreating = false;
  int _selectedTab = 0; // 0 = My Groups, 1 = Discover
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadJoinedGroups();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _areaController.dispose();
    super.dispose();
  }

  Future<void> _loadJoinedGroups() async {
    // 1. Load from local SharedPreferences first (instant update if available)
    final prefs = await SharedPreferences.getInstance();
    final localJoined = prefs.getStringList('joined_groups') ?? [];
    if (mounted) {
      setState(() {
        _joinedGroupIds = localJoined.toSet();
        if (localJoined.isNotEmpty) {
          _isLoading = false;
        }
      });
    }

    // 2. Fetch fresh list from Firestore (source of truth)
    final remoteJoined = await _chatService.fetchJoinedGroupIds();
    final remoteSet = remoteJoined.toSet();

    final hasChanges = _joinedGroupIds.length != remoteSet.length ||
        !_joinedGroupIds.every(remoteSet.contains);

    if (hasChanges) {
      await prefs.setStringList('joined_groups', remoteJoined);
    }

    if (mounted) {
      setState(() {
        _joinedGroupIds = remoteSet;
        _isLoading = false;
      });
    } else {
      _isLoading = false;
    }
  }

  Future<void> _joinGroup(String groupId) async {
    await _chatService.joinGroup(groupId);
    setState(() => _joinedGroupIds.add(groupId));
  }

  Future<void> _leaveGroup(String groupId) async {
    await _chatService.leaveGroup(groupId);
    setState(() => _joinedGroupIds.remove(groupId));
  }

  Future<void> _createAndJoinGroup() async {
    final city = _cityController.text.trim();
    if (city.isEmpty) return;
    final area = _areaController.text.trim();
    setState(() => _isCreating = true);
    final groupId =
        await _chatService.getOrCreateGroup(city: city, area: area);
    await _chatService.joinGroup(groupId);
    setState(() {
      _joinedGroupIds.add(groupId);
      _isCreating = false;
      _cityController.clear();
      _areaController.clear();
    });
    if (mounted) Navigator.pop(context);
  }

  void _openCreateGroupSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _buildCreateGroupSheet(),
    );
  }

  void _navigateToChat(String groupId, String groupName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CommunityChatScreen(groupId: groupId, groupName: groupName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightBackground,
      floatingActionButton: _buildFAB(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.lightBackground, AppColors.mutedBlushLavender],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 8),
              _buildSegmentedTab(),
              const SizedBox(height: 12),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _selectedTab == 0
                      ? _buildMyGroupsTab()
                      : _buildDiscoverTab(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // HEADER
  // ──────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.softLavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.groups_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Community Network',
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryDark,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      'Local safety groups near you',
                      style: GoogleFonts.poppins(
                        color: AppColors.mutedText,
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Stats / feature pills
          Row(
            children: [
              _pill(Icons.bolt_rounded, 'Real-time'),
              const SizedBox(width: 8),
              _pill(Icons.location_on_rounded, 'Location-based'),
              const SizedBox(width: 8),
              _pill(Icons.verified_rounded, 'Verified'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.softLavender),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: AppColors.primaryDark,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // CUSTOM SEGMENTED TAB (replaces broken TabBar)
  // ──────────────────────────────────────────────────────────────────

  // ──────────────────────────────────────────────────────────────────
  // REDESIGNED TAB SWITCHER
  // ──────────────────────────────────────────────────────────────────

  Widget _buildSegmentedTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _segmentBtn(0, Icons.bookmark_rounded, 'My Groups',
              '${_joinedGroupIds.length} joined'),
          const SizedBox(width: 10),
          _segmentBtn(1, Icons.explore_rounded, 'Discover', 'Find groups'),
        ],
      ),
    );
  }

  Widget _segmentBtn(
      int idx, IconData icon, String label, String subtitle) {
    final selected = _selectedTab == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          height: 64,
          decoration: BoxDecoration(
            gradient: selected
                ? const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.softLavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: selected ? null : Colors.white.withOpacity(0.55),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? Colors.transparent
                  : Colors.white.withOpacity(0.8),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? AppColors.primaryDark.withOpacity(0.28)
                    : Colors.black.withOpacity(0.03),
                blurRadius: selected ? 14 : 6,
                spreadRadius: selected ? 1 : 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withOpacity(0.18)
                        : AppColors.primaryDark.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 17,
                    color: selected
                        ? Colors.white
                        : AppColors.primaryDark.withOpacity(0.5),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        color: selected
                            ? Colors.white
                            : AppColors.primaryDark.withOpacity(0.75),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                        color: selected
                            ? Colors.white.withOpacity(0.65)
                            : AppColors.mutedText,
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  // ──────────────────────────────────────────────────────────────────
  // MY GROUPS TAB
  // ──────────────────────────────────────────────────────────────────

  Widget _buildMyGroupsTab() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryDark),
      );
    }
    if (_joinedGroupIds.isEmpty) return _buildJoinPrompt();

    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.streamAllGroups(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark));
        }
        final docs = snap.data!.docs
            .where((d) => _joinedGroupIds.contains(d.id))
            .toList();
        if (docs.isEmpty) return _buildJoinPrompt();
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            return _buildGroupCard(data, docs[i].id, isJoined: true);
          },
        );
      },
    );
  }

  Widget _buildJoinPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primaryDark.withOpacity(0.1),
                    AppColors.softLavender.withOpacity(0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.group_add_rounded,
                size: 48,
                color: AppColors.primaryDark.withOpacity(0.35),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Groups Yet',
              style: GoogleFonts.poppins(
                color: AppColors.primaryDark,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Join a local safety group to receive real-time emergency alerts from your community.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                color: AppColors.mutedText,
                fontSize: 13,
                height: 1.65,
              ),
            ),
            const SizedBox(height: 28),
            GestureDetector(
              onTap: () => setState(() => _selectedTab = 1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 14),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.softLavender],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.explore_rounded,
                        color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Discover Groups',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // DISCOVER TAB
  // ──────────────────────────────────────────────────────────────────

  Widget _buildDiscoverTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _chatService.streamAllGroups(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primaryDark));
        }
        if (!snap.hasData || snap.data!.docs.isEmpty) {
          return _buildNoGroupsState();
        }
        final docs = snap.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final data = docs[i].data() as Map<String, dynamic>;
            final isJoined = _joinedGroupIds.contains(docs[i].id);
            return _buildGroupCard(data, docs[i].id, isJoined: isJoined);
          },
        );
      },
    );
  }

  Widget _buildNoGroupsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: AppColors.primaryDark.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded,
                size: 44, color: AppColors.primaryDark.withOpacity(0.3)),
          ),
          const SizedBox(height: 20),
          Text(
            'No Groups Found',
            style: GoogleFonts.poppins(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to create a\nsafety group in your area!',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
              color: AppColors.mutedText,
              fontSize: 13,
              height: 1.55,
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _openCreateGroupSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.primaryDark.withOpacity(0.09),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: AppColors.primaryDark.withOpacity(0.15)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded,
                      color: AppColors.primaryDark, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    'Create Group',
                    style: GoogleFonts.poppins(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // GROUP CARD
  // ──────────────────────────────────────────────────────────────────

  Widget _buildGroupCard(
    Map<String, dynamic> data,
    String groupId, {
    required bool isJoined,
  }) {
    final name = data['name'] as String? ?? 'Community Group';
    final city = data['city'] as String? ?? '';
    final memberCount = (data['memberCount'] as num?)?.toInt() ?? 0;
    final hasEmergency = data['hasActiveEmergency'] == true;
    final creatorId = data['creatorId'] as String?;
    final isCreator = creatorId == null || creatorId == _chatService.currentUserId;

    return GestureDetector(
      onTap: isJoined ? () => _navigateToChat(groupId, name) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(hasEmergency ? 0.85 : 0.65),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: hasEmergency
                ? const Color(0xFFFF4444).withOpacity(0.45)
                : Colors.white.withOpacity(0.9),
            width: hasEmergency ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: hasEmergency
                  ? const Color(0xFFFF4444).withOpacity(0.12)
                  : AppColors.primaryDark.withOpacity(0.04),
              blurRadius: hasEmergency ? 20 : 10,
              spreadRadius: hasEmergency ? 1 : 0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icon badge
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          gradient: hasEmergency
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF3A004D),
                                    Color(0xFF8B1A4A)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : const LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.softLavender
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(
                          hasEmergency
                              ? Icons.warning_amber_rounded
                              : Icons.shield_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.poppins(
                                color: AppColors.primaryDark,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.place_rounded,
                                    size: 11,
                                    color: AppColors.softLavender),
                                const SizedBox(width: 3),
                                Text(
                                  city.isEmpty ? 'Unknown' : city,
                                  style: GoogleFonts.poppins(
                                    color: AppColors.mutedText,
                                    fontSize: 11,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                const Icon(Icons.people_alt_rounded,
                                    size: 11,
                                    color: AppColors.softLavender),
                                const SizedBox(width: 3),
                                Text(
                                  '$memberCount',
                                  style: GoogleFonts.poppins(
                                    color: AppColors.mutedText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (hasEmergency)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF4444).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color:
                                  const Color(0xFFFF4444).withOpacity(0.35),
                            ),
                          ),
                          child: Text(
                            '🚨 LIVE',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFFBB0000),
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Action buttons row
                  Row(
                    children: [
                      if (isJoined) ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _navigateToChat(groupId, name),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.softLavender
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDark
                                        .withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.chat_bubble_rounded,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Open Chat',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmLeave(groupId, name),
                          child: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.emergencyRed.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.emergencyRed
                                    .withOpacity(0.25),
                              ),
                            ),
                            child: Icon(Icons.logout_rounded,
                                size: 16,
                                color: AppColors.emergencyRed
                                    .withOpacity(0.7)),
                          ),
                        ),
                      ] else ...[
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _joinGroup(groupId),
                            child: Container(
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryDark,
                                    AppColors.softLavender
                                  ],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primaryDark
                                        .withOpacity(0.2),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_rounded,
                                      color: Colors.white, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Join Group',
                                    style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (isCreator) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDelete(groupId, name),
                          child: Container(
                            height: 38,
                            width: 38,
                            decoration: BoxDecoration(
                              color: Colors.red.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.red.withOpacity(0.25),
                              ),
                            ),
                            child: const Icon(Icons.delete_forever_rounded,
                                size: 18, color: Colors.red),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _confirmLeave(String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Leave Group?',
          style: GoogleFonts.poppins(
              color: AppColors.primaryDark, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'You will no longer receive emergency alerts from "$groupName".',
          style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _leaveGroup(groupId);
            },
            child: Text('Leave',
                style: GoogleFonts.poppins(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteGroup(String groupId) async {
    await _chatService.deleteGroup(groupId);
    setState(() {
      _joinedGroupIds.remove(groupId);
    });
  }

  void _confirmDelete(String groupId, String groupName) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.lightBackground,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete Group completely?',
          style: GoogleFonts.poppins(
              color: AppColors.primaryDark, fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will permanently delete "$groupName" and clear all of its messages and members.',
          style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style: GoogleFonts.poppins(color: AppColors.mutedText)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteGroup(groupId);
            },
            child: Text('Delete',
                style: GoogleFonts.poppins(
                    color: AppColors.emergencyRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // CREATE GROUP SHEET
  // ──────────────────────────────────────────────────────────────────

  Widget _buildCreateGroupSheet() {
    return StatefulBuilder(
      builder: (ctx, setSheetState) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            decoration: const BoxDecoration(
              color: Color(0xFFF5E8F0),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.primaryDark.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [
                            AppColors.primaryDark,
                            AppColors.softLavender
                          ],
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.group_add_rounded,
                          color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Create Safety Group',
                      style: GoogleFonts.poppins(
                        color: AppColors.primaryDark,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: Text(
                    'Set up a group for your city or local area.',
                    style: GoogleFonts.poppins(
                        color: AppColors.mutedText, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 24),
                _buildInputField(
                  controller: _cityController,
                  label: 'City *',
                  hint: 'e.g. Mumbai, Pune, Delhi',
                  icon: Icons.location_city_rounded,
                ),
                const SizedBox(height: 14),
                _buildInputField(
                  controller: _areaController,
                  label: 'Area / Campus (optional)',
                  hint: 'e.g. Panvel, VJTI Campus',
                  icon: Icons.place_rounded,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 4,
                      shadowColor: AppColors.primaryDark.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isCreating ? null : _createAndJoinGroup,
                    child: _isCreating
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            'Create & Join',
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w700, fontSize: 15),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            color: AppColors.primaryDark,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.softLavender.withOpacity(0.35)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(icon, size: 17, color: AppColors.softLavender),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.poppins(
                      fontSize: 14, color: AppColors.textDark),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.poppins(
                        color: AppColors.mutedText, fontSize: 13),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────
  // FAB
  // ──────────────────────────────────────────────────────────────────

  Widget _buildFAB() {
    return FloatingActionButton.extended(
      onPressed: _openCreateGroupSheet,
      backgroundColor: AppColors.primaryDark,
      elevation: 6,
      icon: const Icon(Icons.add_rounded, color: Colors.white),
      label: Text(
        'New Group',
        style: GoogleFonts.poppins(
            color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
      ),
    );
  }
}
