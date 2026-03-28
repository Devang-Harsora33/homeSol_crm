import 'dart:convert';
import 'package:Homesol/models/user_profile.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/user_profile_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_user_profile";
  
  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  // Sync user profile from API and store in local database
  static Future<UserProfile?> syncUserProfile({bool forceRefresh = false}) async {
    try {
      print(
        'Syncing user profile from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_my_profile',
      );
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.get_my_profile',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('User profile sync response status: ${response.statusCode}');
      print('User profile sync response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> jsonData = responseData['message'];
        print('User profile JSON data: $jsonData');

        // Store in local database
        final UserProfileDatabase profileDb = UserProfileDatabase();
        await profileDb.upsertUserProfile(jsonData);

        // Update the sync timestamp
        final SharedPreferences prefs = await SharedPreferences.getInstance();
        String formattedTimestamp = jsonData['modified'] ?? DateTime.now().toIso8601String();
        // Format to match Frappe timestamp format
        formattedTimestamp = formattedTimestamp.replaceAll('T', ' ').replaceAll('Z', '');
        await prefs.setString(_lastSyncTimestampKey, formattedTimestamp);
        print('User profile synced successfully. Sync timestamp: $formattedTimestamp');

        return UserProfile.fromJson(jsonData);
      } else {
        print(
          '❌ User profile error: ${response.statusCode} - ${response.body}',
        );
        // Return cached profile on error
        final UserProfileDatabase profileDb = UserProfileDatabase();
        final cachedData = await profileDb.getUserProfile();
        if (cachedData != null) {
          return UserProfile.fromJson(cachedData);
        }
        return null;
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      // Return cached profile on error
      final UserProfileDatabase profileDb = UserProfileDatabase();
      final cachedData = await profileDb.getUserProfile();
      if (cachedData != null) {
        return UserProfile.fromJson(cachedData);
      }
      return null;
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      // Return cached profile on error
      final UserProfileDatabase profileDb = UserProfileDatabase();
      final cachedData = await profileDb.getUserProfile();
      if (cachedData != null) {
        return UserProfile.fromJson(cachedData);
      }
      return null;
    } catch (e) {
      print('❌ General exception caught: $e');
      // Return cached profile on error
      final UserProfileDatabase profileDb = UserProfileDatabase();
      final cachedData = await profileDb.getUserProfile();
      if (cachedData != null) {
        return UserProfile.fromJson(cachedData);
      }
      return null;
    }
  }

  // Fetch user profile from local database
  static Future<UserProfile?> fetchUserProfile({bool forceRefresh = false}) async {
    try {
      // Always sync from API on forceRefresh
      if (forceRefresh) {
        return await syncUserProfile(forceRefresh: true);
      }

      // Load from local database
      final UserProfileDatabase profileDb = UserProfileDatabase();
      final cachedData = await profileDb.getUserProfile();

      if (cachedData == null) {
        print('No user profile in local database, syncing from API...');
        return await syncUserProfile();
      }

      print('Loaded user profile from local database');
      return UserProfile.fromJson(cachedData);
    } catch (e) {
      print('❌ General exception caught while fetching user profile: $e');
      return null;
    }
  }
  
  // Register/update device token for push
  static Future<void> registerDeviceToken({
    required String brokerId,
    required String token,
    String? platform,
  }) async {
    try {
      final authToken = await AuthService.getCookie();
      await http
          .post(
            Uri.parse(
              '${AuthService.baseUrl}/api/v1/brokers/$brokerId/device_token',
            ),
            headers: {
              'Content-Type': 'application/json',
              if (authToken != null) 'Authorization': 'Bearer $authToken',
            },
            body: json.encode({'token': token, 'platform': platform}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // best-effort, ignore failures
    }
  }
}
