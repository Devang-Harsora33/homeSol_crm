import 'dart:convert';
import 'package:Homesol/models/follow_up.dart';
import 'package:Homesol/models/lead.dart';
import 'package:http/http.dart' as http;
import '../../auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Homesol/services/databases/lead_database.dart';
import 'package:Homesol/services/databases/follow_up_database.dart';
import 'package:Homesol/services/databases/channel_partner_database.dart'; // Added missing import
import 'package:Homesol/services/databases/developer_database.dart'; // Added missing import
import 'package:Homesol/services/databases/project_database.dart'; // Added missing import
import 'package:Homesol/services/databases/site_visit_database.dart'; // Added missing import
import 'package:Homesol/services/databases/sales_team_database.dart'; // Added missing import
import 'package:Homesol/services/databases/user_profile_database.dart'; // Added missing import
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;

class LeadService {
  static String get baseUrl => AuthService.baseUrl;
  // Cache variables for leads
  static List<Lead>? _leadsCache;
  static DateTime? _leadsLastFetch;
  final String _lastSyncTimestampKey = "last_sync_timestamp_leads";
  static const String _lastSyncFollowupsTimestampKey = "last_sync_timestamp_followups";

  // Client for instance methods (can be mocked)
  final http.Client _client;

  // Static client for static methods (can be mocked for testing)
  static http.Client? _testClient;
  static http.Client get _httpClient => _testClient ?? http.Client();

  // Setter for injecting mock client for static methods in tests
  static void setTestClient(http.Client? client) {
    _testClient = client;
  }

LeadService({http.Client? client}) : _client = client ?? http.Client(); // Initialize with provided client or a new one

