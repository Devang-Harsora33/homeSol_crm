import 'dart:convert';
import 'package:Homesol/models/site_visit.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/site_visit_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';





class SiteVisitService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_site_visits";
  static List<SiteVisit>? _siteVisitsCache;
  static DateTime? _siteVisitsLastFetch;

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  // Helper to fetch all site visit names from server for deletion comparison
  static Future<List<String>> fetchSiteVisitNamesFromServer() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_all_site_visits',
      );

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toList();
      } else {
        print('❌ Error fetching all site visit names from server: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching all site visit names from server: $e');
      return [];
    }
  }

  static Future<List<SiteVisit>> fetchSiteVisits({bool forceRefresh = false}) async {
    // Load from local database first
    try {
      final cachedSiteVisits = await SiteVisitDatabase.getAllSiteVisits();
      if (cachedSiteVisits.isNotEmpty && !forceRefresh) {
        print('Returning cached site visits from database');
        return cachedSiteVisits;
      }
    } catch (e) {
      print('Error loading from database: $e');
    }

    // Sync from API if DB is empty or forceRefresh is true
    return await _syncSiteVisits(forceRefresh: forceRefresh);
  }

  static Future<List<SiteVisit>> _syncSiteVisits({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey);

      print('Fetching site visits from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_all_site_visits');
      final headers = await _getHeaders();

      // Build request body with timestamp filter
      final Map<String, dynamic> filters = {};
      if (lastSyncTimestamp != null && !forceRefresh) {
        filters['filters'] = [["modified", ">", lastSyncTimestamp]];
      }

      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.get_all_site_visits',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Site visits response status: ${response.statusCode}');
      print('Site visits response body: ${response.body}');

      if (response.statusCode == 200) {
        // --- Deletion Handling Start ---
        final SiteVisitDatabase siteVisitDatabase = SiteVisitDatabase();

        // Step 1: Get all local Site Visit IDs
        final List<SiteVisit> localSiteVisits = await SiteVisitDatabase.getAllSiteVisits();
        final Set<String> localSiteVisitNames = localSiteVisits.map((sv) => sv.name).toSet();

        // Step 2: Get all active server Site Visit IDs
        final List<String> serverSiteVisitNamesList = await fetchSiteVisitNamesFromServer();
        final Set<String> serverSiteVisitNames = serverSiteVisitNamesList.toSet();

        // Step 3: Identify site visits to delete locally
        final List<String> siteVisitsToDelete = localSiteVisitNames
            .where((name) => !serverSiteVisitNames.contains(name))
            .toList();

        // Step 4: Delete identified site visits from local database
        for (final siteVisitName in siteVisitsToDelete) {
          await SiteVisitDatabase.deleteSiteVisit(siteVisitName);
          print('Deleted local site visit: $siteVisitName (no longer on server)');
        }
        // --- Deletion Handling End ---

        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        print('Site visits JSON data: $jsonData');
        final visits = jsonData.map((json) => SiteVisit.fromJson(json)).toList();

        // Store in database
        for (final visit in visits) {
          await SiteVisitDatabase.upsertSiteVisit(visit);
        }

        // Update last sync timestamp
        final now = DateTime.now();
        final formattedTimestamp =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
        await prefs.setString(_lastSyncTimestampKey, formattedTimestamp);

        return visits;
      } else {
        print('❌ Site visits error: ${response.statusCode} - ${response.body}');
        return await SiteVisitDatabase.getAllSiteVisits();
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return await SiteVisitDatabase.getAllSiteVisits();
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return await SiteVisitDatabase.getAllSiteVisits();
    } catch (e) {
      print('❌ General exception caught: $e');
      return await SiteVisitDatabase.getAllSiteVisits();
    }
  }

  static Future<String?> createSiteVisit(Map<String, dynamic> body) async {
      try {
        final headers = await _getHeaders();
        final url = Uri.parse('${AuthService.baseUrl}/api/resource/Site%20Visit');
        final response = await http.post(
          url,
          headers: headers,
          body: jsonEncode(body),
        );

        print('Create Site Visit response status: ${response.statusCode}');
        print('Create Site Visit response body: ${response.body}');

        if (response.statusCode == 200) {
          final Map<String, dynamic> responseData = json.decode(response.body);
          if (responseData.containsKey('message')) {
            // Frappe often puts success/error details in 'message' field
            final message = responseData['message'];
            if (message is String && message.toLowerCase().contains('error')) {
              return message;
            }
          }
          // Assuming 200 with no explicit 'error' in message means success
          return null;
        } else {
          return 'Failed to create site visit. Status: ${response.statusCode} - ${response.body}';
        }
      } on http.ClientException catch (e) {
        print('❌ ClientException caught: $e');
        return 'Network error: $e';
      } on FormatException catch (e) {
        print('❌ FormatException caught: $e');
        return 'Invalid response format from server: $e';
      } catch (e) {
        print('❌ General exception caught: $e');
        return 'An unexpected error occurred: $e';
      }
    }

  static Future<List<SiteVisit>> fetchMySiteVisits({bool forceRefresh = false}) async {
    // Load from local database first
    try {
      final cachedSiteVisits = await SiteVisitDatabase.getAllSiteVisits();
      if (cachedSiteVisits.isNotEmpty && !forceRefresh) {
        print('Returning cached my site visits from database');
        return cachedSiteVisits;
      }
    } catch (e) {
      print('Error loading from database: $e');
    }

    // Sync from API if DB is empty or forceRefresh is true
    return await _syncMySiteVisits(forceRefresh: forceRefresh);
  }

  static Future<List<SiteVisit>> _syncMySiteVisits({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey);

      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_site_visits',
      );

      print('🔍 Syncing my site visits from: $uri');

      final headers = await _getHeaders();

      // Build request body with timestamp filter
      final Map<String, dynamic> filters = {};
      if (lastSyncTimestamp != null && !forceRefresh) {
        filters['filters'] = [["modified", ">", lastSyncTimestamp]];
      }

      final response = await http
          .post(
            uri,
            headers: headers,
            body: filters.isNotEmpty ? jsonEncode(filters) : null,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (responseData.containsKey('message') && responseData['message'] is List) {
          final List<dynamic> jsonData = responseData['message'];
          final siteVisits = jsonData.map((json) => SiteVisit.fromJson(json)).toList();

          // Store in database
          for (final siteVisit in siteVisits) {
            await SiteVisitDatabase.upsertSiteVisit(siteVisit);
          }

          // Update last sync timestamp
          final now = DateTime.now();
          final formattedTimestamp =
              '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
          await prefs.setString(_lastSyncTimestampKey, formattedTimestamp);

          return siteVisits;
        } else {
          return [];
        }
      } else {
        print('❌ Sync error: ${response.statusCode} - ${response.body}');
        // Return cached data on error
        return await SiteVisitDatabase.getAllSiteVisits();
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return await SiteVisitDatabase.getAllSiteVisits();
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return await SiteVisitDatabase.getAllSiteVisits();
    } catch (e) {
      print('❌ General exception caught: $e');
      return await SiteVisitDatabase.getAllSiteVisits();
    }
  }
  


}