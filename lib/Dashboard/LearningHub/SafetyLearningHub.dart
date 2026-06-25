import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:womensafteyhackfair/Dashboard/LearningHub/EmbeddedYouTubePlayer.dart';

class SafetyVideo {
  final String id;
  final String title;
  final String category;
  final String duration;
  final String youtubeUrl;

  SafetyVideo({
    required this.id,
    required this.title,
    required this.category,
    required this.duration,
    required this.youtubeUrl,
  });

  String get thumbnailUrl => 'https://img.youtube.com/vi/$id/mqdefault.jpg';
}

class SafetyLearningHubScreen extends StatefulWidget {
  const SafetyLearningHubScreen({Key? key}) : super(key: key);

  @override
  State<SafetyLearningHubScreen> createState() => _SafetyLearningHubScreenState();
}

class _SafetyLearningHubScreenState extends State<SafetyLearningHubScreen> {
  // Curated lists
  final List<SafetyVideo> _allVideos = [
    SafetyVideo(
      id: 'lfqaVsLF4V0',
      title: 'Self Defense Training Video 1',
      category: 'Self-Defense Essentials',
      duration: '5:12',
      youtubeUrl: 'https://youtu.be/lfqaVsLF4V0',
    ),
    SafetyVideo(
      id: 'nT3OERfppmc',
      title: 'Self Defense Training Video 2',
      category: 'Self-Defense Essentials',
      duration: '4:30',
      youtubeUrl: 'https://youtu.be/nT3OERppmc',
    ),
    SafetyVideo(
      id: 'EgTTmcVY5lk',
      title: 'Travel Safety Guide 1',
      category: 'Travel Safety',
      duration: '8:45',
      youtubeUrl: 'https://youtu.be/EgTTmcVY5lk',
    ),
    SafetyVideo(
      id: 'FkDCIb_UygM',
      title: 'Travel Safety Guide 2',
      category: 'Travel Safety',
      duration: '6:20',
      youtubeUrl: 'https://youtu.be/FkDCIb_UygM',
    ),
    SafetyVideo(
      id: 'XP3AJx_Jb90',
      title: "Don't Panic in Emergency Situations",
      category: 'Stay Calm & Think Smart',
      duration: '7:15',
      youtubeUrl: 'https://youtu.be/XP3AJx_Jb90',
    ),
  ];

  final List<Map<String, String>> _categories = [
    {
      'name': 'Self-Defense Essentials',
      'description': 'Learn basic self-defense techniques and escape methods that can help during dangerous situations.',
      'icon': '🛡️',
    },
    {
      'name': 'Travel Safety',
      'description': 'Learn how to stay safe while traveling alone, using public transport, taxis, or ride-sharing services.',
      'icon': '🚗',
    },
    {
      'name': 'Stay Calm & Think Smart',
      'description': 'Learn how to control panic, make better decisions, and react effectively during emergencies.',
      'icon': '🧠',
    },
  ];

  // State
  List<String> _bookmarkedIds = [];
  List<String> _recentlyWatchedIds = [];
  Map<String, double> _completionProgress = {}; // id -> 0.0 to 1.0
  String _searchQuery = '';
  String? _selectedCategory;
  bool _showBookmarksOnly = false;

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bookmarkedIds = prefs.getStringList('learning_hub_bookmarks') ?? [];
      _recentlyWatchedIds = prefs.getStringList('learning_hub_recently_watched') ?? [];
      
