import 'dart:convert';
import 'package:Homesol/models/developer.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/developer_database.dart';
import 'package:Homesol/services/image_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';





import '../../connectivity_service.dart';

class DeveloperService {
  static String get baseUrl => AuthService.baseUrl;
  // Cache for developers
  static List<Developer>? _developersCache;
  static DateTime? _developersLastFetch;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_developers";

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  /// Cache logo image for a developer
  static Future<void> _cacheDeveloperLogo(Map<String, dynamic> developerJson) async {
    try {
      final logoUrl = developerJson['logo'] as String?;
      if (logoUrl != null && logoUrl.isNotEmpty) {
        print('Caching logo for developer: ${developerJson['name']}');
        
        final cachedPath = await ImageCacheManager.downloadAndCacheImage(logoUrl);
        if (cachedPath != null) {
          // Store cached path in the developer data for later retrieval
          developerJson['_cached_logo_path'] = cachedPath;
        }
      }
    } catch (e) {
      print('Error caching developer logo: $e');
    }
  }

  // Fetch all developer names from the server for deletion checking
  static Future<List<String>> fetchDeveloperNamesFromServer() async {
    // Check if we are online before trying to fetch from API
    if (!ConnectivityService.isOnline) {
      return [];
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '${AuthService.baseUrl}/api/resource/Developer?fields=["name"]',
        ),
        headers: headers,
      );

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          return items.map((item) => item['name'].toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching developer names from server: $e');
      return [];
    }
  }

  // Sync developers from API and store in local database
  static Future<List<Developer>> syncDevelopers({bool forceRefresh = false}) async {
    // Check if we are online before trying to fetch from API
    if (!ConnectivityService.isOnline) {
      print('Offline: Loading developers from local database');
      final DeveloperDatabase developerDatabase = DeveloperDatabase();
      final List<Map<String, dynamic>> rawDevelopers =
          await developerDatabase.getAllDevelopers();
      return rawDevelopers.map((data) {
        final developerJson = json.decode(data['data']);
        return Developer.fromJson(developerJson);
      }).toList();
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastSyncTimestamp =
        prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";

    print('Last sync timestamp for developers: $lastSyncTimestamp');

    // Encode the filter to be URL-safe
    final String filters = Uri.encodeQueryComponent(
      json.encode([
        ["modified", ">", lastSyncTimestamp]
      ]),
    );

    final Uri uri = Uri.parse(
        '$baseUrl/api/method/homesol_app.api.get_all_developers?filters=$filters');
    print('Requesting URL: $uri');

    try {
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> message = responseBody['message'] ?? [];

        final DeveloperDatabase developerDatabase = DeveloperDatabase();

        // Step 1: Get all local Developer IDs
        final List<Map<String, dynamic>> localDevelopersRaw = await developerDatabase.getAllDevelopers();
        final Set<String> localDeveloperNames = localDevelopersRaw.map((e) => e['name'].toString()).toSet();

        // Step 2: Get all active server Developer IDs
        final List<String> serverDeveloperNamesList = await fetchDeveloperNamesFromServer();
        final Set<String> serverDeveloperNames = serverDeveloperNamesList.toSet();

        // Step 3: Identify developers to delete locally
        final List<String> developersToDelete = localDeveloperNames
            .where((name) => !serverDeveloperNames.contains(name))
            .toList();

        // Step 4: Delete identified developers from local database
        for (final developerName in developersToDelete) {
          await developerDatabase.deleteDeveloper(developerName);
          print('Deleted local developer: $developerName (no longer on server)');
        }

        if (message.isEmpty) {
          print('No new developers to sync.');
          // Return existing developers from database (after potential deletions)
          final List<Map<String, dynamic>> rawDevelopers =
              await developerDatabase.getAllDevelopers();
          return rawDevelopers.map((data) {
            final developerJson = json.decode(data['data']);
            return Developer.fromJson(developerJson);
          }).toList();
        }

        DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp + 'Z');

        for (var developerJson in message) {
          // Ensure developerJson is a Map<String, dynamic>
          if (developerJson is Map<String, dynamic>) {
            // Cache logo image for this developer
            await _cacheDeveloperLogo(developerJson);

            await developerDatabase.upsertDeveloper(developerJson);

            final currentDeveloperModified =
                DateTime.parse(developerJson['modified'] + 'Z');
            if (currentDeveloperModified.isAfter(latestModifiedDate)) {
              latestModifiedDate = currentDeveloperModified;
            }
          }
        }

        // Save the new latest modified timestamp
        // Frappe timestamps can have microseconds, so we need to format correctly
        String formattedTimestamp = latestModifiedDate.toIso8601String();
        // Remove 'T' and 'Z'
        formattedTimestamp = formattedTimestamp.replaceAll('T', ' ').replaceAll('Z', '');
        // Ensure 6 digits for microseconds, padding with zeros if necessary
        List<String> parts = formattedTimestamp.split('.');
        if (parts.length > 1) {
          String microseconds = parts[1];
          if (microseconds.length < 6) {
            microseconds = microseconds.padRight(6, '0');
          } else if (microseconds.length > 6) {
            microseconds = microseconds.substring(0, 6);
          }
          formattedTimestamp = '${parts[0]}.$microseconds';
        } else {
          // No microseconds part, add .000000
          formattedTimestamp = '$formattedTimestamp.000000';
        }
        final String newLastSyncTimestamp = formattedTimestamp;
        await prefs.setString(_lastSyncTimestampKey, newLastSyncTimestamp);
        print('Developers synced successfully. New last sync timestamp: $newLastSyncTimestamp');

        // Return synced developers
        final List<Map<String, dynamic>> syncedDevelopers =
            await developerDatabase.getAllDevelopers();
        return syncedDevelopers.map((data) {
          final developerJson = json.decode(data['data']);
          return Developer.fromJson(developerJson);
        }).toList();
      } else {
        print('Failed to load developers: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Return existing developers from database on error
        final DeveloperDatabase developerDatabase = DeveloperDatabase();
        final List<Map<String, dynamic>> rawDevelopers =
            await developerDatabase.getAllDevelopers();
        return rawDevelopers.map((data) {
          final developerJson = json.decode(data['data']);
          return Developer.fromJson(developerJson);
        }).toList();
      }
    } catch (e) {
      print('Error during developer sync: $e');
      // Return existing developers from database on error
      final DeveloperDatabase developerDatabase = DeveloperDatabase();
      final List<Map<String, dynamic>> rawDevelopers =
          await developerDatabase.getAllDevelopers();
      return rawDevelopers.map((data) {
        final developerJson = json.decode(data['data']);
        return Developer.fromJson(developerJson);
      }).toList();
    }
  }

  // Fetch all developers from local database
  static Future<List<Developer>> fetchDevelopers({bool forceRefresh = false}) async {
    try {
      // First, attempt to sync from API if needed
      if (forceRefresh) {
        return await syncDevelopers(forceRefresh: true);
      }

      // Load developers from local database
      final DeveloperDatabase developerDatabase = DeveloperDatabase();
      final List<Map<String, dynamic>> rawDevelopers =
          await developerDatabase.getAllDevelopers();

      if (rawDevelopers.isEmpty) {
        print('No developers in local database, syncing from API...');
        return await syncDevelopers();
      }

      final developers = rawDevelopers.map((data) {
        final developerJson = json.decode(data['data']);
        return Developer.fromJson(developerJson);
      }).toList();

      _developersCache = developers;
      _developersLastFetch = DateTime.now();
      print('Loaded ${developers.length} developers from local database');
      return developers;
    } catch (e) {
      print('❌ General exception caught while fetching developers: $e');
      return [];
    }
  }

  // Fetch a single developer by ID
  static Future<Developer?> fetchDeveloperById(String developerId) async {
    try {
      print('🔍 Fetching developer by ID: $developerId');
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/resource/Developer/$developerId'),
            headers: {'Content-Type': 'application/json'},
          )
          .timeout(const Duration(seconds: 10));

      if (AuthService.checkResponse(response)) return null;

      print('✅ Developer by ID response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        print('📊 Developer by ID JSON data: $jsonData');
        return Developer.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        print('❌ Developer not found with ID: $developerId');
        return null;
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e) {
      print('❌ General exception caught: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timeout: Server is taking too long to respond',
        );
      }
      throw Exception('Error fetching developer by ID: $e');
    }
  }


}