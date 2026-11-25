import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cartoon_service.dart';
import 'api_service.dart';

class PhotoItem {
  final String id;
  final String name;
  final String storagePath;
  final String signedUrl;
  final int sizeKb;

  PhotoItem({
    required this.id,
    required this.name,
    required this.storagePath,
    required this.signedUrl,
    required this.sizeKb,
  });
}

class SupabaseService {
  static final SupabaseClient client = Supabase.instance.client;

  static User? get currentUser => client.auth.currentUser;

  /// Global reactive notifier for profile, avatar and points updates
  static final ValueNotifier<int> profileUpdateNotifier = ValueNotifier<int>(0);

  static void notifyProfileChanged() {
    profileUpdateNotifier.value++;
  }

  /// In-memory cache of user photos shared across screens
  static List<PhotoItem> cachedPhotos = [];

  /// Loads all private photos of current user with freshly generated signed URLs
  static Future<List<PhotoItem>> loadUserPhotos() async {
    final user = currentUser;
    if (user == null) return [];

    final response = await client
        .from('photos')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final List<PhotoItem> list = [];
    for (final row in response) {
      final path = row['storage_path'] as String;
      try {
        final signedUrl = await client.storage.from('user-photos').createSignedUrl(path, 3600);
        list.add(PhotoItem(
          id: row['id'].toString(),
          name: row['photo_name'] ?? 'Photo',
          storagePath: path,
          signedUrl: signedUrl,
          sizeKb: row['file_size_kb'] ?? 0,
        ));
      } catch (_) {
        // Skip invalid/deleted storage object
      }
    }
    cachedPhotos = list;
    return list;
  }

  /// Compresses the image to WebP/JPEG max 1080x1080 (~150-250KB) and uploads to private bucket
  /// Compatible with BOTH Flutter Web (Chrome) and Mobile (Android)
  static Future<void> uploadPhoto(XFile pickedFile) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    // 1. Read bytes from picked file (Universal Web & Mobile)
    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Invalid image file format');