      final progressJson = prefs.getString('learning_hub_progress');
      if (progressJson != null) {
        try {
          final Map<String, dynamic> decoded = jsonDecode(progressJson);
          _completionProgress = decoded.map((key, value) => MapEntry(key, (value as num).toDouble()));
        } catch (_) {}
      }
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('learning_hub_bookmarks', _bookmarkedIds);
  }

  Future<void> _saveRecentlyWatched() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('learning_hub_recently_watched', _recentlyWatchedIds);
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('learning_hub_progress', jsonEncode(_completionProgress));
  }

  void _toggleBookmark(String videoId) {
    setState(() {
      if (_bookmarkedIds.contains(videoId)) {
        _bookmarkedIds.remove(videoId);
      } else {
        _bookmarkedIds.add(videoId);
      }
    });
    _saveBookmarks();
  }

  void _playVideo(SafetyVideo video) {
    // 1. Add to recently watched (move to front, cap at 5)
    setState(() {
      _recentlyWatchedIds.remove(video.id);
      _recentlyWatchedIds.insert(0, video.id);
      if (_recentlyWatchedIds.length > 5) {
        _recentlyWatchedIds = _recentlyWatchedIds.sublist(0, 5);
      }

      // 2. Set completion progress to 100% when starting to play (or toggleable)
      _completionProgress[video.id] = 1.0;
    });

    _saveRecentlyWatched();
    _saveProgress();

    // 3. Open Video inside Embedded player
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmbeddedYouTubePlayer(
          videoId: video.id,
          title: video.title,
        ),
      ),
    ).then((_) {
      // Reload state when returning in case progress/recently watched updated
      _loadState();
    });
  }

  void _resetProgress(String videoId) {
    setState(() {
      _completionProgress.remove(videoId);
    });
    _saveProgress();
  }

  List<SafetyVideo> _getFilteredVideos() {
    return _allVideos.where((video) {
      // Search matches title or category
      final matchesSearch = video.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          video.category.toLowerCase().contains(_searchQuery.toLowerCase());
      
      // Category filter matches
      final matchesCategory = _selectedCategory == null || video.category == _selectedCategory;
      
      // Bookmarks filter matches
      final matchesBookmarks = !_showBookmarksOnly || _bookmarkedIds.contains(video.id);

      return matchesSearch && matchesCategory && matchesBookmarks;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filteredVideos = _getFilteredVideos();
    final recentlyWatchedVideos = _allVideos.where((v) => _recentlyWatchedIds.contains(v.id)).toList();
    // Sort recently watched to match original array order of recentlyWatchedIds
    recentlyWatchedVideos.sort((a, b) => _recentlyWatchedIds.indexOf(a.id).compareTo(_recentlyWatchedIds.indexOf(b.id)));

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Padding(
          padding: const EdgeInsets.only(left: 8.0, top: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "PREPARE & PREVENT",
                style: GoogleFonts.poppins(
                  color: AppColors.primaryDark,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Safety Learning Hub",
                style: GoogleFonts.poppins(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          // ── Search & Filter Controls ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20.0, 16.0, 20.0, 8.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: AppColors.glassDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: TextField(
                      style: GoogleFonts.poppins(color: AppColors.textDark),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search self-defense, travel...",
                        hintStyle: GoogleFonts.poppins(color: AppColors.mutedText.withOpacity(0.7)),
                        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primaryPurple),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                InkWell(
                  onTap: () {
                    setState(() {
                      _showBookmarksOnly = !_showBookmarksOnly;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _showBookmarksOnly ? AppColors.primaryPurple : Colors.white.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _showBookmarksOnly ? AppColors.primaryPurple : Colors.white.withOpacity(0.55),
                        width: 1.5,
                      ),
                    ),
                    child: Icon(
                      _showBookmarksOnly ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                      color: _showBookmarksOnly ? Colors.white : AppColors.primaryPurple,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Category Pills ─────────────────────────────────────────
          Container(
            height: 48,
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                _buildCategoryPill(null, "All Videos"),
                ..._categories.map((c) => _buildCategoryPill(c['name']!, c['name']!)),
              ],
            ),
          ),

          // ── Main Content Area ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 100),
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Recently Watched Section ─────────────────────────────
                  if (recentlyWatchedVideos.isNotEmpty && !_showBookmarksOnly && _searchQuery.isEmpty && _selectedCategory == null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                      child: Text(
                        "Recently Watched",
                        style: GoogleFonts.poppins(
                          color: AppColors.textDark,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      height: 140,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: recentlyWatchedVideos.length,
                        separatorBuilder: (context, index) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final video = recentlyWatchedVideos[index];
                          return _buildRecentlyWatchedCard(video);
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // ── Educational Description for Categories ───────────────
                  if (_selectedCategory != null) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: AppColors.glassDecoration(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  _categories.firstWhere((c) => c['name'] == _selectedCategory)['icon'] ?? '🛡️',
                                  style: const TextStyle(fontSize: 22),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _selectedCategory!,
                                    style: GoogleFonts.poppins(
                                      color: AppColors.textDark,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _categories.firstWhere((c) => c['name'] == _selectedCategory)['description'] ?? '',
                              style: GoogleFonts.poppins(
                                color: AppColors.mutedText,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // ── Video List ───────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                    child: Text(
                      _showBookmarksOnly ? "Bookmarked Videos" : "Safety Guides & Lessons",
                      style: GoogleFonts.poppins(
                        color: AppColors.textDark,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  if (filteredVideos.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
                        child: Column(
                          children: [
                            Icon(Icons.video_library_rounded, color: AppColors.primaryPurple.withOpacity(0.3), size: 64),
                            const SizedBox(height: 16),
                            Text(
                              "No Videos Found",
                              style: GoogleFonts.poppins(color: AppColors.textDark, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "Try adjusting your filters or search query.",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(color: AppColors.mutedText, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: filteredVideos.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 16),
                      itemBuilder: (context, index) {
                        return _buildVideoCard(filteredVideos[index]);
                      },
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPill(String? categoryVal, String label) {
    final isSelected = _selectedCategory == categoryVal;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedCategory = categoryVal;
          });
        },
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryDark : Colors.white.withOpacity(0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryDark : Colors.white.withOpacity(0.55),
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : AppColors.textDark,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoCard(SafetyVideo video) {
    final isBookmarked = _bookmarkedIds.contains(video.id);
    final progress = _completionProgress[video.id] ?? 0.0;
    final isCompleted = progress >= 0.95;

    return Container(
      decoration: AppColors.glassDecoration(
        borderRadius: BorderRadius.circular(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail Stack
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                InkWell(
                  onTap: () => _playVideo(video),
                  child: Image.network(
                    video.thumbnailUrl,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: double.infinity,
                        height: 180,
                        color: AppColors.primaryDark.withOpacity(0.8),
                        child: const Icon(Icons.video_library_rounded, color: Colors.white24, size: 48),
                      );
                    },
                  ),
                ),
                // Play Button overlay
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
                      ),
                    ),
                  ),
                ),
                // Duration chip
                Container(
                  margin: const EdgeInsets.all(12),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    video.duration,
                    style: GoogleFonts.shareTechMono(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            
            // Text and Info
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Category Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.softLavender.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.softLavender.withOpacity(0.3)),
                        ),
                        child: Text(
                          video.category,
                          style: GoogleFonts.poppins(
                            color: AppColors.softLavender,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      
                      // Action Buttons
                      Row(
                        children: [
                          if (isCompleted)
                            IconButton(
                              icon: const Icon(Icons.replay_rounded, color: AppColors.successGreen, size: 20),
                              tooltip: 'Reset Watch Progress',
                              onPressed: () => _resetProgress(video.id),
                            ),
                          IconButton(
                            icon: Icon(
                              isBookmarked ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                              color: isBookmarked ? AppColors.primaryPurple : AppColors.mutedText,
                              size: 24,
                            ),
                            onPressed: () => _toggleBookmark(video.id),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  
                  // Progress indicator
                  if (progress > 0.0) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.white.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation(
                                isCompleted ? AppColors.successGreen : AppColors.primaryPurple,
                              ),
                              minHeight: 5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCompleted ? "COMPLETED" : "${(progress * 100).toInt()}%",
                          style: GoogleFonts.shareTechMono(
                            color: isCompleted ? AppColors.successGreen : AppColors.mutedText,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentlyWatchedCard(SafetyVideo video) {
    return InkWell(
      onTap: () => _playVideo(video),
      child: Container(
        width: 140,
        decoration: AppColors.glassDecoration(
          borderRadius: BorderRadius.circular(16),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  Image.network(
                    video.thumbnailUrl,
                    width: 140,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 140,
                        height: 80,
                        color: AppColors.primaryDark.withOpacity(0.8),
                        child: const Icon(Icons.video_library_rounded, color: Colors.white24, size: 24),
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: AppColors.textDark,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
