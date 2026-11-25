import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme/app_theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/avatar_view.dart';
import '../widgets/quit_game_dialog.dart';

class AdminConsoleScreen extends StatefulWidget {
  final bool isEmbedded;
  final VoidCallback? onExitToShell;
  const AdminConsoleScreen({super.key, this.isEmbedded = false, this.onExitToShell});

  @override
  State<AdminConsoleScreen> createState() => _AdminConsoleScreenState();
}

class _AdminConsoleScreenState extends State<AdminConsoleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SupabaseClient _supabase = Supabase.instance.client;

  bool _isLoading = true;
  String _searchQuery = '';
  String? _selectedUserFilter;
  int _previousTabIndex = 0;

  List<Map<String, dynamic>> _allPlayers = [];
  List<Map<String, dynamic>> _allPhotos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAdminData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAdminData() async {
    setState(() => _isLoading = true);
    try {

      final profilesRes = await _supabase
          .from('profiles')
          .select()
          .order('points', ascending: false);
      _allPlayers = List<Map<String, dynamic>>.from(profilesRes);

      final photosRes = await _supabase
          .from('photos')
          .select('id, user_id, photo_name, storage_path, file_size_kb, created_at')
          .order('created_at', ascending: false);

      final List<Map<String, dynamic>> loadedPhotos = [];
      for (final row in photosRes) {
        final storagePath = row['storage_path'] as String? ?? '';
        String signedUrl = '';
        if (storagePath.isNotEmpty) {
          try {
            signedUrl = await _supabase.storage.from('user-photos').createSignedUrl(storagePath, 3600);
          } catch (_) {}
        }

        final ownerId = row['user_id'] as String?;
        final owner = _allPlayers.firstWhere(
          (p) => p['id'] == ownerId,
          orElse: () => {'username': 'Unknown Player'},
        );

        loadedPhotos.add({
          ...row,
          'signed_url': signedUrl,
          'owner_name': owner['username'] ?? 'Player',
        });
      }
      _allPhotos = loadedPhotos;
    } catch (e) {
      debugPrint('Admin data loading error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deletePhotoAsAdmin(Map<String, dynamic> photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.trash2, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete User Photo?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this photo uploaded by "${photo['owner_name']}"? It will be removed from their vault.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Photo', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final storagePath = photo['storage_path'] as String?;
        if (storagePath != null && storagePath.isNotEmpty) {
          await _supabase.storage.from('user-photos').remove([storagePath]);
        }
        await _supabase.from('photos').delete().eq('id', photo['id']);
        setState(() {
          _allPhotos.removeWhere((p) => p['id'] == photo['id']);
        });
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Photo Deleted',
            message: 'Photo deleted successfully.',
            icon: LucideIcons.trash2,
          );
        }
      } catch (e) {
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Delete Failed',
            message: 'Failed to delete photo: $e',
            icon: LucideIcons.circleAlert,
          );
        }
      }
    }
  }

  Future<void> _deleteAllPhotosForUser(String userId, String username, List<Map<String, dynamic>> userPhotos) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.trash2, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete All User Photos?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Are you sure you want to permanently delete all ${userPhotos.length} photos uploaded by "@$username"? This cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final List<String> paths = [];
        for (final p in userPhotos) {
          final path = p['storage_path'] as String?;
          if (path != null && path.isNotEmpty) paths.add(path);
        }
        if (paths.isNotEmpty) {
          await _supabase.storage.from('user-photos').remove(paths);
        }
        await _supabase.from('photos').delete().eq('user_id', userId);
        setState(() {
          _allPhotos.removeWhere((p) => p['user_id'] == userId);
        });
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Photos Deleted',
            message: 'All photos of @$username deleted.',
            icon: LucideIcons.trash2,
          );
        }
      } catch (e) {
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Delete Failed',
            message: 'Failed to delete photos: $e',
            icon: LucideIcons.circleAlert,
          );
        }
      }
    }
  }

  Future<void> _resetPlayerPoints(Map<String, dynamic> player) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Player Points?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(
          'Reset all points to 0 for "${player['username']}"?',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryOrange, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset Points'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('profiles').update({'points': 0}).eq('id', player['id']);
        await _loadAdminData();
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Points Reset',
            message: 'Points reset to 0 for ${player['username']}.',
            icon: LucideIcons.rotateCcw,
          );
        }
      } catch (e) {
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Error',
            message: 'Error: $e',
            icon: LucideIcons.circleAlert,
          );
        }
      }
    }
  }

  Future<void> _deletePlayerAccountAsAdmin(Map<String, dynamic> player) async {
    final username = player['username'] ?? 'Player';
    final email = player['email'] ?? '';
    final targetUserId = player['id'] as String;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(LucideIcons.trash2, color: Colors.redAccent, size: 22),
            SizedBox(width: 8),
            Text('Delete Account?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          ],
        ),
        content: Text(
          'Permanently delete player @$username ($email)?\n\nAll their uploaded photos, scores, best records, and profile will be deleted forever. This action cannot be undone.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Account'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final photosData = await _supabase
            .from('photos')
            .select('storage_path, diff_storage_path')
            .eq('user_id', targetUserId);

        final List<String> pathsToDelete = [];
        for (final row in photosData) {
          final sPath = row['storage_path'] as String?;
          if (sPath != null && sPath.isNotEmpty) pathsToDelete.add(sPath);
          final dPath = row['diff_storage_path'] as String?;
          if (dPath != null && dPath.isNotEmpty) pathsToDelete.add(dPath);
        }
        if (pathsToDelete.isNotEmpty) {
          try {
            await _supabase.storage.from('user-photos').remove(pathsToDelete);
          } catch (_) {}
        }

        try {
          await _supabase.rpc('admin_delete_user_account', params: {'target_user_id': targetUserId});
        } catch (_) {
          try {
            await _supabase.from('photos').delete().eq('user_id', targetUserId);
            await _supabase.from('game_sessions').delete().eq('user_id', targetUserId);
            await _supabase.from('user_game_bests').delete().eq('user_id', targetUserId);
            await _supabase.from('user_achievements').delete().eq('user_id', targetUserId);
            await _supabase.from('user_challenge_progress').delete().eq('user_id', targetUserId);
            await _supabase.from('profiles').delete().eq('id', targetUserId);
          } catch (_) {}
        }

        await _loadAdminData();
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Account Deleted',
            message: 'Player @$username has been permanently deleted.',
            icon: LucideIcons.circleCheck,
          );
        }
      } catch (e) {
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Delete Failed',
            message: 'Failed to delete account: $e',
            icon: LucideIcons.circleAlert,
          );
        }
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp.toString()).toLocal();
      final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[dt.month - 1];
      final day = dt.day.toString().padLeft(2, '0');
      final year = dt.year;
      final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$day $month $year, $hour:$minute $period';
    } catch (_) {
      return timestamp.toString();
    }
  }

  Future<void> _togglePlayerActiveStatus(Map<String, dynamic> player) async {
    final bool currentActive = player['is_active'] as bool? ?? true;
    final bool willActivate = !currentActive;
    final username = player['username'] ?? 'Player';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.backgroundSecondary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              willActivate ? LucideIcons.userCheck : LucideIcons.userX,
              color: willActivate ? AppColors.accentEmerald : Colors.redAccent,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              willActivate ? 'Activate Player?' : 'Deactivate Player?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          willActivate
              ? 'Reactivate account for @$username? They will be allowed to log in and play.'
              : 'Deactivate account for @$username? They will be blocked from logging in with a prompt to contact admin at limonislamborno@gmail.com.',
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willActivate ? AppColors.accentEmerald : Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willActivate ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _supabase.from('profiles').update({'is_active': willActivate}).eq('id', player['id']);
        await _loadAdminData();
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Status Updated',
            message: willActivate ? '@$username is now Active' : '@$username is now Inactive (Suspended)',
            icon: willActivate ? LucideIcons.circleCheck : LucideIcons.circleAlert,
          );
        }
      } catch (e) {
        if (mounted) {
          await showAppNoticeDialog(
            context,
            title: 'Error',
            message: 'Failed to update status: $e',
            icon: LucideIcons.circleAlert,
          );
        }
      }
    }
  }

  void _showFullScreenPhoto(String url, String owner) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) => Container(
                    padding: const EdgeInsets.all(24),
                    color: Colors.black87,
                    child: const Text('Failed to load full photo', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              bottom: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('Uploaded by @$owner', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _handleBackPress() {

    if (_selectedUserFilter != null) {
      setState(() {
        _selectedUserFilter = null;
        if (_previousTabIndex == 1) {
          _tabController.animateTo(1);
          _previousTabIndex = 0;
        }
      });
      return true;
    }

    if (_tabController.index != 0) {
      setState(() {
        _tabController.animateTo(0);
      });
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_handleBackPress()) {
          if (widget.onExitToShell != null) {
            widget.onExitToShell!();
          } else {
            Navigator.of(context).maybePop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(LucideIcons.arrowLeft, color: AppColors.textPrimary),
            onPressed: () {
              if (!_handleBackPress()) {
                if (widget.onExitToShell != null) {
                  widget.onExitToShell!();
                } else {
                  Navigator.of(context).maybePop();
                }
              }
            },
          ),
          title: Row(
            children: const [
              Icon(LucideIcons.shieldCheck, color: AppColors.primaryOrange, size: 22),
              SizedBox(width: 8),
              Text(
                'Snapzle Admin Console',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textPrimary),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.refreshCw, size: 18, color: AppColors.textPrimary),
              tooltip: 'Refresh All Data',
              onPressed: _loadAdminData,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            labelColor: AppColors.primaryOrange,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primaryOrange,
            indicatorWeight: 3,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            tabs: const [
              Tab(icon: Icon(LucideIcons.layoutDashboard, size: 18), text: 'Overview'),
              Tab(icon: Icon(LucideIcons.users, size: 18), text: 'Players'),
              Tab(icon: Icon(LucideIcons.images, size: 18), text: 'Photos Vault'),
            ],
          ),
        ),
        body: Stack(
          children: [

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

            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primaryOrange))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildOverviewTab(),
                      _buildPlayersTab(),
                      _buildPhotosTab(),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverviewTab() {
    return RefreshIndicator(
      onRefresh: _loadAdminData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [

          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryOrange.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                )
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(LucideIcons.crown, color: Colors.amberAccent, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Master Admin Access',
                        style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'limonislamborno@gmail.com',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(LucideIcons.shieldCheck, color: AppColors.accentEmerald, size: 13),
                            SizedBox(width: 4),
                            Text(
                              'Full Privileges Active',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _statCard(
                  title: 'Players',
                  val: '${_allPlayers.length}',
                  subtitle: 'Registered gamers',
                  icon: LucideIcons.users,
                  color: AppColors.primaryBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _statCard(
                  title: 'Vault Photos',
                  val: '${_allPhotos.length}',
                  subtitle: 'Private user images',
                  icon: LucideIcons.images,
                  color: AppColors.accentEmerald,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(LucideIcons.server, color: AppColors.primaryOrange, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Live Cloud Infrastructure',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _serviceStatusRow('Spring Boot Backend', 'https://snapzle.onrender.com', 'LIVE', AppColors.accentEmerald),
                const Divider(height: 16, color: AppColors.glassBorder),
                _serviceStatusRow('PostgreSQL Database', 'Supabase Cloud (bjwttdvyajsbfnbcspkc)', 'CONNECTED', AppColors.accentEmerald),
                const Divider(height: 16, color: AppColors.glassBorder),
                _serviceStatusRow('Encrypted Photos Vault', 'Storage Bucket: user-photos', 'ENCRYPTED', AppColors.primary),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required String title,
    required String val,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.glassBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 12),
          Text(
            val,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _serviceStatusRow(String name, String host, String status, Color statusColor) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textPrimary)),
              Text(host, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: statusColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildPlayersTab() {
    final filtered = _allPlayers.where((p) {
      final name = (p['username'] as String? ?? '').toLowerCase();
      final email = (p['email'] as String? ?? '').toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || email.contains(q);
    }).toList();

    return Column(
      children: [

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Search player by username or email...',
              hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
              prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppColors.textSecondary),
              filled: true,
              fillColor: AppColors.surfaceMuted,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.glassBorder),
              ),
            ),
          ),
        ),

        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No players found', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (ctx, idx) {
                    final p = filtered[idx];
                    final username = p['username'] as String? ?? 'Player';
                    final email = p['email'] as String? ?? 'No email recorded';
                    final createdAt = _formatDate(p['created_at']);
                    final bool isActive = p['is_active'] as bool? ?? true;
                    final points = p['points'] as int? ?? 0;
                    final games = p['games_played'] as int? ?? 0;
                    final level = p['level'] as int? ?? 1;

                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isActive ? AppColors.glassBorder : Colors.redAccent.withValues(alpha: 0.4),
                          width: isActive ? 1.0 : 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [

                          Row(
                            children: [
                              AvatarView(
                                photoUrl: p['avatar_url'] as String?,
                                cartoonPhotoUrl: p['avatar_cartoon_url'] as String?,
                                avatarStyle: p['avatar_style'] as String? ?? 'original',
                                emoji: p['avatar_emoji'] as String? ?? '🦊',
                                gradientIndex: (p['avatar_gradient'] as num?)?.toInt() ?? 0,
                                size: 44,
                                hasRing: true,
                              ),
                              const SizedBox(width: 12),
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
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: AppColors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: isActive
                                                ? AppColors.accentEmerald.withValues(alpha: 0.12)
                                                : Colors.redAccent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: isActive
                                                  ? AppColors.accentEmerald.withValues(alpha: 0.4)
                                                  : Colors.redAccent.withValues(alpha: 0.4),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                isActive ? LucideIcons.checkCircle2 : LucideIcons.ban,
                                                size: 11,
                                                color: isActive ? AppColors.accentEmerald : Colors.redAccent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                isActive ? 'ACTIVE' : 'INACTIVE',
                                                style: TextStyle(
                                                  color: isActive ? AppColors.accentEmerald : Colors.redAccent,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w900,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Level $level • $points pts • $games games played',
                                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),

                              Tooltip(
                                message: isActive ? 'Click to Deactivate' : 'Click to Activate',
                                child: Transform.scale(
                                  scale: 0.78,
                                  child: Switch(
                                    value: isActive,
                                    activeThumbColor: AppColors.accentEmerald,
                                    activeTrackColor: AppColors.accentEmerald.withValues(alpha: 0.35),
                                    inactiveThumbColor: Colors.redAccent,
                                    inactiveTrackColor: Colors.redAccent.withValues(alpha: 0.35),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (_) => _togglePlayerActiveStatus(p),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.images, size: 19, color: AppColors.primary),
                                tooltip: 'View Photos',
                                onPressed: () {
                                  setState(() {
                                    _previousTabIndex = 1;
                                    _selectedUserFilter = p['id'] as String?;
                                    _tabController.animateTo(2);
                                  });
                                },
                              ),
                              IconButton(
                                icon: const Icon(LucideIcons.rotateCcw, size: 18, color: AppColors.primaryOrange),
                                tooltip: 'Reset Points',
                                onPressed: () => _resetPlayerPoints(p),
                              ),
                              if (p['id'] != _supabase.auth.currentUser?.id)
                                IconButton(
                                  icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                                  tooltip: 'Delete Account',
                                  onPressed: () => _deletePlayerAccountAsAdmin(p),
                                ),
                            ],
                          ),

                          const SizedBox(height: 10),
                          const Divider(height: 1, color: AppColors.glassBorder),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              const Icon(LucideIcons.mail, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),

                          Row(
                            children: [
                              const Icon(LucideIcons.calendar, size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 8),
                              Text(
                                'Created: $createdAt',
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildPhotosTab() {
    if (_allPhotos.isEmpty) {
      return const Center(
        child: Text('No user photos found in vault', style: TextStyle(color: AppColors.textSecondary)),
      );
    }

    final Map<String, List<Map<String, dynamic>>> photosByUser = {};
    for (final photo in _allPhotos) {
      final userId = photo['user_id'] as String? ?? 'unknown';
      photosByUser.putIfAbsent(userId, () => []).add(photo);
    }

    final userIdsWithPhotos = photosByUser.keys.toList();

    final displayedUserIds = _selectedUserFilter == null
        ? userIdsWithPhotos
        : userIdsWithPhotos.where((id) => id == _selectedUserFilter).toList();

    return RefreshIndicator(
      onRefresh: _loadAdminData,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [

          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: FilterChip(
                    label: Text('All (${_allPhotos.length})'),
                    selected: _selectedUserFilter == null,
                    selectedColor: AppColors.primaryOrange.withValues(alpha: 0.2),
                    checkmarkColor: AppColors.primaryOrange,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: _selectedUserFilter == null ? FontWeight.bold : FontWeight.w500,
                      color: _selectedUserFilter == null ? AppColors.primaryOrange : AppColors.textSecondary,
                    ),
                    onSelected: (_) => setState(() => _selectedUserFilter = null),
                  ),
                ),
                ...userIdsWithPhotos.map((userId) {
                  final userPhotos = photosByUser[userId]!;
                  final ownerName = userPhotos.first['owner_name'] as String? ?? 'User';
                  final isSelected = _selectedUserFilter == userId;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: FilterChip(
                      label: Text('@$ownerName (${userPhotos.length})'),
                      selected: isSelected,
                      selectedColor: AppColors.primary.withValues(alpha: 0.2),
                      checkmarkColor: AppColors.primary,
                      labelStyle: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                      onSelected: (_) => setState(() => _selectedUserFilter = isSelected ? null : userId),
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          if (_selectedUserFilter != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ActionChip(
                  avatar: const Icon(LucideIcons.arrowLeft, size: 14, color: AppColors.primaryOrange),
                  label: Text(_previousTabIndex == 1 ? 'Back to Players List' : 'Back to All Photos'),
                  backgroundColor: AppColors.surfaceMuted,
                  labelStyle: const TextStyle(color: AppColors.primaryOrange, fontWeight: FontWeight.bold, fontSize: 12),
                  onPressed: _handleBackPress,
                ),
              ),
            ),

          if (displayedUserIds.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(
                child: Text('No photos for selected user.', style: TextStyle(color: AppColors.textSecondary)),
              ),
            )
          else
            ...displayedUserIds.map((userId) {
              final userPhotos = photosByUser[userId]!;
              final ownerName = userPhotos.first['owner_name'] as String? ?? 'User';

              int totalSizeKb = 0;
              for (final p in userPhotos) {
                totalSizeKb += (p['file_size_kb'] as int? ?? 0);
              }

              return Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                decoration: BoxDecoration(
                  color: AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.glassBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    Padding(
                      padding: const EdgeInsets.all(14.0),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                            child: Text(
                              ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'U',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '@$ownerName',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '${userPhotos.length} photos • $totalSizeKb KB in vault',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(LucideIcons.trash2, size: 18, color: Colors.redAccent),
                            tooltip: 'Delete all photos of @$ownerName',
                            onPressed: () => _deleteAllPhotosForUser(userId, ownerName, userPhotos),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.glassBorder),

                    GridView.builder(
                      padding: const EdgeInsets.all(12),
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: userPhotos.length,
                      itemBuilder: (ctx, pIdx) {
                        final photo = userPhotos[pIdx];
                        final signedUrl = photo['signed_url'] as String? ?? '';
                        final sizeKb = photo['file_size_kb'] as int? ?? 0;

                        return ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [

                              signedUrl.isNotEmpty
                                  ? GestureDetector(
                                      onTap: () => _showFullScreenPhoto(signedUrl, ownerName),
                                      child: Image.network(
                                        signedUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) => Container(
                                          color: AppColors.surfaceMuted,
                                          child: const Icon(LucideIcons.imageOff, size: 18, color: AppColors.textMuted),
                                        ),
                                      ),
                                    )
                                  : Container(
                                      color: AppColors.surfaceMuted,
                                      child: const Icon(LucideIcons.image, color: AppColors.textMuted),
                                    ),

                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => _deletePhotoAsAdmin(photo),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(alpha: 0.7),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(LucideIcons.trash2, size: 12, color: Colors.redAccent),
                                  ),
                                ),
                              ),

                              Positioned(
                                bottom: 0,
                                left: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  color: Colors.black.withValues(alpha: 0.6),
                                  child: Text(
                                    '$sizeKb KB',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