    // 2. Resize to max 1080 dimension
    img.Image resized = decoded;
    if (decoded.width > 1080 || decoded.height > 1080) {
      resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? 1080 : null,
        height: decoded.height >= decoded.width ? 1080 : null,
      );
    }

    // 3. Compress to JPEG 80% quality (~150KB - 250KB)
    final Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));

    // 4. Generate unique file name
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '${user.id}/photo_$timestamp.jpg';

    // 5. Upload to Supabase Storage 'user-photos'
    await client.storage.from('user-photos').uploadBinary(
          storagePath,
          compressedBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    // 6. Save metadata in 'photos' table
    await client.from('photos').insert({
      'user_id': user.id,
      'photo_name': pickedFile.name,
      'storage_path': storagePath,
      'file_size_kb': compressedBytes.length ~/ 1024,
    });
  }

  /// Deletes a photo from both DB and private storage
  static Future<void> deletePhoto(PhotoItem photo) async {
    final user = currentUser;
    if (user == null) return;

    await client.from('photos').delete().eq('id', photo.id);
    await client.storage.from('user-photos').remove([photo.storagePath]);
  }

  /// Uploads user avatar, generates an accurate cartoon version, creates signed URLs, and saves to user metadata & profile
  static Future<Map<String, String>> uploadAvatar(XFile pickedFile) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Invalid image file format');

    // 1. Resize original to max 512x512
    img.Image resized = decoded;
    if (decoded.width > 512 || decoded.height > 512) {
      resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? 512 : null,
        height: decoded.height >= decoded.width ? 512 : null,
      );
    }
    final Uint8List originalBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

    // 2. Generate accurate cartoon version
    final Uint8List cartoonBytes = CartoonService.cartoonifyBytes(bytes);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originalPath = '${user.id}/avatar_$timestamp.jpg';
    final cartoonPath = '${user.id}/avatar_cartoon_$timestamp.jpg';

    // 3. Upload both original and cartoon to user-photos bucket
    await client.storage.from('user-photos').uploadBinary(
          originalPath,
          originalBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    await client.storage.from('user-photos').uploadBinary(
          cartoonPath,
          cartoonBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    // 4. Create 1-year signed URLs
    final originalSignedUrl = await client.storage.from('user-photos').createSignedUrl(originalPath, 31536000);
    final cartoonSignedUrl = await client.storage.from('user-photos').createSignedUrl(cartoonPath, 31536000);

    // 5. Save to auth user metadata
    await client.auth.updateUser(
      UserAttributes(data: {
        'avatar_url': originalSignedUrl,
        'avatar_cartoon_url': cartoonSignedUrl,
        'avatar_path': originalPath,
        'avatar_cartoon_path': cartoonPath,
        'avatar_style': 'original',
      }),
    );

    // 6. Also update profiles table if columns exist
    try {
      await client.from('profiles').update({
        'avatar_url': originalSignedUrl,
        'avatar_cartoon_url': cartoonSignedUrl,
        'avatar_style': 'original',
      }).eq('id', user.id);
    } catch (_) {}

    notifyProfileChanged();

    return {
      'original': originalSignedUrl,
      'cartoon': cartoonSignedUrl,
    };
  }

  /// Generates cartoon version for an already uploaded avatar if not yet generated
  static Future<String?> generateCartoonForCurrentAvatar() async {
    final user = currentUser;
    if (user == null) return null;

    final metadata = user.userMetadata ?? {};
    final existingCartoon = metadata['avatar_cartoon_url'] as String?;
    if (existingCartoon != null && existingCartoon.isNotEmpty) {
      return existingCartoon;
    }

    final avatarPath = metadata['avatar_path'] as String?;
    if (avatarPath == null) return null;

    try {
      final bytes = await client.storage.from('user-photos').download(avatarPath);
      final cartoonBytes = CartoonService.cartoonifyBytes(bytes);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final cartoonPath = '${user.id}/avatar_cartoon_$timestamp.jpg';

      await client.storage.from('user-photos').uploadBinary(
            cartoonPath,
            cartoonBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );

      final cartoonSignedUrl = await client.storage.from('user-photos').createSignedUrl(cartoonPath, 31536000);

      await client.auth.updateUser(
        UserAttributes(data: {
          'avatar_cartoon_url': cartoonSignedUrl,
          'avatar_cartoon_path': cartoonPath,
        }),
      );

      try {
        await client.from('profiles').update({
          'avatar_cartoon_url': cartoonSignedUrl,
        }).eq('id', user.id);
      } catch (_) {}

      notifyProfileChanged();
      return cartoonSignedUrl;
    } catch (_) {
      return null;
    }
  }

  /// Updates avatar style: 'original' or 'cartoon'
  static Future<void> updateAvatarStyle(String style) async {
    final user = currentUser;
    if (user == null) return;

    await client.auth.updateUser(
      UserAttributes(data: {
        'avatar_style': style,
      }),
    );

    try {
      await client.from('profiles').update({
        'avatar_style': style,
      }).eq('id', user.id);
    } catch (_) {}

    notifyProfileChanged();
  }

  /// Records game win, awards points and increments games played
  static Future<void> recordGameWin(
    int score, {
    String gameType = 'puzzle',
    int moves = 0,
    int elapsedSeconds = 0,
  }) async {
    final user = currentUser;
    if (user == null) return;

    try {
      final profile = await client
          .from('profiles')
          .select('points, games_played')
          .eq('id', user.id)
          .maybeSingle();

      final currentPoints = (profile?['points'] as num?)?.toInt() ?? 0;
      final currentGames = (profile?['games_played'] as num?)?.toInt() ?? 0;

      await client.from('profiles').update({
        'points': currentPoints + score,
        'games_played': currentGames + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      // Record in game_sessions
      String mappedType = 'puzzle';
      final lower = gameType.toLowerCase();
      if (lower.contains('slide')) {
        mappedType = 'slide';
      } else if (lower.contains('memory')) {
        mappedType = 'memory';
      } else if (lower.contains('difference') || lower.contains('diff')) {
        mappedType = 'diff';
      }

      await client.from('game_sessions').insert({
        'user_id': user.id,
        'game_type': mappedType,
        'score': score,
        'moves': moves,
        'elapsed_seconds': elapsedSeconds,
        'completed': true,
      });

      notifyProfileChanged();
    } catch (_) {}
  }

  /// Fetches current user's profile stats (points, games_played, global rank)
  static Future<Map<String, dynamic>> getUserProfileStats() async {
    final user = currentUser;
    if (user == null) {
      return {'points': 0, 'games_played': 0, 'rank': '#--'};
    }

    try {
      final profile = await client.from('profiles').select().eq('id', user.id).maybeSingle();

      int points = 0;
      int games = 0;
      if (profile != null) {
        points = (profile['points'] as num?)?.toInt() ?? 0;
        games = (profile['games_played'] as num?)?.toInt() ?? 0;
      }

      final higherCount = await client
          .from('profiles')
          .count(CountOption.exact)
          .gt('points', points);

      final metadata = user.userMetadata ?? {};
      final avatarUrl = metadata['avatar_url'] as String? ?? profile?['avatar_url'] as String?;
      final avatarCartoonUrl = metadata['avatar_cartoon_url'] as String? ?? profile?['avatar_cartoon_url'] as String?;
      final avatarStyle = metadata['avatar_style'] as String? ?? profile?['avatar_style'] as String? ?? 'original';

      // Auto-sync avatar metadata to profiles table so all other users on the leaderboard can see it
      if (metadata.isNotEmpty && (metadata['avatar_url'] != null || metadata['avatar_cartoon_url'] != null)) {
        final dbAvatar = profile?['avatar_url'] as String?;
        final dbCartoon = profile?['avatar_cartoon_url'] as String?;
        final dbStyle = profile?['avatar_style'] as String?;

        if (dbAvatar != avatarUrl || dbCartoon != avatarCartoonUrl || dbStyle != avatarStyle) {
          try {
            await client.from('profiles').update({
              if (avatarUrl != null) 'avatar_url': avatarUrl,
              if (avatarCartoonUrl != null) 'avatar_cartoon_url': avatarCartoonUrl,
              'avatar_style': avatarStyle,
            }).eq('id', user.id);
          } catch (_) {}
        }
      }

      return {
        'points': points,
        'games_played': games,
        'rank': '#${higherCount + 1}',
        'avatar_url': avatarUrl,
        'avatar_cartoon_url': avatarCartoonUrl,
        'avatar_style': avatarStyle,
      };
    } catch (_) {
      return {
        'points': 0,
        'games_played': 0,
        'rank': '#--',
        'avatar_url': null,
        'avatar_cartoon_url': null,
        'avatar_style': 'original',
      };
    }
  }

  /// Fetches live leaderboard sorted by points descending
  static Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    try {
      final response = await client
          .from('profiles')
          .select()
          .order('points', ascending: false)
          .limit(limit);
  /// Checks if a username is already taken by another player
  static Future<bool> isUsernameTaken(String username) async {
    final clean = username.trim();
    if (clean.isEmpty) return false;

    try {
      // 1. Direct Supabase query (case-insensitive)
      final existing = await client
          .from('profiles')
          .select('id')
          .ilike('username', clean)
          .maybeSingle();
      if (existing != null) return true;
    } catch (_) {}

    try {
      // 2. Secondary check via Spring Boot backend API
      return await ApiService().checkUsernameExists(clean);
    } catch (_) {}

    return false;
  }
}
