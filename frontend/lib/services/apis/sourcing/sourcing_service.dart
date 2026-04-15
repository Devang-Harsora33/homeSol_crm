import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth_service.dart';
import '../../../models/sourcing.dart';
import 'package:Homesol/services/databases/sourcing_database.dart';
import 'package:Homesol/services/connectivity_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SourcingService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_sourcing";
  static const String _lastSyncTimestampDeveloperKey = "last_sync_timestamp_sourcing_developer_";

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  static Future<List<Sourcing>> getSourcingByDeveloper(String developerId, {bool forceRefresh = false}) async {
    try {
      final SourcingDatabase sourcingDb = SourcingDatabase();
      
      if (!forceRefresh || !ConnectivityService.isOnline) {
        final List<Map<String, dynamic>> localData = await sourcingDb.getAllSourcing();
        if (localData.isNotEmpty) {
          // Filtering might be needed if multiple developers' data could be in the DB
          // but for now we'll assume the DB contains the relevant sourcing for the current user.
          return localData.map((data) {
            final sourcingJson = json.decode(data['data']);
            return Sourcing.fromJson(sourcingJson);
          }).toList();
        }
      }

      if (ConnectivityService.isOnline) {
        await syncSourcingByDeveloper(developerId);
      }
      
      final List<Map<String, dynamic>> refreshedData = await sourcingDb.getAllSourcing();
      return refreshedData.map((data) {
        final sourcingJson = json.decode(data['data']);
        return Sourcing.fromJson(sourcingJson);
      }).toList();

    } catch (e) {
      print('Exception in getSourcingByDeveloper: $e');
      return [];
    }
  }

  static Future<List<Sourcing>> getMySources({bool forceRefresh = false}) async {
    try {
      final SourcingDatabase sourcingDb = SourcingDatabase();
      
      if (!forceRefresh || !ConnectivityService.isOnline) {
        final List<Map<String, dynamic>> localData = await sourcingDb.getAllSourcing();
        if (localData.isNotEmpty) {
          return localData.map((data) {
            final sourcingJson = json.decode(data['data']);
            return Sourcing.fromJson(sourcingJson);
          }).toList();
        }
      }

      if (ConnectivityService.isOnline) {
        await syncMySources();
      }
      
      final List<Map<String, dynamic>> refreshedData = await sourcingDb.getAllSourcing();
      return refreshedData.map((data) {
        final sourcingJson = json.decode(data['data']);
        return Sourcing.fromJson(sourcingJson);
      }).toList();

    } catch (e) {
      print('Exception in getMySources: $e');
      return [];
    }
  }

  static Future<List<Sourcing>> fetchAllSources() async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/method/homesol_app.api.get_my_sources'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => Sourcing.fromJson(json)).toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<void> syncSourcingByDeveloper(String developerId) async {
    if (!ConnectivityService.isOnline) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String syncKey = "$_lastSyncTimestampDeveloperKey$developerId";
      String lastSyncTimestamp = prefs.getString(syncKey) ?? "2000-01-01 00:00:00";
      
      final Uri uri = Uri.parse('$baseUrl/api/method/homesol_app.api.get_sourcing_by_developer?developer_id=$developerId');
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> message = responseData['message'] ?? [];
        final SourcingDatabase sourcingDb = SourcingDatabase();

        // For property developer, we might want to clear local cache if it's the first time 
        // or just upsert. Given the requirements, upserting is safer.
        // If we want to support deletion sync, we'd need another API or a different approach.

        DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp.contains(' ') ? lastSyncTimestamp.replaceAll(' ', 'T') + 'Z' : lastSyncTimestamp + 'T00:00:00Z');

        for (var sourceJson in message) {
          if (sourceJson is Map<String, dynamic>) {
            await sourcingDb.upsertSourcing(sourceJson);
            if (sourceJson.containsKey('modified') && sourceJson['modified'] != null) {
              final currentModified = DateTime.parse(sourceJson['modified'].toString().replaceAll(' ', 'T') + 'Z');
              if (currentModified.isAfter(latestModifiedDate)) {
                latestModifiedDate = currentModified;
              }
            }
          }
        }
        
        String formattedTimestamp = latestModifiedDate.toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');
        List<String> parts = formattedTimestamp.split('.');
        if (parts.length > 1) {
          String microseconds = parts[1].padRight(6, '0').substring(0, 6);
          formattedTimestamp = '${parts[0]}.$microseconds';
        } else {
          formattedTimestamp = '$formattedTimestamp.000000';
        }
        await prefs.setString(syncKey, formattedTimestamp);
      }
    } catch (e) {
      print('Error in syncSourcingByDeveloper: $e');
    }
  }

  static Future<void> syncMySources() async {
    if (!ConnectivityService.isOnline) return;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      String lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";
      
      final String filters = json.encode([["modified", ">", lastSyncTimestamp]]);
      final Uri uri = Uri.parse('$baseUrl/api/method/homesol_app.api.get_my_sources?filters=$filters');
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> message = responseData['message'] ?? [];
        final SourcingDatabase sourcingDb = SourcingDatabase();

        // Deletion Logic
        final List<Sourcing> serverSources = await fetchAllSources();
        if (serverSources.isNotEmpty) {
          final Set<String> serverSourceNames = serverSources.map((e) => e.name).whereType<String>().toSet();
          final List<Map<String, dynamic>> localSourcesRaw = await sourcingDb.getAllSourcing();
          for (final localS in localSourcesRaw) {
            final name = localS['name'].toString();
            if (!serverSourceNames.contains(name)) {
              await sourcingDb.deleteSourcing(name);
            }
          }
        }

        DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp.contains(' ') ? lastSyncTimestamp.replaceAll(' ', 'T') + 'Z' : lastSyncTimestamp + 'T00:00:00Z');

        for (var sourceJson in message) {
          if (sourceJson is Map<String, dynamic>) {
            await sourcingDb.upsertSourcing(sourceJson);
            if (sourceJson.containsKey('modified') && sourceJson['modified'] != null) {
              final currentModified = DateTime.parse(sourceJson['modified'].toString().replaceAll(' ', 'T') + 'Z');
              if (currentModified.isAfter(latestModifiedDate)) {
                latestModifiedDate = currentModified;
              }
            }
          }
        }
        
        String formattedTimestamp = latestModifiedDate.toIso8601String().replaceAll('T', ' ').replaceAll('Z', '');
        List<String> parts = formattedTimestamp.split('.');
        if (parts.length > 1) {
          String microseconds = parts[1].padRight(6, '0').substring(0, 6);
          formattedTimestamp = '${parts[0]}.$microseconds';
        } else {
          formattedTimestamp = '$formattedTimestamp.000000';
        }
        await prefs.setString(_lastSyncTimestampKey, formattedTimestamp);
      }
    } catch (_) {}
  }

  static Future<void> clearAllCaches() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncTimestampKey);
    await SourcingDatabase().deleteAllSourcing();
  }

  static Future<Sourcing?> getSourcingDetail(String name) async {
    // Check local first
    final SourcingDatabase sourcingDb = SourcingDatabase();
    final localData = await sourcingDb.getAllSourcing();
    try {
      final match = localData.firstWhere((d) => d['name'] == name);
      return Sourcing.fromJson(json.decode(match['data']));
    } catch (_) {}

    if (!ConnectivityService.isOnline) return null;

    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service/$name'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final sourcing = Sourcing.fromJson(responseData['data']);
        await sourcingDb.upsertSourcing(responseData['data']);
        return sourcing;
      }
    } catch (_) {}
    return null;
  }

  static Future<Sourcing?> createSourcing(Sourcing sourcing) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service'),
        headers: headers,
        body: jsonEncode(sourcing.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return Sourcing.fromJson(responseData['data']);
      }
    } catch (_) {}
    return null;
  }

  static Future<Sourcing?> updateSourcing(Sourcing sourcing) async {
    if (sourcing.name == null || !ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service/${sourcing.name}'),
        headers: headers,
        body: jsonEncode(sourcing.toJson()),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        return Sourcing.fromJson(responseData['data']);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> deleteSourcing(String name) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service/$name'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));
      return response.statusCode == 202 || response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<bool> updateDocStatus(String name, int status) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service/$name'),
        headers: headers,
        body: jsonEncode({'docstatus': status}),
      ).timeout(const Duration(seconds: 20));
      return response.statusCode == 200;
    } catch (_) {}
    return false;
  }

  static Future<Map<String, dynamic>?> triggerOtp(String mobileNumber) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/method/homesol_app.api.trigger_otp_sales_service'),
        headers: headers,
        body: jsonEncode({'mobile_number': mobileNumber}),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> verifyOtp(String mobileNumber, String otp) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/api/method/homesol_app.api.verify_otp_sales_service'),
        headers: headers,
        body: jsonEncode({
          'mobile_number': mobileNumber,
          'user_otp': otp,
        }),
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] == 'OTP Verified' || data['message'] == true || (data['message'] is Map && data['message']['status'] == 'success');
      }
    } catch (_) {}
    return false;
  }
}
