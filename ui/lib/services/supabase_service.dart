import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'cartoon_service.dart';
import 'api_service.dart';
import 'game_progress_service.dart';

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

  static bool get isMasterAdmin {
    final user = client.auth.currentUser;
    if (user == null) return false;
    final email = (user.email ?? '').toLowerCase().trim();
    final metaEmail = (user.userMetadata?['email'] as String? ?? '').toLowerCase().trim();
    final username = (user.userMetadata?['username'] as String? ?? '').toLowerCase().trim();
    return email == 'limonislamborno@gmail.com' ||
        email.contains('limonislamborno') ||
        metaEmail == 'limonislamborno@gmail.com' ||
        metaEmail.contains('limonislamborno') ||
        username == 'limonislamborno' ||
        username.contains('limonislamborno');
  }

  static final ValueNotifier<int> profileUpdateNotifier = ValueNotifier<int>(0);

  static void notifyProfileChanged() {
    profileUpdateNotifier.value++;
  }

  static List<PhotoItem> cachedPhotos = [];

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

      }
    }
    cachedPhotos = list;
    return list;
  }

  static Future<void> uploadPhoto(XFile pickedFile) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Invalid image file format');

    img.Image resized = decoded;
    if (decoded.width > 1080 || decoded.height > 1080) {
      resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? 1080 : null,
        height: decoded.height >= decoded.width ? 1080 : null,
      );
    }

    final Uint8List compressedBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 80));

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storagePath = '${user.id}/photo_$timestamp.jpg';

    await client.storage.from('user-photos').uploadBinary(
          storagePath,
          compressedBytes,
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );

    await client.from('photos').insert({
      'user_id': user.id,
      'photo_name': pickedFile.name,
      'storage_path': storagePath,
      'file_size_kb': compressedBytes.length ~/ 1024,
    });
  }

  static Future<void> deletePhoto(PhotoItem photo) async {
    final user = currentUser;
    if (user == null) return;

    await client.from('photos').delete().eq('id', photo.id);
    await client.storage.from('user-photos').remove([photo.storagePath]);
  }

  static Future<Map<String, String>> uploadAvatar(XFile pickedFile) async {
    final user = currentUser;
    if (user == null) throw Exception('User not authenticated');

    final bytes = await pickedFile.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) throw Exception('Invalid image file format');

    img.Image resized = decoded;
    if (decoded.width > 512 || decoded.height > 512) {
      resized = img.copyResize(
        decoded,
        width: decoded.width > decoded.height ? 512 : null,
        height: decoded.height >= decoded.width ? 512 : null,
      );
    }
    final Uint8List originalBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));

    final Uint8List cartoonBytes = CartoonService.cartoonifyBytes(bytes);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final originalPath = '${user.id}/avatar_$timestamp.jpg';
    final cartoonPath = '${user.id}/avatar_cartoon_$timestamp.jpg';

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

    final originalSignedUrl = await client.storage.from('user-photos').createSignedUrl(originalPath, 31536000);
    final cartoonSignedUrl = await client.storage.from('user-photos').createSignedUrl(cartoonPath, 31536000);

    await client.auth.updateUser(
      UserAttributes(data: {
        'avatar_url': originalSignedUrl,
        'avatar_cartoon_url': cartoonSignedUrl,
        'avatar_path': originalPath,
        'avatar_cartoon_path': cartoonPath,
        'avatar_style': 'original',
      }),
    );

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

  static Future<List<Map<String, dynamic>>> fetchLeaderboard({int limit = 50}) async {
    try {
      final response = await client
          .from('profiles')
          .select()
          .order('points', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  static Future<bool> isUsernameTaken(String username) async {
    final clean = username.trim();
    if (clean.isEmpty) return false;

    try {

      final existing = await client
          .from('profiles')
          .select('id')
          .ilike('username', clean)
          .maybeSingle();
      if (existing != null) return true;
    } catch (_) {}

    try {

      return await ApiService().checkUsernameExists(clean);
    } catch (_) {}

    return false;
  }

  static Future<void> resetUserData({
    required bool resetGames,
    required bool resetPhotos,
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;

    if (resetPhotos) {
      try {
        final photosData = await client
            .from('photos')
            .select('storage_path, diff_storage_path')
            .eq('user_id', user.id);

        final List<String> pathsToDelete = [];
        for (final row in photosData) {
          final sPath = row['storage_path'] as String?;
          if (sPath != null && sPath.isNotEmpty) pathsToDelete.add(sPath);
          final dPath = row['diff_storage_path'] as String?;
          if (dPath != null && dPath.isNotEmpty) pathsToDelete.add(dPath);
        }

        if (pathsToDelete.isNotEmpty) {
          await client.storage.from('user-photos').remove(pathsToDelete);
        }

        await client.from('photos').delete().eq('user_id', user.id);
        cachedPhotos.clear();
      } catch (e) {
        debugPrint('Error resetting photos: $e');
      }
    }

    if (resetGames) {
      try {
        await client.from('profiles').update({
          'points': 0,
          'games_played': 0,
          'xp': 0,
          'level': 1,
          'streak': 1,
        }).eq('id', user.id);

        await client.from('game_sessions').delete().eq('user_id', user.id);
        await client.from('user_game_bests').delete().eq('user_id', user.id);

        GameProgressService.resetInMemory();
      } catch (e) {
        debugPrint('Error resetting game history: $e');
      }
    }
  }

  static Future<void> deleteAccount() async {
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      final photosData = await client
          .from('photos')
          .select('storage_path, diff_storage_path')
          .eq('user_id', user.id);

      final List<String> pathsToDelete = [];
      for (final row in photosData) {
        final sPath = row['storage_path'] as String?;
        if (sPath != null && sPath.isNotEmpty) pathsToDelete.add(sPath);
        final dPath = row['diff_storage_path'] as String?;
        if (dPath != null && dPath.isNotEmpty) pathsToDelete.add(dPath);
      }
      if (pathsToDelete.isNotEmpty) {
        await client.storage.from('user-photos').remove(pathsToDelete);
      }
    } catch (_) {}

    try {
      await ApiService().deleteAccount();
    } catch (_) {}

    try {
      await client.rpc('delete_user_account');
    } catch (_) {
      try {
        await client.from('photos').delete().eq('user_id', user.id);
        await client.from('game_sessions').delete().eq('user_id', user.id);
        await client.from('user_game_bests').delete().eq('user_id', user.id);
        await client.from('profiles').delete().eq('id', user.id);
      } catch (_) {}
    }

    GameProgressService.resetInMemory();
    cachedPhotos.clear();
    await client.auth.signOut();
  }
}
