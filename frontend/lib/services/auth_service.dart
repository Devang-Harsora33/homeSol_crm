import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import '../models/profile.dart';

class AuthService {
  static String? _testBaseUrl;
  static String? _testCookie;
  static Map<String, dynamic>? _testUserData;

  static String get baseUrl => _testBaseUrl ?? dotenv.env['BASE_URL'] ?? 'https://erp.homesolindia.com';

  static const String cookieKey = 'auth_cookie';
  static const String userKey = 'user_data';

  // For testing purposes
  static void setTestValues({String? baseUrl, String? cookie, Map<String, dynamic>? userData}) {
    _testBaseUrl = baseUrl;
    _testCookie = cookie;
    _testUserData = userData;
  }

  // For testing purposes
  static void clearTestValues() {
    _testBaseUrl = null;
    _testCookie = null;
    _testUserData = null;
  }
  // 1. LOGIN (Adapted for Frappe)
  static Future<Map<String, dynamic>> loginBroker({
    required String email,
    required String password,
  }) async {
    try {
      // Frappe Standard Login Endpoint
      final response = await http.post(
        Uri.parse('$baseUrl/api/method/login'),
        body: {'usr': email, 'pwd': password},
      );

      if (response.statusCode == 200) {
        // 1. Extract the Session Cookie (sid) from headers
        String? rawCookie = response.headers['set-cookie'];
        if (rawCookie != null) {
          // We split it to get just the "sid=..." part
          int index = rawCookie.indexOf(';');
          String cookie = (index == -1)
              ? rawCookie
              : rawCookie.substring(0, index);

          await _saveCookie(cookie);

          // 2. Fetch User Details immediately to match your old flow
          final userDetails = await _fetchLoggedInUser(cookie);

          if (userDetails != null) {
            await _saveUserData(userDetails);
            return {'success': true, 'data': userDetails};
          }
        }
        return {
          'success': true,
          'data': {'message': 'Logged in'},
        };
      } else {
        // Frappe usually returns HTML error pages or JSON messages
        var msg = 'Login failed';
        try {
          final body = jsonDecode(response.body);
          msg = body['message'] ?? msg;
        } catch (_) {}

        return {'success': false, 'error': msg};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // 1.5. REGISTER BROKER
  static Future<Map<String, dynamic>> registerBroker({
    required String username,
    required String email,
    required String password,
    required String firmName,
    required String name,
    required String address,
    required String phoneNo,
    required String reraNumber,
    String? profileImage,
    required bool freelancing,
    required String workmode,
    required String teamSize,
  }) async {
    try {
      // For now, this is a placeholder - you may need to implement actual registration
      // based on your backend API
      final response = await http.post(
        Uri.parse('$baseUrl/api/resource/User'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': username,
          'email': email,
          'first_name': name,
          'phone': phoneNo,
          'user_type': 'Website User',
          // Add other fields as needed
        }),
      );

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Registration successful'};
      } else {
        return {'success': false, 'error': 'Registration failed'};
      }
    } catch (e) {
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  // 1.6. FETCH LOGGED IN USER
  static Future<Map<String, dynamic>?> _fetchLoggedInUser(String cookie) async {
    try {
      // Get the email of the logged-in user
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/frappe.auth.get_logged_user'),
        headers: {'Cookie': cookie},
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final email = body['message'];

        // OPTIONAL: Fetch full "Employee" or "User" details here if needed
        return {
          'email': email,
          // You can add more fields here by fetching api/resource/User/email
        };
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, String>> getHeaders() async {
    final cookie = await getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  // 2. GET BROKER / USER DATA
  static Future<Map<String, dynamic>?> getBroker(String brokerId) async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      // Assuming "Broker" is a User or Employee in ERPNext
      // Adjust "User" to your custom DocType if you have one (e.g. "Broker")
      final response = await http.get(
        Uri.parse('$baseUrl/api/resource/User/$brokerId'),
        headers: {'Cookie': cookie},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return json['data'];
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 2.5. GET USER PROFILE
  static Future<Profile?> getMyProfile() async {
    try {
      final cookie = await getCookie();
      if (cookie == null) return null;

      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_my_profile'),
        headers: {'Cookie': cookie},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return Profile.fromJson(json['message']);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // 3. STORAGE HELPERS (Cookie based)
  static Future<void> _saveCookie(String cookie) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(cookieKey, cookie);
  }

  static Future<String?> getCookie() async {
    if (_testCookie != null) {
      return _testCookie;
    }
    try {
      print('AuthService: Getting cookie from SharedPreferences');
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString(cookieKey);
      print(
        'AuthService: Retrieved cookie: ${cookie != null ? 'exists (${cookie.length} chars)' : 'null'}',
      );
      return cookie;
    } catch (e) {
      print('AuthService: Error getting cookie: $e');
      return null;
    }
  }

  static Future<void> _saveUserData(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userKey, jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUserData() async {
    if (_testUserData != null) {
      return _testUserData;
    }
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(userKey);
    return str != null ? jsonDecode(str) : null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(cookieKey);
    await prefs.remove(userKey);
    
    // Clear all local caches on logout
    try {
      await LeadService.clearAllCaches();
    } catch (e) {
      print('AuthService: Error clearing caches on logout: $e');
    }

    // Optional: Notify server to clear session
    try {
      await http.get(Uri.parse('$baseUrl/api/method/logout'));
    } catch (_) {}
  }

  // 4. UTILITY METHODS
  static Future<bool> isLoggedIn() async {
    try {
      print('AuthService: Checking if logged in');
      final cookie = await getCookie();
      final result = cookie != null && cookie.isNotEmpty;
      print(
        'AuthService: isLoggedIn result: $result, cookie exists: ${cookie != null}',
      );
      return result;
    } catch (e) {
      print('AuthService: Error in isLoggedIn: $e');
      return false;
    }
  }
}
