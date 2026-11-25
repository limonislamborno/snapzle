import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ApiService {
  // Deployed live backend on Render
  static const String baseUrl = 'https://snapzle.onrender.com/api'; 

  final Dio _dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  ApiService() {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session != null) {
          options.headers['Authorization'] = 'Bearer ${session.accessToken}';
        }
        return handler.next(options);
      },
    ));
  }

  // Games Lifecycle
  Future<Map<String, dynamic>> startGame({
    required String gameType,
    required int difficultyLevel,
    String? photoId,
  }) async {
    final response = await _dio.post('/games/start', data: {
      'gameType': gameType,
      'difficultyLevel': difficultyLevel,
      if (photoId != null) 'photoId': photoId,
    });
    return response.data;
  }

  Future<Map<String, dynamic>> finishGame({
    required String sessionId,
    required int moves,
    required int elapsedSeconds,
    bool isPerfect = false,
  }) async {
    final response = await _dio.post('/games/finish', data: {
      'sessionId': sessionId,
      'moves': moves,
      'elapsedSeconds': elapsedSeconds,
      'isPerfect': isPerfect,
    });
    return response.data;
  }

  // Leaderboard
  Future<List<dynamic>> getGlobalLeaderboard({int limit = 50}) async {
    final response = await _dio.get('/public/leaderboard/global', queryParameters: {'limit': limit});
    return response.data;
  }

  // Username Availability Check
  Future<bool> checkUsernameExists(String username) async {
    try {
      final response = await _dio.get('/public/check-username', queryParameters: {'username': username});
      return response.data['exists'] == true;
    } catch (_) {
      return false;
    }
  }

  // User Profile
  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/profile/me');
    return response.data;
  }

  Future<void> recordDailyLogin() async {
    await _dio.post('/profile/daily-login');
  }
}
