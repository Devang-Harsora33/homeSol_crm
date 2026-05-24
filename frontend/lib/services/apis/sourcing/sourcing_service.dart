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

  static Future<Set<String>?> fetchAllSourceNames() async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      // Use resource API with limit_page_length=none to get ALL names for deletion sync
      final response = await http.get(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service?fields=["name"]&limit_page_length=none'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['data'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toSet();
      }
    } catch (e) {
      print('Error in fetchAllSourceNames: $e');
    }
    return null;
  }

  static Future<Set<String>?> fetchAllSourceNamesByDeveloper(String developerId) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      // Filters for developer - assuming interested_project or a similar field
      // We'll try to use the same logic as the custom API but via resource API for pagination safety
      final String filters = json.encode([["interested_project", "=", developerId]]);
      final response = await http.get(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service?fields=["name"]&filters=$filters&limit_page_length=none'),
        headers: headers,
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['data'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toSet();
      }
    } catch (e) {
      print('Error in fetchAllSourceNamesByDeveloper: $e');
    }
    return null;
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

        // Deletion Logic for Developer Sourcing
        final Set<String>? serverSourceNames = await fetchAllSourceNamesByDeveloper(developerId);
        if (serverSourceNames != null) {
          final List<Map<String, dynamic>> localSourcesRaw = await sourcingDb.getAllSourcing();
          
          for (final localS in localSourcesRaw) {
            final name = localS['name'].toString();
            if (!serverSourceNames.contains(name)) {
              await sourcingDb.deleteSourcing(name);
              print('Deleted local sourcing: $name (no longer on server for developer $developerId)');
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
        final Set<String>? serverSourceNames = await fetchAllSourceNames();
        if (serverSourceNames != null) {
          final List<Map<String, dynamic>> localSourcesRaw = await sourcingDb.getAllSourcing();
          for (final localS in localSourcesRaw) {
            final name = localS['name'].toString();
            if (!serverSourceNames.contains(name)) {
              await sourcingDb.deleteSourcing(name);
              print('Deleted local sourcing: $name (no longer on server)');
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
    } catch (e) {
      print('Error in syncMySources: $e');
    }
  }


  static Future<void> clearAllCaches() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncTimestampKey);
    await SourcingDatabase().deleteAllSourcing();
  }

  static Future<Sourcing?> getSourcingDetail(String name) async {
    final SourcingDatabase sourcingDb = SourcingDatabase();

    // Fetch from network first if online
    if (ConnectivityService.isOnline) {
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
      } catch (_) {
        // Silently fallback to local database on error
      }
    }

    // Fallback to local database
    try {
      final localData = await sourcingDb.getAllSourcing();
      final match = localData.firstWhere((d) => d['name'] == name);
      return Sourcing.fromJson(json.decode(match['data']));
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
        final newSourcing = Sourcing.fromJson(responseData['data']);
        await SourcingDatabase().upsertSourcing(responseData['data']);
        return newSourcing;
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
        final updatedSourcing = Sourcing.fromJson(responseData['data']);
        await SourcingDatabase().upsertSourcing(responseData['data']);
        return updatedSourcing;
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> updateSourcingFields(String name, Map<String, dynamic> fields) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service/$name'),
        headers: headers,
        body: jsonEncode(fields),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        await SourcingDatabase().upsertSourcing(responseData['data']);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<bool> deleteSourcing(String name) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service/$name'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 202 || response.statusCode == 200) {
        await SourcingDatabase().deleteSourcing(name);
        return true;
      }
    } catch (_) {}
    return false;
  }

  static Future<String?> updateDocStatus(String name, int status) async {
    if (!ConnectivityService.isOnline) return "Offline";
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/resource/Sales%20Fields%20Service/$name'),
        headers: headers,
        body: jsonEncode({'docstatus': status}),
      ).timeout(const Duration(seconds: 20));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        await SourcingDatabase().upsertSourcing(responseData['data']);
        return null;
      } else {
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['exc_type'] != null) {
            return "${errorData['exc_type']}: ${errorData['_server_messages'] ?? ''}";
          }
          return response.body;
        } catch (_) {
          return "Status ${response.statusCode}: ${response.body}";
        }
      }
    } catch (e) {
      return "Exception: $e";
    }
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
