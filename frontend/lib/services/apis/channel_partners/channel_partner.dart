import 'dart:convert';
import 'package:Homesol/models/channel_partner.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/channel_partner_database.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ChannelPartnerService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_channel_partners";

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  // Sync channel partners from API and store in local database
  static Future<List<ChannelPartner>> syncChannelPartners({bool forceRefresh = false}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (forceRefresh) {
      await prefs.remove(_lastSyncTimestampKey);
    }

    final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
    final List<Map<String, dynamic>> localPartnersRaw = await partnerDb.getAllChannelPartners();
    final bool isInitialSync = localPartnersRaw.isEmpty;

    String lastSyncTimestamp =
        prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";

    print('Syncing channel partners. Initial sync: $isInitialSync, Force refresh: $forceRefresh, Last sync: $lastSyncTimestamp');

    // If it's initial sync or force refresh, we fetch everything without filters
    String filtersParam = "";
    if (!isInitialSync && !forceRefresh) {
      final String filters = json.encode([
        ["modified", ">", lastSyncTimestamp]
      ]);
      filtersParam = "&filters=${Uri.encodeQueryComponent(filters)}";
    }

    final Uri uri = Uri.parse(
        '$baseUrl/api/resource/Channel%20Partner?fields=["name"]$filtersParam&limit_page_length=none');
    print('Requesting URL: $uri');

    try {
      final headers = await _getHeaders();
      final response = await http
          .get(uri, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> items = responseBody['data'] ?? [];

        // Step 1: Get all local Channel Partner IDs
        final Set<String> localPartnerNames = localPartnersRaw.map((e) => e['name'].toString()).toSet();

        // Step 2: Get all active server Channel Partner IDs
        final List<String> serverPartnerNamesList = await fetchChannelPartnerNamesFromServer();
        final Set<String> serverPartnerNames = serverPartnerNamesList.toSet();

        print('Local partners: ${localPartnerNames.length}, Server partners: ${serverPartnerNames.length}, New/Modified items: ${items.length}');
        
        // Step 3: Identify partners to delete locally
        final List<String> partnersToDelete = localPartnerNames
            .where((name) => !serverPartnerNames.contains(name))
            .toList();

        // Step 4: Delete identified partners from local database
        for (final partnerName in partnersToDelete) {
          await partnerDb.deleteChannelPartner(partnerName);
          print('Deleted local channel partner: $partnerName (no longer on server)');
        }

        if (items.isEmpty && !isInitialSync && !forceRefresh) {
          print('No new channel partners to sync.');
          // Return existing partners from database (after potential deletions)
          final List<Map<String, dynamic>> rawPartners =
              await partnerDb.getAllChannelPartners();
          return rawPartners.map((data) {
            final partnerJson = json.decode(data['data']);
            return ChannelPartner.fromJson(partnerJson);
          }).toList();
        }

        DateTime latestModifiedDate;
        try {
          String isoTimestamp = lastSyncTimestamp.replaceAll(' ', 'T');
          if (!isoTimestamp.contains('Z') && !isoTimestamp.contains('+')) {
            isoTimestamp += 'Z';
          }
          latestModifiedDate = DateTime.parse(isoTimestamp);
        } catch (e) {
          print('Error parsing lastSyncTimestamp: $e');
          latestModifiedDate = DateTime.parse("2000-01-01T00:00:00Z");
        }

        // Fetch full details for each channel partner
        final List<Future<ChannelPartner>> futures = [];
        for (final item in items) {
          futures.add(fetchChannelPartner(item['name']));
        }

        if (futures.isEmpty && isInitialSync && serverPartnerNames.isNotEmpty) {
           // Fallback: If for some reason items is empty but server has partners during initial sync
           print('Fallback: Fetching all server partners individually');
           for (final name in serverPartnerNames) {
             futures.add(fetchChannelPartner(name));
           }
        }

        List<ChannelPartner> partners;
        try {
          partners = await Future.wait(futures);
        } catch (e) {
          print('Error fetching channel partner details: $e');
          // Return existing partners from database on error
          final List<Map<String, dynamic>> rawPartners =
              await partnerDb.getAllChannelPartners();
          return rawPartners.map((data) {
            final partnerJson = json.decode(data['data']);
            return ChannelPartner.fromJson(partnerJson);
          }).toList();
        }

        // Upsert each partner
        for (var partner in partners) {
          final Map<String, dynamic> partnerMap = {
            'name': partner.name,
            'modified': partner.modified?.toIso8601String() ?? '',
            ...partner.toJson(),
          };
          await partnerDb.upsertChannelPartner(partnerMap);

          if (partner.modified != null && partner.modified!.isAfter(latestModifiedDate)) {
            latestModifiedDate = partner.modified!;
          }
        }

        // Save the new latest modified timestamp
        String formattedTimestamp = latestModifiedDate.toIso8601String();
        formattedTimestamp = formattedTimestamp.replaceAll('T', ' ').replaceAll('Z', '');
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
          formattedTimestamp = '$formattedTimestamp.000000';
        }
        final String newLastSyncTimestamp = formattedTimestamp;
        await prefs.setString(_lastSyncTimestampKey, newLastSyncTimestamp);
        print('Channel partners synced successfully. New last sync timestamp: $newLastSyncTimestamp');

        // After sync, return ALL partners from local DB to ensure we have the full list
        final List<Map<String, dynamic>> allRawPartners = await partnerDb.getAllChannelPartners();
        return allRawPartners.map((data) {
          final partnerJson = json.decode(data['data']);
          return ChannelPartner.fromJson(partnerJson);
        }).toList();
      } else {
        print('Failed to load channel partners: ${response.statusCode}');
        print('Response body: ${response.body}');
        // Return existing partners from database on error
        final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
        final List<Map<String, dynamic>> rawPartners =
            await partnerDb.getAllChannelPartners();
        return rawPartners.map((data) {
          final partnerJson = json.decode(data['data']);
          return ChannelPartner.fromJson(partnerJson);
        }).toList();
      }
    } catch (e) {
      print('Error during channel partner sync: $e');
      // Return existing partners from database on error
      final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
      final List<Map<String, dynamic>> rawPartners =
          await partnerDb.getAllChannelPartners();
      return rawPartners.map((data) {
        final partnerJson = json.decode(data['data']);
        return ChannelPartner.fromJson(partnerJson);
      }).toList();
    }
  }

  static Future<List<String>> fetchChannelPartnerNamesFromServer() async {
    try {
      final headers = await _getHeaders();
      final response = await http.get(
        Uri.parse(
          '${AuthService.baseUrl}/api/resource/Channel%20Partner?fields=["name"]&limit_page_length=none',
        ),
        headers: headers,
      );
      // print("Channel Partners names response: ${response.body}"); // Debugging

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          return items.map((item) => item['name'].toString()).toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching channel partner names from server: $e');
      return [];
    }
  }

  static Future<List<ChannelPartner>> fetchAllChannelPartners({
    bool forceRefresh = false,
  }) async {
    try {
      // First, attempt to sync from API if needed
      if (forceRefresh) {
        return await syncChannelPartners(forceRefresh: true);
      }

      // Load channel partners from local database
      final ChannelPartnerDatabase partnerDb = ChannelPartnerDatabase();
      final List<Map<String, dynamic>> rawPartners =
          await partnerDb.getAllChannelPartners();

      if (rawPartners.isEmpty) {
        print('No channel partners in local database, syncing from API...');
        return await syncChannelPartners();
      }

      final partners = rawPartners.map((data) {
        final partnerJson = json.decode(data['data']);
        return ChannelPartner.fromJson(partnerJson);
      }).toList();

      print('Loaded ${partners.length} channel partners from local database');
      return partners;
    } catch (e) {
      print('Error fetching all channel partners: $e');
      return [];
    }
  }

  static Future<ChannelPartner> fetchChannelPartner(String partnerId) async {
    try {
      final headers = await _getHeaders();
      final encodedPartnerId = Uri.encodeComponent(partnerId);
      final response = await http.get(
        Uri.parse(
          '${AuthService.baseUrl}/api/resource/Channel%20Partner/$encodedPartnerId',
        ),
        headers: headers,
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data.containsKey('data')) {
          return ChannelPartner.fromJson(data['data']);
        }
      }
      print(
        'Error fetching channel partner: ${response.statusCode} ${response.body}',
      );
      throw Exception('Failed to load channel partner');
    } catch (e) {
      print('Error fetching channel partner: $e');
      throw e;
    }
  }

  static Future<String?> createChannelPartner(Map<String, dynamic> body) async {
    final headers = await _getHeaders();
    final url = Uri.parse(
      '${AuthService.baseUrl}/api/resource/Channel%20Partner',
    );
    final response = await http.post(
      url,
      headers: headers,
      body: jsonEncode(body),
    );
    if (response.statusCode == 200 || response.statusCode == 201) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      return responseData['data']['name'] as String?;
    } else {
      print(
        'Create Channel Partner failed: ${response.statusCode} - ${response.body}',
      );
      return null;
    }
  }

  static Future<bool> updateChannelPartner(Map<String, dynamic> body) async {
    try {
      final headers = await _getHeaders();
      final name = body['name']; // Assuming the name (ID) is in the body
      final url = Uri.parse(
        '${AuthService.baseUrl}/api/resource/Channel%20Partner/$name',
      );
      final response = await http.put(
        url,
        headers: headers,
        body: jsonEncode(body),
      );
      if (response.statusCode == 200) {
        return true;
      } else {
        print(
          'Update Channel Partner failed: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('Error updating Channel Partner: $e');
      return false;
    }
  }
}
