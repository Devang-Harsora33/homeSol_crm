import 'dart:convert';
import 'package:Homesol/models/site_visit.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/site_visit_database.dart';
import 'package:Homesol/services/connectivity_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class SiteVisitService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_site_visits";

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  // Helper to fetch all site visit names from server for deletion comparison
  static Future<List<String>> fetchSiteVisitNamesFromServer() async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_all_site_visits');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<List<SiteVisit>> fetchSiteVisits({bool forceRefresh = false}) async {
    try {
      final cachedSiteVisits = await SiteVisitDatabase.getAllSiteVisits();
      if (cachedSiteVisits.isNotEmpty && (!forceRefresh || !ConnectivityService.isOnline)) {
        return cachedSiteVisits;
      }
    } catch (_) {}

    if (ConnectivityService.isOnline) {
      return await _syncSiteVisits(forceRefresh: forceRefresh);
    }
    return await SiteVisitDatabase.getAllSiteVisits();
  }

  static Future<List<SiteVisit>> _syncSiteVisits({bool forceRefresh = false}) async {
    if (!ConnectivityService.isOnline) return await SiteVisitDatabase.getAllSiteVisits();
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey);
      final headers = await _getHeaders();

      final response = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_all_site_visits'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // Deletion
        final List<String> serverSiteVisitNamesList = await fetchSiteVisitNamesFromServer();
        if (serverSiteVisitNamesList.isNotEmpty) {
          final Set<String> serverSiteVisitNames = serverSiteVisitNamesList.toSet();
          final List<SiteVisit> localSiteVisits = await SiteVisitDatabase.getAllSiteVisits();
          for (final sv in localSiteVisits) {
            if (!serverSiteVisitNames.contains(sv.name)) {
              await SiteVisitDatabase.deleteSiteVisit(sv.name);
            }
          }
        }

        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        final visits = jsonData.map((json) => SiteVisit.fromJson(json)).toList();

        for (final visit in visits) {
          await SiteVisitDatabase.upsertSiteVisit(visit);
        }

        final now = DateTime.now();
        final formattedTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
        await prefs.setString(_lastSyncTimestampKey, formattedTimestamp);

        return visits;
      }
    } catch (_) {}
    return await SiteVisitDatabase.getAllSiteVisits();
  }

  static Future<String?> createSiteVisit(Map<String, dynamic> body) async {
    if (!ConnectivityService.isOnline) return 'Internet connection required to create a site visit.';
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('${AuthService.baseUrl}/api/resource/Site%20Visit');
      final response = await http.post(url, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        if (responseData.containsKey('message')) {
          final message = responseData['message'];
          if (message is String && message.toLowerCase().contains('error')) return message;
        }
        return null;
      }
      return 'Failed to create site visit. Status: ${response.statusCode}';
    } catch (e) {
      return 'An error occurred: $e';
    }
  }

  static Future<List<SiteVisit>> fetchMySiteVisits({bool forceRefresh = false}) async {
    try {
      final cachedSiteVisits = await SiteVisitDatabase.getAllSiteVisits();
      if (cachedSiteVisits.isNotEmpty && (!forceRefresh || !ConnectivityService.isOnline)) return cachedSiteVisits;
    } catch (_) {}
    return await _syncMySiteVisits(forceRefresh: forceRefresh);
  }

  static Future<List<SiteVisit>> fetchDeveloperSiteVisits(String developerId, {bool forceRefresh = false}) async {
    try {
      final cachedSiteVisits = await SiteVisitDatabase.getAllSiteVisits();
      if (cachedSiteVisits.isNotEmpty && (!forceRefresh || !ConnectivityService.isOnline)) return cachedSiteVisits;
    } catch (_) {}
    return await _syncDeveloperSiteVisits(developerId, forceRefresh: forceRefresh);
  }

  static Future<List<SiteVisit>> _syncDeveloperSiteVisits(String developerId, {bool forceRefresh = false}) async {
    if (!ConnectivityService.isOnline) return await SiteVisitDatabase.getAllSiteVisits();
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey);

      String url = '${AuthService.baseUrl}/api/method/homesol_app.api.get_site_visits_by_developer?developer_id=$developerId';
      if (lastSyncTimestamp != null && !forceRefresh) {
        final filters = jsonEncode([["modified", ">", lastSyncTimestamp]]);
        url += '&filters=${Uri.encodeComponent(filters)}';
      }

      final response = await http.get(Uri.parse(url), headers: await _getHeaders()).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData.containsKey('message') && responseData['message'] is List) {
          final List<dynamic> jsonData = responseData['message'];
          final siteVisits = jsonData.map((json) => SiteVisit.fromJson(json)).toList();
          for (final siteVisit in siteVisits) await SiteVisitDatabase.upsertSiteVisit(siteVisit);
          final now = DateTime.now();
          final formattedTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
          await prefs.setString(_lastSyncTimestampKey, formattedTimestamp);
          return siteVisits;
        }
      }
    } catch (_) {}
    return await SiteVisitDatabase.getAllSiteVisits();
  }

  static Future<List<SiteVisit>> _syncMySiteVisits({bool forceRefresh = false}) async {
    if (!ConnectivityService.isOnline) return await SiteVisitDatabase.getAllSiteVisits();
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey);
      final uri = Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_team_site_visits');
      final headers = await _getHeaders();
      final Map<String, dynamic> filters = {};
      if (lastSyncTimestamp != null && !forceRefresh) filters['filters'] = [["modified", ">", lastSyncTimestamp]];

      final response = await http.post(uri, headers: headers, body: filters.isNotEmpty ? jsonEncode(filters) : null).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        if (responseData.containsKey('message') && responseData['message'] is List) {
          final List<dynamic> jsonData = responseData['message'];
          final siteVisits = jsonData.map((json) => SiteVisit.fromJson(json)).toList();
          for (final siteVisit in siteVisits) await SiteVisitDatabase.upsertSiteVisit(siteVisit);
          final now = DateTime.now();
          final formattedTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
          await prefs.setString(_lastSyncTimestampKey, formattedTimestamp);
          return siteVisits;
        }
      }
    } catch (_) {}
    return await SiteVisitDatabase.getAllSiteVisits();
  }
}
