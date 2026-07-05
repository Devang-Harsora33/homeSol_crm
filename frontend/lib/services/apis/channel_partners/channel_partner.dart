import 'dart:convert';
import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/channel_partner_database.dart';
import 'package:Homesol/services/connectivity_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:intl/intl.dart';
import '../../../models/cp_connections.dart';

class ChannelPartnerService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_channel_partners";

  static Future<bool> recordButtonPress(String partnerId, String buttonName) async {
    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      final userData = await AuthService.getUserData();
      final pressedBy = userData?['email'] ?? 'Unknown';

      final newRecord = {
        "date_and_time": formattedDate,
        "button_pressed": buttonName,
        "pressed_by": pressedBy,
        "doctype": "Button Pressed Logs CP"
      };

      // Fetch existing partner data from local DB
      final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
      final localPartner = await partnerDb.getChannelPartnerByName(partnerId);
      List<dynamic> existingRecords = [];
      
      if (localPartner != null) {
        if (localPartner.containsKey('button_logs')) {
          existingRecords = List.from(localPartner['button_logs'] ?? []);
        }
      }
      
      // Append the new record
      existingRecords.add(newRecord);

      final body = {
        "button_logs": existingRecords
      };

      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$baseUrl/api/resource/Channel%20Partner/$partnerId'),
        headers: headers,
        body: json.encode(body)
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        // Update local DB
        final Map<String, dynamic> updatedData = Map.from(localPartner ?? {});
        updatedData['button_logs'] = existingRecords;
        await partnerDb.upsertChannelPartner(updatedData);
        return true;
      }
      return false;
    } catch (e) {
      print('Error recording button press for Channel Partner: $e');
      return false;
    }
  }

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  // Sync channel partners from API and store in local database
  static Future<List<ChannelPartner>> syncChannelPartners({bool forceRefresh = false}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (forceRefresh) await prefs.remove(_lastSyncTimestampKey);

    final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
    final List<Map<String, dynamic>> localPartnersRaw = await partnerDb.getAllChannelPartners();

    if (!ConnectivityService.isOnline) {
      return localPartnersRaw.map((data) => ChannelPartner.fromJson(json.decode(data['data']))).toList();
    }

    final bool isInitialSync = localPartnersRaw.isEmpty;
    String lastSyncTimestamp = prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";

    String filtersParam = "";
    if (!isInitialSync && !forceRefresh) {
      final String filters = json.encode([["modified", ">", lastSyncTimestamp]]);
      filtersParam = "&filters=${Uri.encodeQueryComponent(filters)}";
    }

    final Uri uri = Uri.parse('$baseUrl/api/resource/Channel%20Partner?fields=["name"]$filtersParam&limit_page_length=none');

    try {
      final headers = await _getHeaders();
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> items = responseBody['data'] ?? [];

        // Deletion check
        final List<String> serverPartnerNamesList = await fetchChannelPartnerNamesFromServer();
        if (serverPartnerNamesList.isNotEmpty) {
          final Set<String> serverPartnerNames = serverPartnerNamesList.toSet();
          final Set<String> localPartnerNames = localPartnersRaw.map((e) => e['name'].toString()).toSet();
          for (final partnerName in localPartnerNames) {
            if (!serverPartnerNames.contains(partnerName)) await partnerDb.deleteChannelPartner(partnerName);
          }
        }

        if (items.isEmpty && !isInitialSync && !forceRefresh) {
          final List<Map<String, dynamic>> rawPartners = await partnerDb.getAllChannelPartners();
          return rawPartners.map((data) => ChannelPartner.fromJson(json.decode(data['data']))).toList();
        }

        // Fix: Removed 'Z' to avoid UTC conversion if server uses local time
        DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp.contains(' ') ? lastSyncTimestamp.replaceAll(' ', 'T') : lastSyncTimestamp + 'T00:00:00');

        final List<Future<ChannelPartner>> futures = [];
        for (final item in items) {
          futures.add(fetchChannelPartner(item['name'], forceRefresh: true));
        }

        List<ChannelPartner> partners = await Future.wait(futures);

        for (var partner in partners) {
          final Map<String, dynamic> partnerMap = {'name': partner.name, 'modified': partner.modified?.toIso8601String() ?? '', ...partner.toJson()};
          await partnerDb.upsertChannelPartner(partnerMap);
          if (partner.modified != null && partner.modified!.isAfter(latestModifiedDate)) latestModifiedDate = partner.modified!;
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
        
        final List<Map<String, dynamic>> allRawPartners = await partnerDb.getAllChannelPartners();
        return allRawPartners.map((data) => ChannelPartner.fromJson(json.decode(data['data']))).toList();
      }
    } catch (e) {
      print('Error during channel partner sync: $e');
    }
    
    final List<Map<String, dynamic>> rawPartners = await partnerDb.getAllChannelPartners();
    return rawPartners.map((data) => ChannelPartner.fromJson(json.decode(data['data']))).toList();
  }

  static Future<List<String>> fetchChannelPartnerNamesFromServer() async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/api/resource/Channel%20Partner?fields=["name"]&limit_page_length=none'), headers: headers).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          return items.map((item) => item['name'].toString()).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<List<ChannelPartner>> fetchAllChannelPartners({bool forceRefresh = false}) async {
    if (ConnectivityService.isOnline) {
      return await syncChannelPartners(forceRefresh: forceRefresh);
    }
    
    final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
    final List<Map<String, dynamic>> rawPartners = await partnerDb.getAllChannelPartners();
    return rawPartners.map((data) => ChannelPartner.fromJson(json.decode(data['data']))).toList();
  }

  static Future<ChannelPartner> fetchChannelPartner(String partnerId, {bool forceRefresh = false}) async {
    // Check local first if not forcing refresh
    final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
    if (!forceRefresh) {
      final localPartner = await partnerDb.getChannelPartnerByName(partnerId);
      if (localPartner != null) return ChannelPartner.fromJson(localPartner);
    }

    if (!ConnectivityService.isOnline) {
      if (!forceRefresh) {
        throw Exception('Internet connection required.');
      } else {
        // If forcing refresh but offline, try local as fallback
        final localPartner = await partnerDb.getChannelPartnerByName(partnerId);
        if (localPartner != null) return ChannelPartner.fromJson(localPartner);
        throw Exception('Offline and no local data found.');
      }
    }

    try {
      final headers = await _getHeaders();
      final response = await http.get(Uri.parse('$baseUrl/api/resource/Channel%20Partner/${Uri.encodeComponent(partnerId)}'), headers: headers).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final partner = ChannelPartner.fromJson(data['data']);
        // Store in local DB
        await partnerDb.upsertChannelPartner(data['data']);
        return partner;
      }
      throw Exception('Failed to load channel partner from server');
    } catch (e) {
      print('Error fetching channel partner: $e');
      throw e;
    }
  }

  static Future<ChannelPartner?> createChannelPartner(Map<String, dynamic> body) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final response = await http.post(Uri.parse('$baseUrl/api/resource/Channel%20Partner'), headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final partner = ChannelPartner.fromJson(responseData['data']);
        // Save to local database
        final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
        await partnerDb.upsertChannelPartner(responseData['data']);
        return partner;
      }
    } catch (e) {
      print('❌ Create Channel Partner error: $e');
    }
    return null;
  }

  static Future<ChannelPartner?> updateChannelPartner(Map<String, dynamic> body) async {
    if (!ConnectivityService.isOnline) {
      print('❌ Update Channel Partner failed: No internet connection');
      return null;
    }
    try {
      final headers = await _getHeaders();
      final name = body['name'];
      final url = '$baseUrl/api/resource/Channel%20Partner/$name';
      final jsonBody = jsonEncode(body);
      
      final response = await http.put(
        Uri.parse(url), 
        headers: headers, 
        body: jsonBody
      ).timeout(const Duration(seconds: 30));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final partner = ChannelPartner.fromJson(responseData['data']);
        // Save to local database
        final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
        await partnerDb.upsertChannelPartner(responseData['data']);
        return partner;
      } else {
        print('❌ Update Channel Partner failed. Status: ${response.statusCode}, Body: ${response.body}');
        throw Exception('Failed to update: ${response.body}');
      }
    } catch (e) {
      print('❌ Update Channel Partner error: $e');
      throw e;
    }
  }

  static Future<List<Map<String, dynamic>>> fetchSiteVisitsByChannelPartner(String partnerId) async {
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/method/homesol_app.api.crm.get_site_visits_by_channel_partner?partner_id=$partnerId');
      
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['message'] != null) {
          return List<Map<String, dynamic>>.from(data['message']);
        }
      }
      return [];
    } catch (e) {
      print('Error fetching site visits for channel partner: $e');
      return [];
    }
  }

  static Future<CPConnections?> fetchCPConnections(String cpName) async {
    if (!ConnectivityService.isOnline) return null;
    try {
      final headers = await _getHeaders();
      final url = Uri.parse('$baseUrl/api/method/homesol_app.api.get_cp_connections?cp_name=${Uri.encodeComponent(cpName)}');
      
      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] != null && data['message']['data'] != null) {
          return CPConnections.fromJson(data['message']['data']);
        }
      }
    } catch (e) {
      print('Error fetching CP connections: $e');
    }
    return null;
  }
}
