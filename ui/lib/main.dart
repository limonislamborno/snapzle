import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'theme/app_theme.dart';
import 'widgets/glass_card.dart';
import 'widgets/gaming_button.dart';
import 'widgets/avatar_view.dart';
import 'widgets/cartoon_game_icons.dart';
import 'screens/auth_screen.dart';
import 'services/supabase_service.dart';
import 'services/game_progress_service.dart';
import 'games/photo_puzzle_screen.dart';
import 'games/memory_match_screen.dart';
// import 'games/find_difference_screen.dart';
import 'games/sliding_puzzle_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase init
  await Supabase.initialize(
    url: 'https://bjwttdvyajsbfnbcspkc.supabase.co',
    anonKey: 'sb_publishable_K3euv4gSPoCOj6-FYqnJug_8-_B_jC3',
  );

  await GameProgressService.loadForCurrentUser();

  runApp(const ProviderScope(child: SnapzleApp()));
}

class SnapzleApp extends StatelessWidget {
  const SnapzleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Snapzle',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.appTheme,
      home: const AuthGate(),
    );
  }
}

/// Listens to Supabase Auth State:
/// - If not logged in -> Shows AuthScreen (Welcome / Sign In / Create Account / OTP)
/// - If logged in -> Shows MainShellScreen (Game Hub)
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          GameProgressService.resetInMemory();
          SupabaseService.cachedPhotos.clear();
          return const AuthScreen();
        }
        GameProgressService.loadForCurrentUser();
        return const MainShellScreen();
      },
    );
  }
}

class MainShellScreen extends StatefulWidget {
  const MainShellScreen({super.key});

  @override
  State<MainShellScreen> createState() => _MainShellScreenState();
}