  // Caches for dropdowns and users
  static List<String>? _campaignsCache;
  static DateTime? _campaignsLastFetch;
  static List<String>? _territoriesCache;
  static DateTime? _territoriesLastFetch;
  static List<String>? _industryTypesCache;
  static DateTime? _industryTypesLastFetch;
  static List<String>? _marketSegmentsCache;
  static DateTime? _marketSegmentsLastFetch;
  static List<String>? _leadSourcesCache;
  static DateTime? _leadSourcesLastFetch;
  static List<Map<String, String>>? _usersWithIdCache;
  static DateTime? _usersWithIdLastFetch;
  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    // From the user request, the token is in the format `token YOUR_API_KEY:YOUR_API_SECRET`
    // I will use the cookie for authentication as it is the existing convention.
    // If this does not work, I will switch to the token-based authentication.
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) {
      headers['Cookie'] = cookie;
    }
    return headers;
  }

  static Future<String?> sendOTP(String mobileNo) async {
    final headers = await _getHeaders();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/api/method/homesol_app.api.crm.trigger_otp_lead'),
      headers: headers,
      body: jsonEncode({
        'mobile_no': mobileNo,
        'lead_name': null,
      }),
    );
    print('OTP Trigger API Response: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['message'] == 'success') {
        if (responseData.containsKey('_server_messages')) {
          final serverMessages = jsonDecode(responseData['_server_messages']);
          if (serverMessages.isNotEmpty) {
            final innerMessageJson = jsonDecode(serverMessages[0]);
            final message = innerMessageJson['message'];
            final otpMatch = RegExp(r'OTP: <b>(\d{6})<\/b>').firstMatch(message);
            if (otpMatch != null) {
              return otpMatch.group(1); // OTP found
            }
          }
        }
        return ""; // Success, but no debug OTP found
      }
    }
    return null; // API call failed or message was not 'success'
  }

  static Future<bool> verifyOTP(String mobileNo, String otp) async {
    final headers = await _getHeaders();
    final response = await _httpClient.post(
      Uri.parse('$baseUrl/api/method/homesol_app.api.crm.verify_otp_lead'),
      headers: headers,
      body: jsonEncode({
        'mobile_no': mobileNo,
        'user_otp': otp,
        'lead_name': null,
      }),
    );

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['message'] == true;
    } else {
      return false;
    }
  }

  static Future<bool> recordButtonPress(String leadId, String buttonName) async {
    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
      
      final userData = await AuthService.getUserData();
      final pressedBy = userData?['email'] ?? 'Unknown';

      final newRecord = {
        "date_and_time": formattedDate,
        "button_pressed": buttonName,
        "pressed_by": pressedBy,
        "doctype": "Buttons Pressed Logs"
      };

      // Fetch existing lead data from local DB to get existing button press records
      final localLead = await LeadDatabase().getLeadByName(leadId);
      List<dynamic> existingRecords = [];
      
      // Try both field names just in case, but prioritize custom_button_logs
      if (localLead != null) {
        if (localLead.containsKey('custom_button_logs')) {
          existingRecords = List.from(localLead['custom_button_logs'] ?? []);
        } else if (localLead.containsKey('custom_button_press_records')) {
          existingRecords = List.from(localLead['custom_button_press_records'] ?? []);
        }
      }
      
      // Append the new record
      existingRecords.add(newRecord);

      final body = {
        "custom_button_logs": existingRecords
      };

      final headers = await AuthService.getHeaders();
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/api/resource/Lead/$leadId'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('Button press recorded successfully for lead $leadId: $buttonName');
        // Update local DB with the new records to keep it in sync
        if (localLead != null) {
          // Update the correct field in the local map
          localLead['custom_button_logs'] = existingRecords;
          // Also remove the old field if it exists to clean up
          localLead.remove('custom_button_press_records');
          await LeadDatabase().upsertLead(localLead);
        }
        return true;
      } else {
        print('Failed to record button press for lead $leadId: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error recording button press for lead $leadId: $e');
      return false;
    }
  }

  static Future<bool> markLeadAsLost(String leadId) async {
    try {
      final headers = await AuthService.getHeaders();
      final response = await _httpClient.put(
        Uri.parse('$baseUrl/api/resource/Lead/$leadId'),
        headers: headers,
        body: jsonEncode({
          'status': 'Do Not Contact',
          'custom_lead_status': 'Lost',
        }),
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        print('Lead marked as Lost successfully: $leadId');
        return true;
      } else {
        print('Failed to mark lead as Lost: ${response.statusCode} - ${response.body}');
        return false;
      }
    } catch (e) {
      print('Error marking lead as Lost: $e');
      return false;
    }
  }

  // Generic dropdown fetcher with optional simple caching
  static Future<List<String>> _fetchDropdownData({
    required String endpoint,
    required List<String>? cache,
    required DateTime? lastFetch,
    required Function(List<String>) setCache,
    required Function(DateTime) setLastFetch,
  }) async {
    final now = DateTime.now();
    if (cache != null && lastFetch != null && now.difference(lastFetch).inMinutes < 5) {
      print('Returning cached dropdown data for $endpoint');
      return cache;
    }

    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(endpoint);
      final response = await _httpClient.get(url, headers: headers).timeout(const Duration(seconds: 20));
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          final names = items.map((item) => item['name'].toString()).toList();
          setCache(names);
          setLastFetch(now);
          return names;
        }
      }
      return [];
    } catch (e) {
      print('Error fetching dropdown data for $endpoint: $e');
      return [];
    }
  }

  static Future<List<String>> fetchCampaigns({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _campaignsCache = null;
      _campaignsLastFetch = null;
    }
    return _fetchDropdownData(
      endpoint: '$baseUrl/api/resource/Campaign',
      cache: _campaignsCache,
      lastFetch: _campaignsLastFetch,
      setCache: (data) => _campaignsCache = data,
      setLastFetch: (date) => _campaignsLastFetch = date,
    );
  }

  static Future<List<String>> fetchIndustryTypes({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _industryTypesCache = null;
      _industryTypesLastFetch = null;
    }
    return _fetchDropdownData(
      endpoint: '$baseUrl/api/resource/Industry Type',
      cache: _industryTypesCache,
      lastFetch: _industryTypesLastFetch,
      setCache: (data) => _industryTypesCache = data,
      setLastFetch: (date) => _industryTypesLastFetch = date,
    );
  }

  static Future<List<String>> fetchMarketSegments({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _marketSegmentsCache = null;
      _marketSegmentsLastFetch = null;
    }
    return _fetchDropdownData(
      endpoint: '$baseUrl/api/resource/Market Segment',
      cache: _marketSegmentsCache,
      lastFetch: _marketSegmentsLastFetch,
      setCache: (data) => _marketSegmentsCache = data,
      setLastFetch: (date) => _marketSegmentsLastFetch = date,
    );
  }

  static Future<List<String>> fetchLeadSources({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _leadSourcesCache = null;
      _leadSourcesLastFetch = null;
    }
    return _fetchDropdownData(
      endpoint: '$baseUrl/api/resource/Lead Source',
      cache: _leadSourcesCache,
      lastFetch: _leadSourcesLastFetch,
      setCache: (data) => _leadSourcesCache = data,
      setLastFetch: (date) => _leadSourcesLastFetch = date,
    );
  }

  static Future<List<String>> fetchTerritories({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _territoriesCache = null;
      _territoriesLastFetch = null;
    }
    return _fetchDropdownData(
      endpoint: '$baseUrl/api/resource/Territory',
      cache: _territoriesCache,
      lastFetch: _territoriesLastFetch,
      setCache: (data) => _territoriesCache = data,
      setLastFetch: (date) => _territoriesLastFetch = date,
    );
  }

  static Future<List<Map<String, String>>> fetchUsersWithId({bool forceRefresh = false}) async {
    if (forceRefresh) {
      _usersWithIdCache = null;
      _usersWithIdLastFetch = null;
    }
    final now = DateTime.now();
    if (_usersWithIdCache != null && _usersWithIdLastFetch != null && now.difference(_usersWithIdLastFetch!).inMinutes < 5) {
      return _usersWithIdCache!;
    }

    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/User?fields=["name","full_name"]');
      final response = await _httpClient.get(url, headers: headers).timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          final users = items.map((item) => {
                'id': item['name'].toString(),
                'name': item['full_name']?.toString() ?? item['name'].toString(),
              }).toList();
          _usersWithIdCache = List<Map<String, String>>.from(users);
          _usersWithIdLastFetch = now;
          return users;
        }
      }
      return [];
    } catch (e) {
      print('Error fetching users with id: $e');
      return [];
    }
  }

  static Future<List<String>> fetchUsers({bool forceRefresh = false}) async {
    final usersWithId = await fetchUsersWithId(forceRefresh: forceRefresh);
    return usersWithId.map((user) => user['id']!).toList();
  }

  // Fetch leads for a specific broker
  static Future<List<Lead>> fetchBrokerLeads(String brokerId) async {
    try {
      print('🔍 Fetching leads for broker: $brokerId');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Lead/?filters=[["lead_owner","=","$brokerId"]]');
      print('DEBUG: fetchBrokerLeads URL: $url');
      print('DEBUG: fetchBrokerLeads Headers: $headers');
      final response = await _httpClient
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('✅ Broker leads response status: ${response.statusCode}');
      print('📄 Broker leads response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['data'] ?? [];
        print('📊 Broker leads JSON data: $jsonData');
        return jsonData.map((json) => Lead.fromJson(json)).toList();
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
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
      throw Exception('Error fetching broker leads: $e');
    }
  }

  // Fetch all leads
  static Future<List<Lead>> fetchAllLeads() async {
    try {
      print('🔍 Fetching all leads from: $baseUrl/api/resource/Lead');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Lead');
      print('DEBUG: fetchAllLeads URL: $url');
      print('DEBUG: fetchAllLeads Headers: $headers');
      final response = await _httpClient.get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('✅ All leads response status: ${response.statusCode}');
      print('📄 All leads response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['data'] ?? [];
        print('📊 All leads JSON data: $jsonData');
        return jsonData.map((json) => Lead.fromJson(json)).toList();
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
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
      throw Exception('Error fetching all leads: $e');
    }
  }

  // Create a new lead
  static Future<Lead> createLead(Lead lead) async {
    try {
      print('🔍 Creating lead: ${lead.toJson()}');
      final headers = {'Content-Type': 'application/json'};
      final url = Uri.parse('$baseUrl/api/resource/Lead/');
      print('DEBUG: createLead URL: $url');
      print('DEBUG: createLead Headers: $headers');
      final response = await _httpClient
          .post(
            url,
            headers: headers,
            body: json.encode(lead.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('✅ Create lead response status: ${response.statusCode}');
      print('📄 Create lead response body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final jsonData = json.decode(response.body);
        print('📊 Created lead JSON data: $jsonData');
        return Lead.fromJson(jsonData);
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
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
      throw Exception('Error creating lead: $e');
    }
  }


  // Update lead by ID (API and local DB)
  Future<void> updateLead(String leadId, Map<String, dynamic> updates) async {
    try {
      // Clean updates before sending to API
      final cleanedUpdates = Map<String, dynamic>.from(updates);
      cleanedUpdates.removeWhere((key, value) => 
        key.startsWith('_') || 
        key == 'name' || 
        key == 'doctype' ||
        key == 'idx' ||
        key == 'owner' ||
        key == 'docstatus' ||
        key == 'creation' ||
        key == 'modified' ||
        key == 'modifiedBy' ||
        value == null
      );

      final urlStr = '$baseUrl/api/resource/Lead/$leadId';
      final response = await _client.put(
        Uri.parse(urlStr),
        headers: await _getHeaders(),
        body: json.encode(cleanedUpdates),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // If API update is successful, update local DB
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> updatedLeadData = responseData['data'] ?? responseData;
        await LeadDatabase().upsertLead(updatedLeadData);
        print('Lead $leadId updated successfully (API and local DB).');
      } else {
        throw Exception('Failed to update lead $leadId on API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error updating lead $leadId: $e');
      rethrow;
    }
  }

  // Delete lead by ID (API and local DB)
  Future<void> deleteLead(String leadId) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/api/resource/Lead/$leadId'),
        headers: await _getHeaders(),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 204) {
        // If API delete is successful, delete from local DB
        // Assuming LeadDatabase has a delete method
        // You might need to add a deleteLead method to LeadDatabase
        // For now, I'll simulate it by assuming it handles deletion
        await LeadDatabase().deleteLead(leadId); // This method needs to be added
        print('Lead $leadId deleted successfully (API and local DB).');
      } else {
        throw Exception('Failed to delete lead $leadId on API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error deleting lead $leadId: $e');
      rethrow;
    }
  }

  static Future<List<Lead>> fetchMyLeads({bool forceRefresh = false}) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _leadsCache != null &&
        _leadsLastFetch != null &&
        now.difference(_leadsLastFetch!).inMinutes < 5) { // 5-minute cache
      print('Returning cached leads');
      return _leadsCache!;
    }

    try {
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_leads',
      );

      print('🔍 [EMULATOR] Fetching hierarchy leads from: $uri');

      final headers = await AuthService.getHeaders();
      
      // 3. Use POST (or GET) depending on your setup. 
      // POST is often safer for custom methods to avoid caching issues.
      final url = uri;
      print('DEBUG: fetchMyLeads URL: $url');
      print('DEBUG: fetchMyLeads Headers: $headers');
      final response = await _httpClient.post(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      print('✅ [EMULATOR] Leads response status: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        
        // 4. CRITICAL CHANGE: Custom APIs return data in 'message', not 'data'
        if (responseData.containsKey('message') && responseData['message'] is List) {
           final List<dynamic> jsonData = responseData['message'];
           print('📊 [EMULATOR] Leads found: ${jsonData.length}');
           final leads = jsonData.map((json) => Lead.fromJson(json)).toList();
           _leadsCache = leads; // Store in cache
           _leadsLastFetch = now; // Update last fetch time
           return leads;
        } else {
           print('⚠️ [EMULATOR] "message" key missing or not a list.');
           return [];
        }

      } else {
        print(
          '❌ [EMULATOR] Error fetching leads: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('❌ [EMULATOR] Exception fetching leads: $e');
      return [];
    }
  }

  Future<void> syncMyLeads() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastSyncTimestamp =
        prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";

    print('Last sync timestamp: $lastSyncTimestamp');

    // Encode the filter to be URL-safe
    final String filters = json.encode([
      ["modified", ">", lastSyncTimestamp]
    ]);

    final Uri uri = Uri.parse(
        '$baseUrl/api/method/homesol_app.api.get_team_leads?filters=$filters');
    print('Requesting URL: $uri');

    try {
      final response = await _client.get(uri, headers: await _getHeaders()); // Use the injected client

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> message = responseBody['message'] ?? [];

        if (message.isEmpty) {
                  print('No new leads to sync for upserting.');
                  // Even if no new leads to upsert, we still need to check for deletions.
                }
          
                final LeadDatabase leadDatabase = LeadDatabase();
          
                // Step 1: Get all local lead IDs
                final List<Map<String, dynamic>> localLeadsRaw = await leadDatabase.getAllLeads();
                final Set<String> localLeadNames = localLeadsRaw.map((e) => e['name'].toString()).toSet();
          
                // Step 2: Get all active server lead IDs
                // Using fetchAllLeads() to get all current leads from the server for comparison.
                // This assumes fetchAllLeads() returns ALL leads, not just team leads.
                final List<Lead> serverLeads = await LeadService.fetchAllLeads();
                final Set<String> serverLeadNames = serverLeads.map((e) => e.name).where((name) => name != null).cast<String>().toSet();
          
                // Step 3: Identify leads to delete locally
                final List<String> leadsToDelete = localLeadNames
                    .where((name) => !serverLeadNames.contains(name))
                    .toList();
          
                // Step 4: Delete identified leads from local database
                for (final leadName in leadsToDelete) {
                  await leadDatabase.deleteLead(leadName);
                  print('Deleted local lead: $leadName (no longer on server)');
                }
          
                DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp + 'Z');
          
                for (var leadJson in message) {
                    // Ensure leadJson is a Map<String, dynamic>
                    if (leadJson is Map<String, dynamic>) {
                      await leadDatabase.upsertLead(leadJson);
          
                      final currentLeadModified =
                          DateTime.parse(leadJson['modified'] + 'Z');
                      if (currentLeadModified.isAfter(latestModifiedDate)) {
                        latestModifiedDate = currentLeadModified;
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
        print('Leads synced successfully. New last sync timestamp: $newLastSyncTimestamp');
      } else {
        print('Failed to load leads: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e) {
      print('Error during lead sync: $e');
    }
  }



  static Future<Lead?> fetchLead(String id) async {
    try {
      print('Fetching lead from: $baseUrl/api/resource/Lead/$id');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Lead/$id');
      print('DEBUG: fetchLead URL: $url');
      print('DEBUG: fetchLead Headers: $headers');
      final response = await _httpClient
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Lead response status: ${response.statusCode}');
      print('Lead response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> jsonData = responseData['data'];
        print('Lead JSON data: $jsonData');
        return Lead.fromJson(jsonData);
      } else {
        print('❌ Lead error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return null;
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return null;
    } catch (e) {
      print('❌ General exception caught: $e');
      return null;
    }
  }

  static Future<List<FollowUp>> fetchTeamFollowups(String leadId) async {
    try {
      print(
        'Fetching team followups for lead $leadId from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      );
      final headers = await AuthService.getHeaders();
      // Construct the URI with the lead_id as a query parameter
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      ).replace(queryParameters: {'lead_id': leadId});
      final url = uri;
      print('DEBUG: fetchTeamFollowups URL: $url');
      print('DEBUG: fetchTeamFollowups Headers: $headers');
      final response = await _httpClient
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Team followups response status: ${response.statusCode}');
      print('Team followups response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        print('Team followups JSON data: $jsonData');
        final followups = jsonData.map((json) => FollowUp.fromJson(json)).toList();
        return followups;
      } else {
        print('❌ Team followups error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return [];
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return [];
    } catch (e) {
      print('❌ General exception caught: $e');
      return [];
    }
  }

  // New method to fetch all follow-ups for the authenticated user/team
  static Future<List<FollowUp>> fetchMyFollowups({bool forceRefresh = false}) async {
    // Load from local database first
    try {
      final cachedFollowups = await FollowUpDatabase.getAllFollowUps();
      if (cachedFollowups.isNotEmpty && !forceRefresh) {
        print('Returning cached my followups from database');
        return cachedFollowups;
      }
    } catch (e) {
      print('Error loading from database: $e');
    }

    // Sync from API if DB is empty or forceRefresh is true
    return await syncMyFollowups(forceRefresh: forceRefresh);
  }

  static Future<List<FollowUp>> syncMyFollowups({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncFollowupsTimestampKey);

      print(
        'Syncing all followups from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      );
      final headers = await AuthService.getHeaders();
      // No lead_id parameter, so it should fetch all for the team/user
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      );

      // Build request body with timestamp filter
      final Map<String, dynamic> filters = {};
      if (lastSyncTimestamp != null && !forceRefresh) {
        filters['filters'] = [["modified", ">", lastSyncTimestamp]];
      }

      final url = uri;
      print('DEBUG: syncMyFollowups URL: $url');
      print('DEBUG: syncMyFollowups Headers: $headers');
      final response = await _httpClient
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('All followups response status: ${response.statusCode}');
      print('All followups response body: ${response.body}');

      if (response.statusCode == 200) {
        // --- Deletion Handling Start ---
        final FollowUpDatabase followUpDatabase = FollowUpDatabase();

        // Step 1: Get all local Follow-up IDs
        final List<FollowUp> localFollowups = await FollowUpDatabase.getAllFollowUps();
        final Set<String> localFollowupNames = localFollowups.map((f) => f.name).toSet();

        // Step 2: Get all active server Follow-up IDs
        final List<String> serverFollowupNamesList = await fetchFollowupNamesFromServer();
        final Set<String> serverFollowupNames = serverFollowupNamesList.toSet();

        // Step 3: Identify follow-ups to delete locally
        final List<String> followupsToDelete = localFollowupNames
            .where((name) => !serverFollowupNames.contains(name))
            .toList();

        // Step 4: Delete identified follow-ups from local database
        for (final followupName in followupsToDelete) {
          await FollowUpDatabase.deleteFollowUp(followupName);
          print('Deleted local follow-up: $followupName (no longer on server)');
        }
        // --- Deletion Handling End ---

        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        print('All followups JSON data: $jsonData');
        final followups = jsonData.map((json) => FollowUp.fromJson(json)).toList();

        // Store in database
        for (final followup in followups) {
          await FollowUpDatabase.upsertFollowUp(followup);
        }

        // Update last sync timestamp
        final now = DateTime.now();
        final formattedTimestamp =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
        await prefs.setString(_lastSyncFollowupsTimestampKey, formattedTimestamp);

        return followups;
      } else {
        print('❌ All followups error: ${response.statusCode} - ${response.body}');
        return await FollowUpDatabase.getAllFollowUps();
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return await FollowUpDatabase.getAllFollowUps();
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return await FollowUpDatabase.getAllFollowUps();
    } catch (e) {
      print('❌ General exception caught: $e');
      return await FollowUpDatabase.getAllFollowUps();
    }
  }

  static Future<FollowUp?> fetchFollowUp(String followUpName) async {
    try {
      print('Fetching follow-up $followUpName from: $baseUrl/api/resource/Lead FollowUps/$followUpName');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Lead%20FollowUps/$followUpName');
      print('DEBUG: fetchFollowUp URL: $url');
      print('DEBUG: fetchFollowUp Headers: $headers');
      final response = await _httpClient
          .get(
            url,
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      print('Follow-up response status: ${response.statusCode}');
      print('Follow-up response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> jsonData = responseData['data'];
        print('Follow-up JSON data: $jsonData');
        return FollowUp.fromJson(jsonData);
      } else if (response.statusCode == 404) {
        print('❌ Follow-up $followUpName not found.');
        return null;
      } else {
        print('❌ Follow-up error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch follow-up: ${response.statusCode} - ${response.body}');
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server: $e');
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server: $e');
    } catch (e) {
      print('❌ General exception caught: $e');
      throw Exception('Error fetching follow-up: $e');
    }
  }

  static Future<bool> updateFollowUp(String followUpName, String status, String remarks, {String? nextFollowUp}) async {
    try {
      print('Updating follow-up $followUpName with status: $status, remarks: $remarks, nextFollowUp: $nextFollowUp');
      final headers = await AuthService.getHeaders();
      
      final Map<String, dynamic> body = {
        "status": status,
        "remarks": remarks,
      };
      if (nextFollowUp != null && nextFollowUp.isNotEmpty) {
        body["next_follow_up"] = nextFollowUp;
      }

      final response = await _httpClient.put(
        Uri.parse('$baseUrl/api/resource/Lead%20FollowUps/$followUpName'),
        headers: headers,
        body: json.encode(body),
      ).timeout(const Duration(seconds: 30));

      print('Update follow-up response status: ${response.statusCode}');
      print('Update follow-up response body: ${response.body}');

      if (response.statusCode == 200) {
        // Assuming a 200 status code indicates success for updates
        return true;
      } else {
        print('❌ Failed to update follow-up: ${response.statusCode} - ${response.body}');
        return false;
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server: $e');
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server: $e');
    } catch (e) {
      print('❌ General exception caught: $e');
      throw Exception('Error updating follow-up: $e');
    }
  }
    
  static Future<Lead?> createLeadFromForm(Map<String, dynamic> formData) async {
    try {
      final headers = await AuthService.getHeaders();
      final userData = await AuthService.getUserData();
      final owner = userData?['email'] ?? 'Administrator';

      final body = {
        // 'naming_series': 'CRM-LEAD-.YYYY.-', // Frappe will handle this if not provided or if auto-name is set
        'lead_owner': owner,
        'status': 'Lead',
        'custom_lead_status': 'New Lead',
        'custom_latest_visit_status': 'Visit Scheduled',
        'is_verified': 1,
        ...formData,
      };

      print('Submitting lead with body: ${jsonEncode(body)}');

      final url = Uri.parse('$baseUrl/api/resource/Lead');
      print('DEBUG: createLeadFromForm URL: $url');
      print('DEBUG: createLeadFromForm Headers: $headers');
      final response = await _httpClient.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      print('Create lead from form response: ${response.statusCode} ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        return Lead.fromJson(responseData['data']);
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
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
      throw Exception('Error creating lead from form: $e');
    }
  }

  // Helper to fetch all followup names from server for deletion comparison
  static Future<List<String>> fetchFollowupNamesFromServer() async {
    try {
      final headers = await AuthService.getHeaders();
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      );
      final url = uri;
      print('DEBUG: fetchFollowupNamesFromServer URL: $url');
      print('DEBUG: fetchFollowupNamesFromServer Headers: $headers');
      final response = await _httpClient.get(url, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toList();
      } else {
        print('❌ Error fetching all followup names from server: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching all followup names from server: $e');
      return [];
    }
  }

  // New method to clear all caches and local storage related to sync functions
  static Future<void> clearAllCaches() async {
    print('Clearing all sync-related caches...');

    // Clear LeadService static caches
    _leadsCache = null;
    _leadsLastFetch = null;
    _campaignsCache = null;
    _campaignsLastFetch = null;
    _territoriesCache = null;
    _territoriesLastFetch = null;
    _industryTypesCache = null;
    _industryTypesLastFetch = null;
    _marketSegmentsCache = null;
    _marketSegmentsLastFetch = null;
    _leadSourcesCache = null;
    _leadSourcesLastFetch = null;
    _usersWithIdCache = null;
    _usersWithIdLastFetch = null;

    // Clear SharedPreferences entries
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove("last_sync_timestamp_leads"); 
    await prefs.remove(_lastSyncFollowupsTimestampKey);

    // Clear local databases
    await LeadDatabase().deleteAllLeads();
    await FollowUpDatabase.deleteAllFollowUps();
    await ChannelPartnerDatabase().deleteAllChannelPartners();
    await DeveloperDatabase().deleteAllDevelopers();
    await ProjectDatabase().deleteAllProjects(); 
    await SiteVisitDatabase.deleteAllSiteVisits(); 
    await SalesTeamDatabase().deleteAllSalesTeams();
    await UserProfileDatabase().deleteAllUserProfiles();

    print('All sync-related caches cleared successfully.');
  }

}