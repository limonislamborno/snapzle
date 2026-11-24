import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class GameProgressService {
  static const int requiredPhotosToUnlock = 5;

  /// User-scoped isolation: Each user's progress is stored under their unique Supabase UID
  static String get _userId => Supabase.instance.client.auth.currentUser?.id ?? 'guest';

  static String _photoPuzzle3Key(String uid) => 'snapzle_${uid}_cleared_photos_photo_puzzle_3';
  static String _photoPuzzle4Key(String uid) => 'snapzle_${uid}_cleared_photos_photo_puzzle_4';
  static String _slidingPuzzle3Key(String uid) => 'snapzle_${uid}_cleared_photos_sliding_puzzle_3';
  static String _memoryMatch6Key(String uid) => 'snapzle_${uid}_wins_memory_match_6';
  static String _memoryMatch8Key(String uid) => 'snapzle_${uid}_wins_memory_match_8';

  // In-memory sets & win counters scoped to the active user
  static Set<String> clearedPhotoPuzzle3 = {};
  static Set<String> clearedPhotoPuzzle4 = {};
  static Set<String> clearedSlidingPuzzle3 = {};
  static int memoryMatchWins6 = 0;
  static int memoryMatchWins8 = 0;

  /// Resets in-memory caches (called on logout or account switch)
  static void resetInMemory() {
    clearedPhotoPuzzle3 = {};
    clearedPhotoPuzzle4 = {};
    clearedSlidingPuzzle3 = {};
    memoryMatchWins6 = 0;
    memoryMatchWins8 = 0;
  }

  /// Loads saved progression for the currently authenticated user
  static Future<void> loadForCurrentUser() async {
    final uid = _userId;
    try {
      final prefs = await SharedPreferences.getInstance();

      // Clean up any old un-namespaced keys from previous version
      await prefs.remove('snapzle_cleared_photos_photo_puzzle_3');
      await prefs.remove('snapzle_cleared_photos_photo_puzzle_4');
      await prefs.remove('snapzle_cleared_photos_sliding_puzzle_3');
      await prefs.remove('snapzle_wins_memory_match_6');
      await prefs.remove('snapzle_wins_memory_match_8');

      clearedPhotoPuzzle3 = (prefs.getStringList(_photoPuzzle3Key(uid)) ?? []).toSet();
      clearedPhotoPuzzle4 = (prefs.getStringList(_photoPuzzle4Key(uid)) ?? []).toSet();
      clearedSlidingPuzzle3 = (prefs.getStringList(_slidingPuzzle3Key(uid)) ?? []).toSet();
      memoryMatchWins6 = prefs.getInt(_memoryMatch6Key(uid)) ?? 0;
      memoryMatchWins8 = prefs.getInt(_memoryMatch8Key(uid)) ?? 0;
    } catch (_) {}
  }

  // Check if a photo is already cleared in a tier for THIS user
  static bool isPhotoClearedInPhotoPuzzle(int dim, String photoId) {
    if (dim == 3) return clearedPhotoPuzzle3.contains(photoId);
    if (dim == 4) return clearedPhotoPuzzle4.contains(photoId);
    return false;
  }

  static bool isPhotoClearedInSlidingPuzzle(int dim, String photoId) {
    if (dim == 3) return clearedSlidingPuzzle3.contains(photoId);
    return false;
  }

  // Check if a tier is unlocked (requires 5 distinct photo clears by THIS user)
  static bool isPhotoPuzzleUnlocked(int dim) {
    if (dim == 3) return true;
    if (dim == 4) return clearedPhotoPuzzle3.length >= requiredPhotosToUnlock;
    if (dim == 5) return clearedPhotoPuzzle4.length >= requiredPhotosToUnlock;
    return false;
  }

  static bool isSlidingPuzzleUnlocked(int dim) {
    if (dim == 3) return true;
    if (dim == 4) return clearedSlidingPuzzle3.length >= requiredPhotosToUnlock;
    return false;
  }

  static bool isMemoryMatchUnlocked(int pairs) {
    if (pairs == 6) return true;
    if (pairs == 8) return memoryMatchWins6 >= requiredPhotosToUnlock;
    if (pairs == 10) return memoryMatchWins8 >= requiredPhotosToUnlock;
    return false;
  }

  /// Records a win in Photo Puzzle with a specific photoId for the active user
  static Future<({bool isNewPhoto, int totalCleared, bool unlockedNextTier})> recordPhotoPuzzleWin({
    required int dim,
    required String photoId,
  }) async {
    final uid = _userId;
    bool isNewPhoto = false;
    bool unlockedNextTier = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (dim == 3) {
        if (!clearedPhotoPuzzle3.contains(photoId)) {
          isNewPhoto = true;
          clearedPhotoPuzzle3.add(photoId);
          await prefs.setStringList(_photoPuzzle3Key(uid), clearedPhotoPuzzle3.toList());
          if (clearedPhotoPuzzle3.length == requiredPhotosToUnlock) {
            unlockedNextTier = true;
          }
        }
        return (
          isNewPhoto: isNewPhoto,
          totalCleared: clearedPhotoPuzzle3.length,
          unlockedNextTier: unlockedNextTier,
        );
      } else if (dim == 4) {
        if (!clearedPhotoPuzzle4.contains(photoId)) {
          isNewPhoto = true;
          clearedPhotoPuzzle4.add(photoId);
          await prefs.setStringList(_photoPuzzle4Key(uid), clearedPhotoPuzzle4.toList());
          if (clearedPhotoPuzzle4.length == requiredPhotosToUnlock) {
            unlockedNextTier = true;
          }
        }
        return (
          isNewPhoto: isNewPhoto,
          totalCleared: clearedPhotoPuzzle4.length,
          unlockedNextTier: unlockedNextTier,
        );
      }
    } catch (_) {}
    return (isNewPhoto: false, totalCleared: 0, unlockedNextTier: false);
  }

  /// Records a win in Sliding Puzzle with a specific photoId for the active user
  static Future<({bool isNewPhoto, int totalCleared, bool unlockedNextTier})> recordSlidingPuzzleWin({
    required int dim,
    required String photoId,
  }) async {
    final uid = _userId;
    bool isNewPhoto = false;
    bool unlockedNextTier = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (dim == 3) {
        if (!clearedSlidingPuzzle3.contains(photoId)) {
          isNewPhoto = true;
          clearedSlidingPuzzle3.add(photoId);
          await prefs.setStringList(_slidingPuzzle3Key(uid), clearedSlidingPuzzle3.toList());
          if (clearedSlidingPuzzle3.length == requiredPhotosToUnlock) {
            unlockedNextTier = true;
          }
        }
        return (
          isNewPhoto: isNewPhoto,
          totalCleared: clearedSlidingPuzzle3.length,
          unlockedNextTier: unlockedNextTier,
        );
      }
    } catch (_) {}
    return (isNewPhoto: false, totalCleared: 0, unlockedNextTier: false);
  }

  /// Records a win in Memory Match for the active user
  static Future<({int totalWins, bool unlockedNextTier})> recordMemoryMatchWin(int pairs) async {
    final uid = _userId;
    bool unlockedNextTier = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (pairs == 6) {
        memoryMatchWins6++;
        await prefs.setInt(_memoryMatch6Key(uid), memoryMatchWins6);
        if (memoryMatchWins6 == requiredPhotosToUnlock) unlockedNextTier = true;
        return (totalWins: memoryMatchWins6, unlockedNextTier: unlockedNextTier);
      } else if (pairs == 8) {
        memoryMatchWins8++;
        await prefs.setInt(_memoryMatch8Key(uid), memoryMatchWins8);
        if (memoryMatchWins8 == requiredPhotosToUnlock) unlockedNextTier = true;
        return (totalWins: memoryMatchWins8, unlockedNextTier: unlockedNextTier);
      }
    } catch (_) {}
    return (totalWins: 0, unlockedNextTier: false);
  }
}