class _MainShellScreenState extends State<MainShellScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Ambient Warm Orange Bubbles Background
          Positioned(
            top: -50,
            right: -30,
            child: IgnorePointer(
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryOrange.withValues(alpha: 0.10),
                ),
              ),
            ),
          ),
          Positioned(
            top: 250,
            left: -40,
            child: IgnorePointer(
              child: Container(
                width: 170,
                height: 170,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFB923C).withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -25,
            child: IgnorePointer(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryOrange.withValues(alpha: 0.09),
                ),
              ),
            ),
          ),
          Positioned(
            top: 130,
            left: 20,
            child: IgnorePointer(
              child: Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primaryOrange.withValues(alpha: 0.13),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 180,
            left: 25,
            child: IgnorePointer(
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFB923C).withValues(alpha: 0.14),
                ),
              ),
            ),
          ),

          // Main Screen Switcher
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: const [
                HomeScreen(),
                GamesHubScreen(),
                LeaderboardScreen(),
                PhotoLibraryScreen(),
                ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (idx) {
            if (idx == 0 || idx == 2) {
              SupabaseService.notifyProfileChanged();
            } else if (idx == 1 || idx == 3) {
              SupabaseService.loadUserPhotos().then((_) {
                if (mounted) setState(() {});
              });
            }
            setState(() => _currentIndex = idx);
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.transparent,
          selectedItemColor: AppColors.primaryOrange,
          unselectedItemColor: AppColors.textMuted,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(icon: Icon(LucideIcons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.gamepad2), label: 'Games'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.trophy), label: 'Ranks'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.images), label: 'Photos'),
            BottomNavigationBarItem(icon: Icon(LucideIcons.user), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 1. HOME SCREEN
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _points = 0;
  int _gamesPlayed = 0;
  String _rank = '#--';
  String? _avatarUrl;
  String? _avatarCartoonUrl;
  String _avatarStyle = 'original';

  @override
  void initState() {
    super.initState();
    _loadStats();
    SupabaseService.profileUpdateNotifier.addListener(_loadStats);
  }

  @override
  void dispose() {
    SupabaseService.profileUpdateNotifier.removeListener(_loadStats);
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stats = await SupabaseService.getUserProfileStats();
      if (mounted) {
        setState(() {
          _points = stats['points'] as int? ?? 0;
          _gamesPlayed = stats['games_played'] as int? ?? 0;
          _rank = stats['rank'] as String? ?? '#--';
          _avatarUrl = stats['avatar_url'] as String?;
          _avatarCartoonUrl = stats['avatar_cartoon_url'] as String?;
          _avatarStyle = stats['avatar_style'] as String? ?? 'original';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final username = user?.userMetadata?['username'] ?? 'Player';
    final level = (_points ~/ 500) + 1;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppColors.primary,
      backgroundColor: AppColors.backgroundSecondary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Prominent Hero Player Card (Large Avatar, Points & Rank)
            GlassCard(
              isStrong: true,
              glowColor: AppColors.primary,
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      // Large Prominent Avatar (Original or Cartoon)
                      AvatarView(
                        photoUrl: _avatarUrl,
                        cartoonPhotoUrl: _avatarCartoonUrl,
                        avatarStyle: _avatarStyle,
                        emoji: '🦊',
                        gradientIndex: 0,
                        size: 72,
                        hasRing: true,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    username,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [AppColors.primary, AppColors.accentPink],
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    'LVL $level',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _avatarStyle == 'cartoon' ? '⚡ Cartoon Avatar Active' : '📷 Original Photo Active',
                              style: TextStyle(
                                color: _avatarStyle == 'cartoon' ? AppColors.primaryOrange : AppColors.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _heroMetric('GLOBAL RANK', _rank, AppColors.primaryOrange, LucideIcons.trophy),
                        Container(width: 1, height: 32, color: AppColors.glassBorder),
                        _heroMetric('TOTAL POINTS', '$_points pts', AppColors.primary, LucideIcons.sparkles),
                        Container(width: 1, height: 32, color: AppColors.glassBorder),
                        _heroMetric('GAMES WON', '$_gamesPlayed', AppColors.accentEmerald, LucideIcons.gamepad2),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 2. Game Points & Scoring Breakdown
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'How Points Are Scored',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.glassFill,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(LucideIcons.zap, size: 12, color: AppColors.accentAmber),
                      SizedBox(width: 4),
                      Text('Max Speed Bonus', style: TextStyle(fontSize: 10, color: AppColors.accentAmber, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _scoringGuideCard(
              title: 'Photo Puzzle',
              icon: LucideIcons.puzzle,
              color: AppColors.primary,
              maxPts: 'Up to 1,000 pts',
              rule: 'Base 1000 - (5 × Seconds) - (10 × Moves)',
              tip: 'Solve quickly with fewer tile swaps for max score.',
            ),
            _scoringGuideCard(
              title: 'Sliding Puzzle',
              icon: LucideIcons.layoutGrid,
              color: AppColors.accentEmerald,
              maxPts: 'Up to 1,200 pts',
              rule: 'Base 1200 - (4 × Seconds) - (8 × Moves)',
              tip: 'Fast sliding and optimal pathing yields highest points.',
            ),
            _scoringGuideCard(
              title: 'Memory Match',
              icon: LucideIcons.brain,
              color: AppColors.primaryBlue,
              maxPts: 'Up to 2,500 pts',
              rule: '200 pts/pair + Speed Bonus (up to 500)',
              tip: 'Tier scoring: 6 pairs (~1.7K), 8 pairs (~2.1K), 10 pairs (~2.5K).',
            ),
            /*
            _scoringGuideCard(
              title: 'Find the Difference',
              icon: LucideIcons.scanSearch,
              color: AppColors.accentPink,
              maxPts: 'Up to 1,000 pts',
              rule: 'Base 1000 - (5 × Seconds)',
              tip: 'Spot all 5 differences quickly with zero wrong taps.',
            ),
            */
          ],
        ),
      ),
    );
  }

  Widget _heroMetric(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
      ],
    );
  }

  Widget _scoringGuideCard({
    required String title,
    required IconData icon,
    required Color color,
    required String maxPts,
    required String rule,
    required String tip,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: GlassCard(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text(maxPts, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(rule, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontFamily: 'monospace')),
                  const SizedBox(height: 2),
                  Text(tip, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 2. GAMES HUB SCREEN (Plays with User Photos)
// ==========================================
class GamesHubScreen extends StatefulWidget {
  const GamesHubScreen({super.key});

  @override
  State<GamesHubScreen> createState() => _GamesHubScreenState();
}

class _GamesHubScreenState extends State<GamesHubScreen> {
  List<PhotoItem> get _photos => SupabaseService.cachedPhotos;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    try {
      await SupabaseService.loadUserPhotos();
      if (mounted) setState(() {});
    } catch (_) {}
  }

  Future<void> _openPuzzleSetup(BuildContext context) async {
    if (_photos.isEmpty) {
      await _loadPhotos();
    }
    if (!context.mounted) return;
    if (_photos.isEmpty) {
      _showUploadRequiredDialog('Photo Puzzle');
      return;
    }

    int selectedPhotoIdx = 0;
    int selectedDim = 3;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Photo Puzzle',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a photo from your vault & difficulty:',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  // Photo selector carousel
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      itemBuilder: (ctx, idx) {
                        bool isSel = selectedPhotoIdx == idx;
                        bool isCleared = GameProgressService.isPhotoClearedInPhotoPuzzle(
                          selectedDim,
                          _photos[idx].id,
                        );

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedPhotoIdx = idx),
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel ? AppColors.primary : AppColors.glassBorder,
                                    width: isSel ? 3 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(_photos[idx].signedUrl, fit: BoxFit.cover),
                                ),
                              ),
                              if (isCleared)
                                Positioned(
                                  top: 6,
                                  right: 18,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentEmerald,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Grid Difficulty', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [3, 4, 5].map((dim) {
                      bool isUnlocked = GameProgressService.isPhotoPuzzleUnlocked(dim);
                      bool isSel = selectedDim == dim;
                      int clearedCount = dim == 3
                          ? GameProgressService.clearedPhotoPuzzle3.length
                          : (dim == 4
                              ? GameProgressService.clearedPhotoPuzzle4.length
                              : 0);
                      int prereqCount = dim == 4
                          ? GameProgressService.clearedPhotoPuzzle3.length
                          : GameProgressService.clearedPhotoPuzzle4.length;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap: () {
                              if (!isUnlocked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      dim == 4
                                          ? '🔒 Need 5 different photos completed on 3×3 to unlock 4×4! ($prereqCount/5 done)'
                                          : '🔒 Need 5 different photos completed on 4×4 to unlock 5×5! ($prereqCount/5 done)',
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: AppColors.backgroundSecondary,
                                  ),
                                );
                                return;
                              }
                              setModalState(() => selectedDim = dim);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.primary
                                    : (isUnlocked
                                        ? AppColors.glassFill
                                        : Colors.black.withValues(alpha: 0.35)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.primary
                                      : (isUnlocked ? AppColors.glassBorder : Colors.white12),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (!isUnlocked) ...[
                                        const Icon(LucideIcons.lock, size: 12, color: Colors.white38),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        '$dim×$dim',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSel
                                              ? Colors.white
                                              : (isUnlocked ? Colors.white70 : Colors.white30),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    isUnlocked
                                        ? (dim == 5 ? 'Master' : '$clearedCount/5')
                                        : '$prereqCount/5',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSel
                                          ? Colors.white70
                                          : (isUnlocked ? AppColors.accentEmerald : Colors.white30),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  GamingButton(
                    label: 'Start Puzzle',
                    icon: LucideIcons.play,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PhotoPuzzleScreen(
                            imageUrl: _photos[selectedPhotoIdx].signedUrl,
                            photoId: _photos[selectedPhotoIdx].id,
                            gridDim: selectedDim,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSlidingPuzzleSetup(BuildContext context) async {
    if (_photos.isEmpty) {
      await _loadPhotos();
    }
    if (!context.mounted) return;
    if (_photos.isEmpty) {
      _showUploadRequiredDialog('Sliding Puzzle');
      return;
    }

    int selectedPhotoIdx = 0;
    int selectedDim = 3;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Sliding Puzzle',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Select a photo from your vault & grid size:',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _photos.length,
                      itemBuilder: (ctx, idx) {
                        bool isSel = selectedPhotoIdx == idx;
                        bool isCleared = GameProgressService.isPhotoClearedInSlidingPuzzle(
                          selectedDim,
                          _photos[idx].id,
                        );

                        return GestureDetector(
                          onTap: () => setModalState(() => selectedPhotoIdx = idx),
                          child: Stack(
                            children: [
                              Container(
                                width: 100,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSel ? AppColors.accentEmerald : AppColors.glassBorder,
                                    width: isSel ? 3 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(11),
                                  child: Image.network(_photos[idx].signedUrl, fit: BoxFit.cover),
                                ),
                              ),
                              if (isCleared)
                                Positioned(
                                  top: 6,
                                  right: 18,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppColors.accentEmerald,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.check, size: 12, color: Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('Grid Size', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Row(
                    children: [3, 4].map((dim) {
                      bool isUnlocked = GameProgressService.isSlidingPuzzleUnlocked(dim);
                      bool isSel = selectedDim == dim;
                      int cleared3 = GameProgressService.clearedSlidingPuzzle3.length;

                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4.0),
                          child: InkWell(
                            onTap: () {
                              if (!isUnlocked) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '🔒 Need 5 different photos completed on 3×3 to unlock 4×4! ($cleared3/5 done)',
                                    ),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: AppColors.backgroundSecondary,
                                  ),
                                );
                                return;
                              }
                              setModalState(() => selectedDim = dim);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppColors.accentEmerald
                                    : (isUnlocked
                                        ? AppColors.glassFill
                                        : Colors.black.withValues(alpha: 0.35)),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSel
                                      ? AppColors.accentEmerald
                                      : (isUnlocked ? AppColors.glassBorder : Colors.white12),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (!isUnlocked) ...[
                                        const Icon(LucideIcons.lock, size: 12, color: Colors.white38),
                                        const SizedBox(width: 4),
                                      ],
                                      Text(
                                        '$dim×$dim',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: isSel
                                              ? Colors.white
                                              : (isUnlocked ? Colors.white70 : Colors.white30),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dim == 3
                                        ? '$cleared3/5'
                                        : (isUnlocked ? '15 tiles' : '$cleared3/5'),
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSel
                                          ? Colors.white70
                                          : (isUnlocked ? AppColors.accentEmerald : Colors.white30),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 24),
                  GamingButton(
                    label: 'Start Sliding Puzzle',
                    icon: LucideIcons.play,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SlidingPuzzleScreen(
                            imageUrl: _photos[selectedPhotoIdx].signedUrl,
                            photoId: _photos[selectedPhotoIdx].id,
                            gridDim: selectedDim,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openMemoryMatchSetup(BuildContext context) async {
    if (_photos.isEmpty) {
      await _loadPhotos();
    }
    if (!context.mounted) return;
    if (_photos.isEmpty) {
      _showUploadRequiredDialog('Memory Match');
      return;
    }

    int selectedPairs = 6;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundSecondary,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final tiers = [
              {
                'pairs': 6,
                'label': '6 Pairs (Easy)',
                'progress': '${GameProgressService.memoryMatchWins6}/5 wins',
                'prereq': 0,
              },
              {
                'pairs': 8,
                'label': '8 Pairs (Medium)',
                'progress': GameProgressService.memoryMatchWins6 >= 5
                    ? '${GameProgressService.memoryMatchWins8}/5 wins'
                    : '${GameProgressService.memoryMatchWins6}/5 to unlock',
                'prereq': GameProgressService.memoryMatchWins6,
              },
              {
                'pairs': 10,
                'label': '10 Pairs (Hard)',
                'progress': GameProgressService.memoryMatchWins8 >= 5
                    ? 'Master'
                    : '${GameProgressService.memoryMatchWins8}/5 to unlock',
                'prereq': GameProgressService.memoryMatchWins8,
              },
            ];

            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Setup Memory Match',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Flip and match photo pairs from your vault:',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                  ),
                  const SizedBox(height: 20),
                  const Text('Difficulty Tier', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  Column(
                    children: tiers.map((tier) {
                      int pairs = tier['pairs'] as int;
                      String label = tier['label'] as String;
                      String progress = tier['progress'] as String;
                      int prereq = tier['prereq'] as int;
                      bool isUnlocked = GameProgressService.isMemoryMatchUnlocked(pairs);
                      bool isSel = selectedPairs == pairs;

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: InkWell(
                          onTap: () {
                            if (!isUnlocked) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    pairs == 8
                                        ? '🔒 Need 5 wins on 6-Pairs to unlock 8-Pairs! ($prereq/5 done)'
                                        : '🔒 Need 5 wins on 8-Pairs to unlock 10-Pairs! ($prereq/5 done)',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  backgroundColor: AppColors.backgroundSecondary,
                                ),
                              );
                              return;
                            }
                            setModalState(() => selectedPairs = pairs);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? AppColors.primaryBlue
                                  : (isUnlocked
                                      ? AppColors.glassFill
                                      : Colors.black.withValues(alpha: 0.35)),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSel
                                    ? AppColors.primaryBlue
                                    : (isUnlocked ? AppColors.glassBorder : Colors.white12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        if (!isUnlocked) ...[
                                          const Icon(LucideIcons.lock, size: 14, color: Colors.white38),
                                          const SizedBox(width: 6),
                                        ],
                                        Text(
                                          label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isSel
                                                ? Colors.white
                                                : (isUnlocked ? Colors.white : Colors.white38),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      progress,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isSel
                                            ? Colors.white70
                                            : (isUnlocked ? AppColors.accentEmerald : Colors.white30),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (isSel)
                                  const Icon(LucideIcons.circleCheck, size: 18, color: Colors.white),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  GamingButton(
                    label: 'Start Match',
                    icon: LucideIcons.play,
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MemoryMatchScreen(
                            photoUrls: _photos.map((p) => p.signedUrl).toList(),
                            pairsCount: selectedPairs,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showUploadRequiredDialog(String gameName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: Text('$gameName needs Photos'),
        content: const Text(
          'Please upload at least 1 photo in your Photo Vault to play with your own memories!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadPhotos,
      color: AppColors.primary,
      backgroundColor: AppColors.backgroundSecondary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select a Challenge',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Play puzzles exclusively using your private photos.',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
          const SizedBox(height: 20),
          _gameLaunchCard(
            context: context,
            title: 'Photo Puzzle',
            subtitle: 'Drag & drop pieces to rebuild your photo',
            tag: 'POPULAR',
            cartoonIcon: const CartoonGameBadge(
              iconWidget: CartoonPuzzleIllustration(size: 46),
              bgGradient: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
              glowColor: Color(0xFF8B5CF6),
              tagEmoji: '🧩',
            ),
            glowColor: const Color(0xFF8B5CF6),
            actionGradient: const [Color(0xFF8B5CF6), Color(0xFFD946EF)],
            difficultyMeta: '3×3 • 4×4 • 5×5',
            onTap: () => _openPuzzleSetup(context),
          ),
          _gameLaunchCard(
            context: context,
            title: 'Memory Match',
            subtitle: 'Flip and find matching photo pairs',
            tag: 'BRAIN TRAIN',
            cartoonIcon: const CartoonGameBadge(
              iconWidget: CartoonMemoryIllustration(size: 46),
              bgGradient: [Color(0xFF06B6D4), Color(0xFF3B82F6)],
              glowColor: Color(0xFF06B6D4),
              tagEmoji: '⚡',
            ),
            glowColor: const Color(0xFF06B6D4),
            actionGradient: const [Color(0xFF06B6D4), Color(0xFF3B82F6)],
            difficultyMeta: '6 to 10 Pairs',
            onTap: () => _openMemoryMatchSetup(context),
          ),
          /*
          _gameLaunchCard(
            context: context,
            title: 'Find the Difference',
            subtitle: 'Spot the 5 procedural hidden changes',
            tag: 'OBSERVE',
            cartoonIcon: const CartoonGameBadge(
              iconWidget: Icon(LucideIcons.scanSearch, color: Colors.white, size: 28),
              bgGradient: [Color(0xFFF43F5E), Color(0xFFFB923C)],
              glowColor: Color(0xFFF43F5E),
              tagEmoji: '🔍',
            ),
            glowColor: const Color(0xFFF43F5E),
            actionGradient: const [Color(0xFFF43F5E), Color(0xFFFB923C)],
            difficultyMeta: '5 Hidden Spots',
            onTap: () async {
              if (_photos.isEmpty) {
                await _loadPhotos();
              }
              if (_photos.isEmpty) {
                if (mounted) _showUploadRequiredDialog('Find the Difference');
                return;
              }
              if (!context.mounted) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FindDifferenceScreen(
                    spots: [
                      SpotDifference(id: 1, xPct: 28, yPct: 22),
                      SpotDifference(id: 2, xPct: 74, yPct: 35),
                      SpotDifference(id: 3, xPct: 38, yPct: 70),
                      SpotDifference(id: 4, xPct: 82, yPct: 60),
                      SpotDifference(id: 5, xPct: 15, yPct: 50),
                    ],
                    originalImage: Image.network(_photos.first.signedUrl, fit: BoxFit.contain),
                    modifiedImage: Image.network(_photos.first.signedUrl, fit: BoxFit.contain),
                  ),
                ),
              );
            },
          ),
          */
          _gameLaunchCard(
            context: context,
            title: 'Sliding Puzzle',
            subtitle: 'Slide tiles into empty slots to solve',
            tag: 'CLASSIC',
            cartoonIcon: const CartoonGameBadge(
              iconWidget: CartoonSlidingIllustration(size: 46),
              bgGradient: [Color(0xFF10B981), Color(0xFF0D9488)],
              glowColor: Color(0xFF10B981),
              tagEmoji: '🎮',
            ),
            glowColor: const Color(0xFF10B981),
            actionGradient: const [Color(0xFF10B981), Color(0xFF0D9488)],
            difficultyMeta: 'Classic 15 Grid',
            onTap: () => _openSlidingPuzzleSetup(context),
          ),
        ],
      ),
    ),
    );
  }

  Widget _gameLaunchCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String tag,
    required Widget cartoonIcon,
    required Color glowColor,
    required List<Color> actionGradient,
    required String difficultyMeta,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14.0),
      child: GlassCard(
        onTap: onTap,
        glowColor: glowColor,
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        child: Row(
          children: [
            cartoonIcon,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: glowColor.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: glowColor.withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          tag,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                            color: glowColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          difficultyMeta,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.25,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: actionGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withValues(alpha: 0.45),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Icon(
                LucideIcons.play,
                color: Colors.white,
                size: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. LEADERBOARD SCREEN (Accurate Live Rankings)
// ==========================================
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  List<Map<String, dynamic>> _leaderboard = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLeaderboard();
    SupabaseService.profileUpdateNotifier.addListener(_loadLeaderboard);
  }

  @override
  void dispose() {
    SupabaseService.profileUpdateNotifier.removeListener(_loadLeaderboard);
    super.dispose();
  }

  Future<void> _loadLeaderboard() async {
    setState(() => _isLoading = true);
    try {
      final list = await SupabaseService.fetchLeaderboard(limit: 50);
      if (mounted) {
        setState(() {
          _leaderboard = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;

    return RefreshIndicator(
      onRefresh: _loadLeaderboard,
      color: AppColors.primary,
      backgroundColor: AppColors.backgroundSecondary,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _leaderboard.isEmpty
              ? ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(24.0),
                  children: [
                    const SizedBox(height: 60),
                    Center(
                      child: Column(
                        children: [
                          Icon(LucideIcons.trophy, size: 60, color: Colors.white.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          const Text(
                            'No ranked players yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Play and win games to be the first on the podium!',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ],
                )
              : ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    const Text(
                      'Rankings',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    // Dynamic Podium for Top 3
                    _buildPodium(),
                    const SizedBox(height: 24),
                    // List from #4 onwards (or remaining)
                    ...List.generate(
                      _leaderboard.length > 3 ? _leaderboard.length - 3 : 0,
                      (i) {
                        final player = _leaderboard[i + 3];
                        final rank = i + 4;
                        final isMe = player['id'] == currentUserId;
                        final points = player['points'] ?? 0;
                        final name = player['username'] ?? 'Player_$rank';

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: GlassCard(
                            isStrong: isMe,
                            glowColor: isMe ? AppColors.primary : null,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Text(
                                  '#$rank',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? AppColors.primaryOrange : AppColors.textSecondary,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AvatarView(
                                  emoji: player['avatar_emoji'] ?? '🦊',
                                  gradientIndex: player['avatar_gradient'] ?? (i % 8),
                                  size: 36,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          name,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                                            fontSize: 14,
                                            color: isMe ? AppColors.primaryOrange : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      if (isMe) ...[
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppColors.primary.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
                                          ),
                                          child: const Text(
                                            'YOU',
                                            style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Text(
                                  '$points pts',
                                  style: const TextStyle(
                                    color: AppColors.accentCyan,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
    );
  }

  Widget _buildPodium() {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final top1 = _leaderboard.isNotEmpty ? _leaderboard[0] : null;
    final top2 = _leaderboard.length > 1 ? _leaderboard[1] : null;
    final top3 = _leaderboard.length > 2 ? _leaderboard[2] : null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Rank 2 (Left)
        if (top2 != null)
          _podiumPillar(
            rank: '#2',
            player: top2,
            height: 90,
            color: AppColors.primaryBlue,
            currentUserId: currentUserId,
            badgeIcon: LucideIcons.medal,
            avatarSize: 50,
          )
        else
          const SizedBox(width: 82),

        // Rank 1 (Center)
        if (top1 != null)
          _podiumPillar(
            rank: '#1',
            player: top1,
            height: 120,
            color: AppColors.accentAmber,
            currentUserId: currentUserId,
            badgeIcon: LucideIcons.crown,
            avatarSize: 62,
          )
        else
          const SizedBox(width: 82),

        // Rank 3 (Right)
        if (top3 != null)
          _podiumPillar(
            rank: '#3',
            player: top3,
            height: 72,
            color: AppColors.accentEmerald,
            currentUserId: currentUserId,
            badgeIcon: LucideIcons.award,
            avatarSize: 46,
          )
        else
          const SizedBox(width: 82),
      ],
    );
  }

  Map<String, dynamic> _resolvePlayerAvatar(Map<String, dynamic> player, String? currentUserId) {
    final isMe = player['id'] == currentUserId;
    final user = Supabase.instance.client.auth.currentUser;
    final meta = isMe ? (user?.userMetadata ?? {}) : {};

    final avatarUrl = meta['avatar_url'] as String? ?? player['avatar_url'] as String?;
    final cartoonUrl = meta['avatar_cartoon_url'] as String? ?? player['avatar_cartoon_url'] as String?;
    final avatarStyle = meta['avatar_style'] as String? ?? player['avatar_style'] as String? ?? 'original';
    final emoji = player['avatar_emoji'] as String? ?? '🦊';
    final gradientIndex = (player['avatar_gradient'] as num?)?.toInt() ?? 0;

    return {
      'avatarUrl': avatarUrl,
      'cartoonUrl': cartoonUrl,
      'avatarStyle': avatarStyle,
      'emoji': emoji,
      'gradientIndex': gradientIndex,
    };
  }

  Widget _podiumPillar({
    required String rank,
    required Map<String, dynamic> player,
    required double height,
    required Color color,
    required String? currentUserId,
    required IconData badgeIcon,
    required double avatarSize,
  }) {
    final avatarData = _resolvePlayerAvatar(player, currentUserId);
    final name = player['username'] ?? 'Player';
    final pts = '${player['points'] ?? 0} pts';
    final isMe = player['id'] == currentUserId;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Column(
        children: [
          Icon(badgeIcon, color: color, size: rank == '#1' ? 22 : 18),
          const SizedBox(height: 4),
          AvatarView(
            photoUrl: avatarData['avatarUrl'],
            cartoonPhotoUrl: avatarData['cartoonUrl'],
            avatarStyle: avatarData['avatarStyle'],
            emoji: avatarData['emoji'],
            gradientIndex: avatarData['gradientIndex'],
            size: avatarSize,
            hasRing: true,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: 82,
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isMe ? FontWeight.w900 : FontWeight.bold,
                fontSize: 12,
                color: isMe ? AppColors.primaryOrange : AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(pts, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            width: 82,
            height: height,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0.1)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              border: Border.all(color: color.withValues(alpha: 0.5)),
            ),
            child: Center(
              child: Text(
                rank,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 4. PHOTO LIBRARY SCREEN (Universal Web & Mobile)
// ==========================================
class PhotoLibraryScreen extends StatefulWidget {
  const PhotoLibraryScreen({super.key});

  @override
  State<PhotoLibraryScreen> createState() => _PhotoLibraryScreenState();
}

class _PhotoLibraryScreenState extends State<PhotoLibraryScreen> {
  final ImagePicker _picker = ImagePicker();
  List<PhotoItem> _photos = [];
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadPhotos();
  }

  Future<void> _loadPhotos() async {
    setState(() => _isLoading = true);
    try {
      final list = await SupabaseService.loadUserPhotos();
      if (mounted) {
        setState(() {
          _photos = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_photos.length >= 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Free vault limit reached (10 photos max).')),
      );
      return;
    }

    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (file == null) return;

    setState(() => _isUploading = true);

    try {
      await SupabaseService.uploadPhoto(file);
      await _loadPhotos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.accentEmerald,
            content: Text('Photo securely uploaded to your private vault!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Upload failed: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deletePhoto(PhotoItem photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        title: const Text('Delete Photo?'),
        content: const Text('This will permanently delete this photo from your private vault.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.deletePhoto(photo);
      _loadPhotos();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Photo Vault',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_photos.length} of 10 slots used (Private & Encrypted)',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(LucideIcons.plus, color: AppColors.accentCyan),
                onPressed: _isUploading ? null : _pickAndUploadPhoto,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _photos.isEmpty
                    ? GlassCard(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(LucideIcons.images, size: 54, color: AppColors.primaryOrange.withValues(alpha: 0.35)),
                              const SizedBox(height: 12),
                              const Text(
                                'No photos uploaded yet',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Upload at least 5 photos to unlock all puzzle games.',
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _photos.length,
                        itemBuilder: (context, idx) {
                          final photo = _photos[idx];
                          return GlassCard(
                            padding: EdgeInsets.zero,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Image.network(
                                  photo.signedUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (_, child, progress) {
                                    if (progress == null) return child;
                                    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
                                  },
                                  errorBuilder: (_, __, ___) => const Center(
                                    child: Icon(LucideIcons.imageOff, color: Colors.white38),
                                  ),
                                ),
                                Positioned(
                                  top: 6,
                                  right: 6,
                                  child: GestureDetector(
                                    onTap: () => _deletePhoto(photo),
                                    child: Container(
                                      padding: const EdgeInsets.all(5),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.65),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(LucideIcons.trash2, size: 14, color: Colors.redAccent),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 6,
                                  left: 8,
                                  right: 8,
                                  child: Text(
                                    photo.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 12),
          GamingButton(
            label: _isUploading ? 'Compressing & Uploading...' : 'Upload New Photo',
            icon: LucideIcons.upload,
            isLoading: _isUploading,
            onPressed: _isUploading ? null : _pickAndUploadPhoto,
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 5. PROFILE SCREEN
// ==========================================
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();
  int _points = 0;
  int _gamesPlayed = 0;
  String _rank = '#--';
  String? _avatarUrl;
  String? _avatarCartoonUrl;
  String _avatarStyle = 'original';
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isGeneratingCartoon = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final stats = await SupabaseService.getUserProfileStats();
      if (mounted) {
        setState(() {
          _points = stats['points'] as int? ?? 0;
          _gamesPlayed = stats['games_played'] as int? ?? 0;
          _rank = stats['rank'] as String? ?? '#--';
          _avatarUrl = stats['avatar_url'] as String?;
          _avatarCartoonUrl = stats['avatar_cartoon_url'] as String?;
          _avatarStyle = stats['avatar_style'] as String? ?? 'original';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickAndUploadAvatar() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final result = await SupabaseService.uploadAvatar(file);
      if (mounted) {
        setState(() {
          _avatarUrl = result['original'];
          _avatarCartoonUrl = result['cartoon'];
          _avatarStyle = 'original';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.accentEmerald,
            content: Text('Profile photo and cartoon avatar ready!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.redAccent,
            content: Text('Failed to update avatar: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _selectAvatarStyle(String newStyle) async {
    if (_avatarStyle == newStyle) return;

    // If switching to cartoon and cartoon is not generated yet, generate now
    if (newStyle == 'cartoon' && (_avatarCartoonUrl == null || _avatarCartoonUrl!.isEmpty)) {
      setState(() => _isGeneratingCartoon = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          backgroundColor: AppColors.backgroundSecondary,
          content: Text('🎨 Generating accurate cartoon portrait...'),
        ),
      );
      final generatedUrl = await SupabaseService.generateCartoonForCurrentAvatar();
      if (mounted) {
        setState(() {
          _avatarCartoonUrl = generatedUrl;
          _isGeneratingCartoon = false;
        });
      }
    }

    setState(() => _avatarStyle = newStyle);
    try {
      await SupabaseService.updateAvatarStyle(newStyle);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 1),
            backgroundColor: AppColors.backgroundSecondary,
            content: Text(
              newStyle == 'cartoon'
                  ? '🎨 Switched to Cartoon Gamer avatar!'
                  : '📷 Switched to Original Photo avatar!',
            ),
          ),
        );
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final username = user?.userMetadata?['username'] ?? 'Player';
    final email = user?.email ?? 'private@user';
    final level = (_points ~/ 500) + 1;

    return RefreshIndicator(
      onRefresh: _loadProfile,
      color: AppColors.primary,
      backgroundColor: AppColors.backgroundSecondary,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              children: [
          Center(
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    AvatarView(
                      photoUrl: _avatarUrl,
                      cartoonPhotoUrl: _avatarCartoonUrl,
                      avatarStyle: _avatarStyle,
                      emoji: '🦊',
                      gradientIndex: 0,
                      size: 88,
                      hasRing: true,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onTap: _isUploading ? null : _pickAndUploadAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.backgroundSecondary, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black54, blurRadius: 6),
                            ],
                          ),
                          child: _isUploading
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(LucideIcons.camera, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  username,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                Text(
                  '$email (Private)',
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 12),
                if (_avatarUrl != null) ...[
                  // Avatar Style Switcher (Original vs Cartoon)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.glassBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _styleToggleChip(
                          label: 'Original',
                          icon: LucideIcons.camera,
                          isSelected: _avatarStyle == 'original',
                          onTap: () => _selectAvatarStyle('original'),
                        ),
                        const SizedBox(width: 4),
                        _styleToggleChip(
                          label: _isGeneratingCartoon ? 'Toonifying...' : 'Cartoon',
                          icon: _isGeneratingCartoon ? LucideIcons.loader : LucideIcons.sparkles,
                          isSelected: _avatarStyle == 'cartoon',
                          onTap: _isGeneratingCartoon ? () {} : () => _selectAvatarStyle('cartoon'),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  TextButton.icon(
                    onPressed: _isUploading ? null : _pickAndUploadAvatar,
                    icon: const Icon(LucideIcons.upload, size: 16, color: AppColors.primaryOrange),
                    label: const Text(
                      'Upload Avatar Photo',
                      style: TextStyle(color: AppColors.primaryOrange, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Live Stats Card
          GlassCard(
            child: Column(
              children: [
                _profileRow(LucideIcons.shieldAlert, 'Global Rank', _rank),
                const Divider(color: AppColors.glassBorder),
                _profileRow(LucideIcons.sparkles, 'Total Points', '$_points pts'),
                const Divider(color: AppColors.glassBorder),
                _profileRow(LucideIcons.gamepad2, 'Games Played', '$_gamesPlayed'),
                const Divider(color: AppColors.glassBorder),
                _profileRow(LucideIcons.medal, 'Player Level', 'Level $level'),
                const Divider(color: AppColors.glassBorder),
                _profileRow(LucideIcons.shieldCheck, 'Privacy & Photos', '100% Private'),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GamingButton(
            label: 'Sign Out',
            color: Colors.redAccent.withValues(alpha: 0.8),
            icon: LucideIcons.logOut,
            onPressed: () async {
              GameProgressService.resetInMemory();
              SupabaseService.cachedPhotos.clear();
              await Supabase.instance.client.auth.signOut();
            },
          ),
        ],
      ),
    );
  }

  Widget _styleToggleChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryOrange : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : AppColors.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _profileRow(IconData icon, String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryOrange, size: 20),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            val,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
