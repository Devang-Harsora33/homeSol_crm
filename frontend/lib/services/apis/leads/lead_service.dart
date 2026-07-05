import 'dart:convert';
import 'package:Homesol/models/activity_log.dart';
import 'package:Homesol/models/follow_up.dart';
import 'package:Homesol/models/lead.dart';
import 'package:Homesol/models/campaign.dart';
import 'package:Homesol/models/lead_transfer.dart';
import 'package:http/http.dart' as http;
import '../../auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Homesol/services/databases/lead_database.dart';
import 'package:Homesol/services/databases/follow_up_database.dart';
import 'package:Homesol/services/databases/channel_partner_database.dart';
import 'package:Homesol/services/databases/developer_database.dart';
import 'package:Homesol/services/databases/project_database.dart';
import 'package:Homesol/services/databases/site_visit_database.dart';
import 'package:Homesol/services/databases/sales_team_database.dart';
import 'package:Homesol/services/databases/user_profile_database.dart';
import 'package:Homesol/services/apis/sourcing/sourcing_service.dart'; // Add this
import 'package:Homesol/services/connectivity_service.dart';
import 'package:intl/intl.dart';
import 'package:Homesol/utils/error_logger.dart';

class LeadService {
  static String get baseUrl => AuthService.baseUrl;
  // Cache variables for leads
  static List<Lead>? _leadsCache;
  static DateTime? _leadsLastFetch;
  static const String _lastSyncTimestampKey = "last_sync_timestamp_leads";
  static const String _lastSyncFollowupsTimestampKey =
      "last_sync_timestamp_followups";

  // Static client for static methods (can be mocked for testing)
  static http.Client? _testClient;
  static http.Client get _httpClient => _testClient ?? http.Client();

  // Setter for injecting mock client for static methods in tests
  static void setTestClient(http.Client? client) {
    _testClient = client;
  }

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
  static List<Map<String, dynamic>>? _usersWithIdCache;
  static DateTime? _usersWithIdLastFetch;

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
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
      body: jsonEncode({'mobile_no': mobileNo, 'lead_name': null}),
    );

    if (AuthService.checkResponse(response)) return null;

    print('OTP Trigger API Response: ${response.body}');

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      if (responseData['message'] == 'success') {
        if (responseData.containsKey('_server_messages')) {
          final serverMessages = jsonDecode(responseData['_server_messages']);
          if (serverMessages.isNotEmpty) {
            final innerMessageJson = jsonDecode(serverMessages[0]);
            final message = innerMessageJson['message'];
            final otpMatch = RegExp(
              r'OTP: <b>(\d{6})<\/b>',
            ).firstMatch(message);
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

    if (AuthService.checkResponse(response)) return false;

    if (response.statusCode == 200) {
      final responseData = jsonDecode(response.body);
      return responseData['message'] == true;
    } else {
      return false;
    }
  }

  static Future<bool> recordButtonPress(
    String leadId,
    String buttonName,
  ) async {
    try {
      final now = DateTime.now();
      final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);

      final userData = await AuthService.getUserData();
      final pressedBy = userData?['email'] ?? 'Unknown';

      final newRecord = {
        "date_and_time": formattedDate,
        "button_pressed": buttonName,
        "pressed_by": pressedBy,
        "doctype": "Buttons Pressed Logs",
      };

      // Fetch existing lead data from local DB to get existing button press records
      final localLead = await LeadDatabase().getLeadByName(leadId);
      List<dynamic> existingRecords = [];

      // Try both field names just in case, but prioritize custom_button_logs
      if (localLead != null) {
        if (localLead.containsKey('custom_button_logs')) {
          existingRecords = List.from(localLead['custom_button_logs'] ?? []);
        } else if (localLead.containsKey('custom_button_press_records')) {
          existingRecords = List.from(
            localLead['custom_button_press_records'] ?? [],
          );
        }
      }

      // Append the new record
      existingRecords.add(newRecord);

      final body = {"custom_button_logs": existingRecords};

      final headers = await AuthService.getHeaders();
      final response = await _httpClient
          .put(
            Uri.parse('$baseUrl/api/resource/Lead/$leadId'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (AuthService.checkResponse(response)) return false;

      if (response.statusCode == 200) {
        print(
          'Button press recorded successfully for lead $leadId: $buttonName',
        );
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
        print(
          'Failed to record button press for lead $leadId: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'recordButtonPress',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error recording button press for lead $leadId: $e');
      return false;
    }
  }

  static Future<bool> markLeadAsLost(String leadId) async {
    try {
      final headers = await AuthService.getHeaders();
      final response = await _httpClient
          .put(
            Uri.parse('$baseUrl/api/resource/Lead/$leadId'),
            headers: headers,
            body: jsonEncode({
              'status': 'Do Not Contact',
              'custom_lead_status': 'Lost',
            }),
          )
          .timeout(const Duration(seconds: 15));

      if (AuthService.checkResponse(response)) return false;

      if (response.statusCode == 200) {
        print('Lead marked as Lost successfully: $leadId');
        return true;
      } else {
        print(
          'Failed to mark lead as Lost: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'markLeadAsLost',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
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
    if (cache != null &&
        lastFetch != null &&
        now.difference(lastFetch).inMinutes < 5) {
      print('Returning cached dropdown data for $endpoint');
      return cache;
    }

    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(endpoint);
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (AuthService.checkResponse(response)) return [];

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
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: '_fetchDropdownData',
        message: 'Endpoint: $endpoint | Error: $e',
        stackTrace: stack.toString(),
      );
      print('Error fetching dropdown data for $endpoint: $e');
      return [];
    }
  }

  static Future<List<String>> fetchCampaigns({
    bool forceRefresh = false,
  }) async {
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

  static Future<List<Campaign>> fetchCampaignsByProject(
    String projectId,
  ) async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/method/homesol_app.api.get_campaigns_by_project?project_id=$projectId',
      );
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] != null && data['message']['data'] is List) {
          final List<dynamic> items = data['message']['data'];
          return items.map((item) => Campaign.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchCampaignsByProject',
        message: 'ProjectID: $projectId | Error: $e',
        stackTrace: stack.toString(),
      );
      print('Error fetching campaigns by project $projectId: $e');
      return [];
    }
  }

  static Future<List<String>> fetchIndustryTypes({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _industryTypesCache = null;
      _industryTypesLastFetch = null;
    }
    return _fetchDropdownData(
      endpoint: '$baseUrl/api/resource/Industry Type?limit_page_length=500',
      cache: _industryTypesCache,
      lastFetch: _industryTypesLastFetch,
      setCache: (data) => _industryTypesCache = data,
      setLastFetch: (date) => _industryTypesLastFetch = date,
    );
  }

  static Future<List<String>> fetchMarketSegments({
    bool forceRefresh = false,
  }) async {
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

  static Future<List<String>> fetchLeadSources({
    bool forceRefresh = false,
  }) async {
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

  static Future<List<String>> fetchTerritories({
    bool forceRefresh = false,
  }) async {
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

  static Future<List<Map<String, dynamic>>> fetchUsersWithId({
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      _usersWithIdCache = null;
      _usersWithIdLastFetch = null;
    }
    final now = DateTime.now();
    if (_usersWithIdCache != null &&
        _usersWithIdLastFetch != null &&
        now.difference(_usersWithIdLastFetch!).inMinutes < 5) {
      return _usersWithIdCache!;
    }

    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/resource/User?fields=["name","full_name"]',
      );
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          final users = items
              .map(
                (item) => {
                  'id': item['name'].toString(),
                  'name':
                      item['full_name']?.toString() ?? item['name'].toString(),
                },
              )
              .toList();
          _usersWithIdCache = List<Map<String, String>>.from(users);
          _usersWithIdLastFetch = now;
          return users;
        }
      }
      return [];
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchUsersWithId',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error fetching users with id: $e');
      return [];
    }
  }

  static Future<List<String>> fetchUsers({bool forceRefresh = false}) async {
    final usersWithId = await fetchUsersWithId(forceRefresh: forceRefresh);
    return usersWithId.map((user) => user['id']!.toString()).toList();
  }

  // Fetch leads for a specific broker
  static Future<List<Lead>> fetchBrokerLeads(String brokerId) async {
    try {
      print('🔍 Fetching leads for broker: $brokerId');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/resource/Lead/?filters=[["lead_owner","=","$brokerId"]]',
      );
      print('DEBUG: fetchBrokerLeads URL: $url');
      print('DEBUG: fetchBrokerLeads Headers: $headers');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

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
    } on http.ClientException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchBrokerLeads',
        message: 'ClientException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchBrokerLeads',
        message: 'FormatException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchBrokerLeads',
        message: 'GeneralException: $e',
        stackTrace: stack.toString(),
      );
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
    if (!ConnectivityService.isOnline) return [];
    try {
      print('🔍 Fetching all leads from: $baseUrl/api/resource/Lead');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/resource/Lead?limit_page_length=none',
      );
      print('DEBUG: fetchAllLeads URL: $url');
      print('DEBUG: fetchAllLeads Headers: $headers');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

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
    } on http.ClientException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchAllLeads',
        message: 'ClientException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchAllLeads',
        message: 'FormatException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchAllLeads',
        message: 'GeneralException: $e',
        stackTrace: stack.toString(),
      );
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
    if (!ConnectivityService.isOnline) {
      throw Exception(
        'Offline: Cannot create lead without internet connection.',
      );
    }
    try {
      print('🔍 Creating lead: ${lead.toJson()}');
      final headers = {'Content-Type': 'application/json'};
      final url = Uri.parse('$baseUrl/api/resource/Lead/');
      print('DEBUG: createLead URL: $url');
      print('DEBUG: createLead Headers: $headers');
      final response = await _httpClient
          .post(url, headers: headers, body: json.encode(lead.toJson()))
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response))
        throw Exception('Session Expired');

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
    } on http.ClientException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'createLead',
        message: 'ClientException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ ClientException caught: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'createLead',
        message: 'FormatException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ FormatException caught: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'createLead',
        message: 'GeneralException: $e',
        stackTrace: stack.toString(),
      );
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
  static Future<List<Lead>> fetchLeadsByOwner(String ownerEmail) async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      // Filters for all leads owned by the specific user
      final filters = jsonEncode([
        ["lead_owner", "=", ownerEmail],
      ]);
      final url = Uri.parse(
        '$baseUrl/api/resource/Lead?filters=$filters&fields=["name","lead_name","mobile_no","lead_owner","status"]&limit_page_length=2000',
      );
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          return (data['data'] as List)
              .map((json) => Lead.fromJson(json))
              .toList();
        }
      }
      return [];
    } catch (e) {
      print('Error fetching leads by owner: $e');
      return [];
    }
  }

  static Future<void> updateLead(
    String leadId,
    Map<String, dynamic> updates,
  ) async {
    if (!ConnectivityService.isOnline) {
      // For now, we only update API and then local DB.
      // Offline update would require a sync queue.
      throw Exception(
        'Offline: Cannot update lead without internet connection.',
      );
    }
    try {
      // Clean updates before sending to API
      final cleanedUpdates = Map<String, dynamic>.from(updates);
      cleanedUpdates.removeWhere(
        (key, value) =>
            key.startsWith('_') ||
            key == 'name' ||
            key == 'doctype' ||
            key == 'idx' ||
            key == 'owner' ||
            key == 'docstatus' ||
            key == 'creation' ||
            key == 'modified' ||
            key == 'modifiedBy' ||
            value == null,
      );

      final urlStr = '$baseUrl/api/resource/Lead/$leadId';
      final response = await _httpClient
          .put(
            Uri.parse(urlStr),
            headers: await _getHeaders(),
            body: json.encode(cleanedUpdates),
          )
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return;

      if (response.statusCode == 200) {
        // If API update is successful, update local DB
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> updatedLeadData =
            responseData['data'] ?? responseData;
        await LeadDatabase().upsertLead(updatedLeadData);
        print('Lead $leadId updated successfully (API and local DB).');
      } else {
        String errorMessage = 'Failed to update lead $leadId on API: ${response.statusCode} - ${response.body}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['exception'] != null) {
            final exceptionStr = errorData['exception'].toString();
            if (exceptionStr.contains('UniqueValidationError') || exceptionStr.contains('Duplicate entry')) {
               if (exceptionStr.contains('mobile_no')) {
                 errorMessage = 'A lead with this mobile number already exists.';
               } else if (exceptionStr.contains('email_id')) {
                 errorMessage = 'A lead with this email address already exists.';
               } else {
                 errorMessage = 'A lead with these details already exists (duplicate entry).';
               }
            } else if (errorData['exc_type'] != null) {
               if (errorData['exception'] != null) {
                 final rawMsg = errorData['exception'].toString();
                 final parts = rawMsg.split(': ');
                 if (parts.length > 1) {
                   errorMessage = parts.sublist(1).join(': ').replaceAll('<b>', '').replaceAll('</b>', '').trim();
                 } else {
                   errorMessage = rawMsg.replaceAll('<b>', '').replaceAll('</b>', '').trim();
                 }
               } else {
                 errorMessage = 'Validation Error: ${errorData['exc_type']}';
               }
            }
          }
        } catch (_) {}
        throw Exception(errorMessage);
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'updateLead',
        message: 'LeadID: $leadId | Error: $e',
        stackTrace: stack.toString(),
      );
      print('Error updating lead $leadId: $e');
      rethrow;
    }
  }

  // Delete lead by ID (API and local DB)
  static Future<void> deleteLead(String leadId) async {
    try {
      final response = await _httpClient
          .delete(
            Uri.parse('$baseUrl/api/resource/Lead/$leadId'),
            headers: await _getHeaders(),
          )
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return;

      if (response.statusCode == 200 || response.statusCode == 204) {
        // If API delete is successful, delete from local DB
        await LeadDatabase().deleteLead(leadId);
        print('Lead $leadId deleted successfully (API and local DB).');
      } else {
        throw Exception(
          'Failed to delete lead $leadId on API: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'deleteLead',
        message: 'LeadID: $leadId | Error: $e',
        stackTrace: stack.toString(),
      );
      print('Error deleting lead $leadId: $e');
      rethrow;
    }
  }

  static Future<List<Lead>> fetchMyLeads({bool forceRefresh = false}) async {
    final LeadDatabase leadDatabase = LeadDatabase();

    // 1. If not forcing refresh or offline, try to return from local DB
    if (!forceRefresh || !ConnectivityService.isOnline) {
      final List<Map<String, dynamic>> rawLeads = await leadDatabase
          .getAllLeads();
      if (rawLeads.isNotEmpty) {
        print('Returning leads from local database');
        final leads = rawLeads.map((data) {
          final leadJson = json.decode(data['data']);
          return Lead.fromJson(leadJson);
        }).toList();
        _leadsCache = leads;
        _leadsLastFetch = DateTime.now();
        return leads;
      }
    }

    // 2. If online and (forcing refresh or DB was empty), sync from API
    if (ConnectivityService.isOnline) {
      try {
        await syncMyLeads();
      } catch (e) {
        print('Error during lead sync in fetchMyLeads: $e');
      }
    }

    // 3. Return the latest data from DB
    final List<Map<String, dynamic>> refreshedData = await leadDatabase
        .getAllLeads();
    final leads = refreshedData.map((data) {
      final leadJson = json.decode(data['data']);
      return Lead.fromJson(leadJson);
    }).toList();

    _leadsCache = leads;
    _leadsLastFetch = DateTime.now();
    return leads;
  }

  static Future<void> syncMyLeads() async {
    if (!ConnectivityService.isOnline) {
      print('Offline: Skipping syncMyLeads');
      return;
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String lastSyncTimestamp =
        prefs.getString(_lastSyncTimestampKey) ?? "2000-01-01 00:00:00";

    print('Last sync timestamp: $lastSyncTimestamp');

    // Encode the filter to be URL-safe
    final String filters = json.encode([
      ["modified", ">", lastSyncTimestamp],
    ]);

    final Uri uri = Uri.parse(
      '$baseUrl/api/method/homesol_app.api.get_team_leads?filters=$filters',
    );
    print('Requesting URL: $uri');

    try {
      final response = await _httpClient.get(uri, headers: await _getHeaders());

      if (AuthService.checkResponse(response)) return;

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseBody = json.decode(response.body);
        final List<dynamic> message = responseBody['message'] ?? [];

        print('✅ Lead Sync Success. Received ${message.length} leads.');
        if (message.isNotEmpty) {
          print('DEBUG: First lead snippet: ${json.encode(message.first)}');
          // Look for Neha's leads in the response
          final nehaLeads = message
              .where(
                (l) =>
                    l['lead_owner']?.toString().toLowerCase().contains(
                          'neha',
                        ) ==
                        true ||
                    l['owner']?.toString().toLowerCase().contains('neha') ==
                        true,
              )
              .toList();
          print(
            'DEBUG: Found ${nehaLeads.length} leads matching "neha" in sync response',
          );
        }

        if (message.isEmpty) {
          print('No new leads to sync for upserting.');
        }

        final LeadDatabase leadDatabase = LeadDatabase();

        // Step 1: Get all local lead IDs
        final List<Map<String, dynamic>> localLeadsRaw = await leadDatabase
            .getAllLeads();
        final Set<String> localLeadNames = localLeadsRaw
            .map((e) => e['name'].toString())
            .toSet();

        // Step 2: Get all active server lead IDs (Basic set for reconciliation)
        // Note: We use fetchAllLeads but we must be careful not to delete team leads
        // that might be missing from this list due to permissions.
        final List<Lead> serverLeads = await LeadService.fetchAllLeads();
        final Set<String> serverLeadNames = serverLeads
            .map((e) => e.name)
            .where((name) => name != null)
            .cast<String>()
            .toSet();

        // Step 3: Identify leads to delete locally
        // We only delete if serverLeads is NOT empty (meaning the API call was successful and returned data)
        if (serverLeadNames.isNotEmpty) {
          final List<String> leadsToDelete = localLeadNames
              .where((name) => !serverLeadNames.contains(name))
              .toList();

          // Only delete if the count of leads to delete is reasonable (e.g., not deleting everything)
          // Or if we are sure these are truly gone.
          // For now, let's keep it but add a safety check.
          if (leadsToDelete.length < localLeadNames.length * 0.5 ||
              leadsToDelete.length < 10) {
            for (final leadName in leadsToDelete) {
              await leadDatabase.deleteLead(leadName);
              print('Deleted local lead: $leadName (no longer on server)');
            }
          } else {
            print(
              '⚠️ Skipping mass deletion of ${leadsToDelete.length} leads for safety.',
            );
          }
        }

        DateTime latestModifiedDate = DateTime.parse(lastSyncTimestamp + 'Z');

        for (var leadJson in message) {
          if (leadJson is Map<String, dynamic>) {
            await leadDatabase.upsertLead(leadJson);

            final currentLeadModified = DateTime.parse(
              leadJson['modified'] + 'Z',
            );
            if (currentLeadModified.isAfter(latestModifiedDate)) {
              latestModifiedDate = currentLeadModified;
            }
          }
        }

        String formattedTimestamp = latestModifiedDate.toIso8601String();
        formattedTimestamp = formattedTimestamp
            .replaceAll('T', ' ')
            .replaceAll('Z', '');
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
        print(
          'Leads synced successfully. New last sync timestamp: $newLastSyncTimestamp',
        );
      } else {
        print('Failed to load leads: ${response.statusCode}');
        print('Response body: ${response.body}');
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'syncMyLeads',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error during lead sync: $e');
    }
  }

  static Future<List<Lead>> fetchLeadsByDeveloper(String developerId) async {
    // 1. If offline, return filtered leads from local DB
    if (!ConnectivityService.isOnline) {
      print('Offline: Loading developer leads from local database');
      final List<Map<String, dynamic>> rawLeads = await LeadDatabase()
          .getAllLeads();
      return rawLeads
          .map((data) {
            final leadJson = json.decode(data['data']);
            return Lead.fromJson(leadJson);
          })
          .where(
            (lead) =>
                // We might need to check multiple fields for developer ID depending on how it's stored in Lead
                lead.customInterestedProject ==
                    developerId || // If developerId is actually a project ID
                lead.projectId.contains(developerId),
          )
          .toList();
    }

    try {
      print('🔍 Fetching leads for developer: $developerId');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/method/homesol_app.api.get_leads_by_developer?developer_id=$developerId',
      );

      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => Lead.fromJson(json)).toList();
      } else {
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error fetching developer leads: $e');
      return [];
    }
  }

  static Future<Lead?> fetchLead(String id) async {
    // 1. Try to return from local DB if offline
    if (!ConnectivityService.isOnline) {
      print('Offline: Loading lead $id from local database');
      final localData = await LeadDatabase().getLeadByName(id);
      if (localData != null) {
        return Lead.fromJson(localData);
      }
      return null;
    }

    try {
      print('Fetching lead from: $baseUrl/api/resource/Lead/$id');
      final headers = await AuthService.getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Lead/$id');
      print('DEBUG: fetchLead URL: $url');
      print('DEBUG: fetchLead Headers: $headers');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return null;

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
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      ).replace(queryParameters: {'lead_id': leadId});
      final url = uri;
      print('DEBUG: fetchTeamFollowups URL: $url');
      print('DEBUG: fetchTeamFollowups Headers: $headers');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

      print('Team followups response status: ${response.statusCode}');
      print('Team followups response body: ${response.body}');

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        print('Team followups JSON data: $jsonData');
        final followups = jsonData
            .map((json) => FollowUp.fromJson(json))
            .toList();
        return followups;
      } else {
        print(
          '❌ Team followups error: ${response.statusCode} - ${response.body}',
        );
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

  static Future<List<FollowUp>> fetchMyFollowups({
    bool forceRefresh = false,
  }) async {
    // 1. If not forcing refresh or offline, try to return from local DB
    if (!forceRefresh || !ConnectivityService.isOnline) {
      try {
        final cachedFollowups = await FollowUpDatabase.getAllFollowUps();
        if (cachedFollowups.isNotEmpty) {
          print('Returning cached my followups from database');
          return cachedFollowups;
        }
      } catch (e) {
        print('Error loading from database: $e');
      }
    }

    // 2. If online and (forcing refresh or DB was empty), sync from API
    if (ConnectivityService.isOnline) {
      try {
        await syncMyFollowups(forceRefresh: forceRefresh);
      } catch (e) {
        print('Error during followups sync in fetchMyFollowups: $e');
      }
    }

    // 3. Return latest data from DB
    return await FollowUpDatabase.getAllFollowUps();
  }

  static Future<List<FollowUp>> syncMyFollowups({
    bool forceRefresh = false,
  }) async {
    if (!ConnectivityService.isOnline) {
      print('Offline: Skipping syncMyFollowups');
      return await FollowUpDatabase.getAllFollowUps();
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncFollowupsTimestampKey);

      print(
        'Syncing all followups from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      );
      final headers = await AuthService.getHeaders();
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      );

      final Map<String, dynamic> filters = {};
      if (lastSyncTimestamp != null && !forceRefresh) {
        filters['filters'] = [
          ["modified", ">", lastSyncTimestamp],
        ];
      }

      final url = uri;
      print('DEBUG: syncMyFollowups URL: $url');
      print('DEBUG: syncMyFollowups Headers: $headers');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response))
        return await FollowUpDatabase.getAllFollowUps();

      print('All followups response status: ${response.statusCode}');
      print('All followups response body: ${response.body}');

      if (response.statusCode == 200) {
        final FollowUpDatabase followUpDatabase = FollowUpDatabase();

        final List<FollowUp> localFollowups =
            await FollowUpDatabase.getAllFollowUps();
        final Set<String> localFollowupNames = localFollowups
            .map((f) => f.name)
            .toSet();

        final List<String> serverFollowupNamesList =
            await fetchFollowupNamesFromServer();
        final Set<String> serverFollowupNames = serverFollowupNamesList.toSet();

        final List<String> followupsToDelete = localFollowupNames
            .where((name) => !serverFollowupNames.contains(name))
            .toList();

        for (final followupName in followupsToDelete) {
          await FollowUpDatabase.deleteFollowUp(followupName);
          print('Deleted local follow-up: $followupName (no longer on server)');
        }

        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        print('All followups JSON data: $jsonData');
        final followups = jsonData
            .map((json) => FollowUp.fromJson(json))
            .toList();

        for (final followup in followups) {
          await FollowUpDatabase.upsertFollowUp(followup);
        }

        final now = DateTime.now();
        final formattedTimestamp =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
        await prefs.setString(
          _lastSyncFollowupsTimestampKey,
          formattedTimestamp,
        );

        return followups;
      } else {
        print(
          '❌ All followups error: ${response.statusCode} - ${response.body}',
        );
        return await FollowUpDatabase.getAllFollowUps();
      }
    } on http.ClientException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'syncMyFollowups',
        message: 'ClientException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ ClientException caught: $e');
      return await FollowUpDatabase.getAllFollowUps();
    } on FormatException catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'syncMyFollowups',
        message: 'FormatException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ FormatException caught: $e');
      return await FollowUpDatabase.getAllFollowUps();
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'syncMyFollowups',
        message: 'GeneralException: $e',
        stackTrace: stack.toString(),
      );
      print('❌ General exception caught: $e');
      return await FollowUpDatabase.getAllFollowUps();
    }
  }

  static Future<FollowUp?> fetchFollowUp(String followUpName) async {
    // 1. Try to return from local DB if offline
    if (!ConnectivityService.isOnline) {
      print('Offline: Loading follow-up $followUpName from local database');
      final localData = await FollowUpDatabase.getFollowUpByName(followUpName);
      if (localData != null) {
        return localData;
      }
      return null;
    }

    try {
      print(
        'Fetching follow-up $followUpName from: $baseUrl/api/resource/Lead FollowUps/$followUpName',
      );
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/resource/Lead%20FollowUps/$followUpName',
      );
      print('DEBUG: fetchFollowUp URL: $url');
      print('DEBUG: fetchFollowUp Headers: $headers');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return null;

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
        throw Exception(
          'Failed to fetch follow-up: ${response.statusCode} - ${response.body}',
        );
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

  static Future<bool> updateFollowUp(
    String followUpName,
    String status,
    String remarks, {
    String? nextFollowUp,
  }) async {
    if (!ConnectivityService.isOnline) return false;
    try {
      print(
        'Updating follow-up $followUpName with status: $status, remarks: $remarks, nextFollowUp: $nextFollowUp',
      );
      final headers = await AuthService.getHeaders();

      final Map<String, dynamic> body = {"status": status, "remarks": remarks};
      if (nextFollowUp != null && nextFollowUp.isNotEmpty) {
        body["next_follow_up"] = nextFollowUp;
      }

      final response = await _httpClient
          .put(
            Uri.parse('$baseUrl/api/resource/Lead%20FollowUps/$followUpName'),
            headers: headers,
            body: json.encode(body),
          )
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return false;

      print('Update follow-up response status: ${response.statusCode}');
      print('Update follow-up response body: ${response.body}');

      if (response.statusCode == 200) {
        return true;
      } else {
        print(
          '❌ Failed to update follow-up: ${response.statusCode} - ${response.body}',
        );
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
    if (!ConnectivityService.isOnline) {
      throw Exception(
        'Offline: Cannot create lead from form without internet connection.',
      );
    }
    try {
      final headers = await AuthService.getHeaders();
      final userData = await AuthService.getUserData();
      final owner = userData?['email'] ?? 'Administrator';

      final body = {
        'lead_owner': owner,
        'status': 'Lead',
        'custom_lead_status': 'New Lead',
        'custom_latest_visit_status': 'Visit Scheduled',
        'is_verified': 1,
        ...formData,
      };

      final bodyJson = jsonEncode(body);
      print('📤 [LeadService] Submitting lead to Frappe...');
      print('📦 [LeadService] Body: $bodyJson');

      final url = Uri.parse('$baseUrl/api/resource/Lead');
      final response = await _httpClient.post(
        url,
        headers: headers,
        body: bodyJson,
      );

      if (AuthService.checkResponse(response)) return null;

      print('📥 [LeadService] Response Status: ${response.statusCode}');
      print('📄 [LeadService] Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final leadData = responseData['data'] ?? responseData;
        print('✅ [LeadService] Lead created successfully: ${leadData['name']}');

        // Log EVERY SINGLE field returned to identify counter logic
        print('📋 [LeadService] Full Server Response Fields:');
        leadData.forEach((key, value) {
          print('  🔹 $key: $value');
        });

        return Lead.fromJson(leadData);
      } else {
        print('❌ [LeadService] Server Error: ${response.statusCode}');
        print('❌ [LeadService] Server Error Details: ${response.body}');
        
        String errorMessage = 'Server error: ${response.statusCode} - ${response.body}';
        try {
          final errorData = json.decode(response.body);
          if (errorData['exception'] != null) {
            final exceptionStr = errorData['exception'].toString();
            if (exceptionStr.contains('UniqueValidationError') || exceptionStr.contains('Duplicate entry')) {
               if (exceptionStr.contains('mobile_no')) {
                 errorMessage = 'A lead with this mobile number already exists.';
               } else if (exceptionStr.contains('email_id')) {
                 errorMessage = 'A lead with this email address already exists.';
               } else {
                 errorMessage = 'A lead with these details already exists (duplicate entry).';
               }
            } else if (errorData['exc_type'] != null) {
               if (errorData['exception'] != null) {
                 final rawMsg = errorData['exception'].toString();
                 final parts = rawMsg.split(': ');
                 if (parts.length > 1) {
                   errorMessage = parts.sublist(1).join(': ').replaceAll('<b>', '').replaceAll('</b>', '').trim();
                 } else {
                   errorMessage = rawMsg.replaceAll('<b>', '').replaceAll('</b>', '').trim();
                 }
               } else {
                 errorMessage = 'Validation Error: ${errorData['exc_type']}';
               }
            }
          }
        } catch (_) {
          // Fallback if parsing fails
        }

        throw Exception(errorMessage);
      }
    } on http.ClientException catch (e) {
      print('❌ [LeadService] ClientException: $e');
      throw Exception('Network error: Unable to connect to server at $baseUrl');
    } on FormatException catch (e) {
      print('❌ [LeadService] FormatException: $e');
      throw Exception('Data format error: Invalid response from server');
    } catch (e) {
      print('❌ [LeadService] General Exception: $e');
      if (e.toString().contains('TimeoutException')) {
        throw Exception(
          'Request timeout: Server is taking too long to respond',
        );
      }
      rethrow;
    }
  }

  static Future<List<String>> fetchFollowupNamesFromServer() async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await AuthService.getHeaders();
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_team_followups_list',
      );
      final url = uri;
      print('DEBUG: fetchFollowupNamesFromServer URL: $url');
      print('DEBUG: fetchFollowupNamesFromServer Headers: $headers');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toList();
      } else {
        print(
          '❌ Error fetching all followup names from server: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching all followup names from server: $e');
      return [];
    }
  }

  static Future<List<Lead>> getLeadsByChannelPartner(String partnerId) async {
    try {
      final List<Map<String, dynamic>> rawLeads = await LeadDatabase()
          .getAllLeads();
      return rawLeads
          .map((data) {
            final leadJson = json.decode(data['data']);
            return Lead.fromJson(leadJson);
          })
          .where((lead) => lead.customChannelPartner == partnerId)
          .toList();
    } catch (e) {
      print('Error getting leads by channel partner: $e');
      return [];
    }
  }

  static Future<String?> createFollowup(Map<String, dynamic> body) async {
    if (!ConnectivityService.isOnline) {
      return 'Offline: Cannot create follow-up without internet connection.';
    }
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.crm.create_followup',
      );
      final response = await _httpClient.post(
        url,
        headers: headers,
        body: jsonEncode(body),
      );

      if (AuthService.checkResponse(response)) return 'Session Expired';

      print('Create Follow-up response status: ${response.statusCode}');
      print('Create Follow-up response body: ${response.body}');

      if (response.statusCode == 200) {
        return null;
      } else {
        String message = 'Failed to create follow-up (${response.statusCode})';
        try {
          final data = jsonDecode(response.body);
          if (data['message'] != null) {
            message = data['message'].toString();
          } else if (data['_server_messages'] != null) {
            final List<dynamic> serverMsgs = jsonDecode(
              data['_server_messages'],
            );
            if (serverMsgs.isNotEmpty) {
              final Map<String, dynamic> firstMsg = jsonDecode(serverMsgs[0]);
              message = firstMsg['message'] ?? message;
            }
          }
        } catch (_) {}
        return message.split('\n').first;
      }
    } catch (e) {
      print('❌ General exception caught: $e');
      return 'Connection error. Please try again.';
    }
  }

  static Future<List<ActivityLog>> fetchLeadActivityLogs(String leadId) async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/method/homesol_app.api.crm.get_lead_activity_logs',
      );
      final response = await _httpClient
          .post(url, headers: headers, body: jsonEncode({'lead_id': leadId}))
          .timeout(const Duration(seconds: 15));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final dynamic message = responseData['message'];
        if (message is List) {
          return message.map((json) => ActivityLog.fromJson(json)).toList();
        } else {
          print('Activity logs message is not a List: $message');
          return [];
        }
      } else {
        print(
          'Failed to fetch activity logs for lead $leadId: ${response.statusCode} - ${response.body}',
        );
        return [];
      }
    } catch (e) {
      print('Error fetching activity logs for lead $leadId: $e');
      return [];
    }
  }

  static Future<void> clearAllCaches() async {
    print('Clearing all sync-related caches...');

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

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_lastSyncTimestampKey);
    await prefs.remove(_lastSyncFollowupsTimestampKey);

    await LeadDatabase().deleteAllLeads();
    await FollowUpDatabase.deleteAllFollowUps();
    await ChannelPartnerDatabase().deleteAllChannelPartners();
    await DeveloperDatabase().deleteAllDevelopers();
    await ProjectDatabase().deleteAllProjects();
    await SiteVisitDatabase.deleteAllSiteVisits();
    await SalesTeamDatabase().deleteAllSalesTeams();
    await UserProfileDatabase().deleteAllUserProfiles();
    await SourcingService.clearAllCaches(); // Add this

    print('All sync-related caches cleared successfully.');
  }

  static Future<List<String>> fetchEligibleTransferUsers() async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse(
        '$baseUrl/api/method/homesol_app.api.get_eligible_transfer_users',
      );
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['message'] is List) {
          return List<String>.from(data['message']);
        }
      }
      return [];
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchEligibleTransferUsers',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error fetching eligible transfer users: $e');
      return [];
    }
  }

  static String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  static Future<String?> performLeadTransfer(Map<String, dynamic> body) async {
    try {
      final headers = await AuthService.getHeaders();
      headers['Content-Type'] = 'application/json';

      final url = Uri.parse('$baseUrl/api/resource/Lead Transfer');

      final bodyJson = jsonEncode(body);
      print('DEBUG: [LeadService] performLeadTransfer URL: $url');
      print('DEBUG: [LeadService] performLeadTransfer Headers: $headers');
      print('DEBUG: [LeadService] performLeadTransfer Request Body: $bodyJson');

      final response = await _httpClient
          .post(url, headers: headers, body: bodyJson)
          .timeout(const Duration(seconds: 30));

      print(
        'DEBUG: [LeadService] performLeadTransfer Response Status: ${response.statusCode}',
      );
      print(
        'DEBUG: [LeadService] performLeadTransfer Response Body: ${response.body}',
      );

      if (AuthService.checkResponse(response))
        return 'Session expired or authentication failed.';

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('✅ Lead transfer successful');
        return null; // Success
      } else {
        print('❌ Lead transfer failed with status: ${response.statusCode}');

        String errorMessage = 'Failed to perform bulk transfer.';
        try {
          final Map<String, dynamic> errorData = jsonDecode(response.body);

          // Try to get message from _server_messages (often more descriptive)
          if (errorData.containsKey('_server_messages')) {
            final String serverMsgsStr = errorData['_server_messages'];
            final List<dynamic> serverMsgs = jsonDecode(serverMsgsStr);
            if (serverMsgs.isNotEmpty) {
              final Map<String, dynamic> msgObj = jsonDecode(serverMsgs.first);
              if (msgObj.containsKey('message')) {
                errorMessage = _stripHtml(msgObj['message']);
              }
            }
          } else if (errorData.containsKey('exception')) {
            // Fallback to exception string
            final String exc = errorData['exception'];
            if (exc.contains(':')) {
              errorMessage = _stripHtml(exc.split(':').last.trim());
            } else {
              errorMessage = _stripHtml(exc);
            }
          }
        } catch (e) {
          print('DEBUG: Error parsing error response: $e');
        }

        ErrorLogger.logError(
          logLevel: 'ERROR',
          module: 'LeadService',
          action: 'performLeadTransfer',
          message:
              'Status: ${response.statusCode} | Error: $errorMessage | Body: ${response.body}',
          showDialog: false, // Don't show crash dialog for validation errors
        );

        return errorMessage;
      }
    } catch (e, stack) {
      print('❌ DEBUG: performLeadTransfer caught exception: $e');
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'performLeadTransfer',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      return e.toString();
    }
  }

  static Future<Map<String, String>> getHeaders() async {
    return _getHeaders();
  }

  static Future<Map<String, String>> fetchLeadNames(
    List<String> leadIds,
  ) async {
    if (leadIds.isEmpty) return {};
    try {
      final headers = await AuthService.getHeaders();
      final filters = jsonEncode([
        ["name", "in", leadIds],
      ]);
      final url = Uri.parse(
        '$baseUrl/api/resource/Lead?filters=$filters&fields=["name","lead_name"]&limit_page_length=1000',
      );

      print('DEBUG: [fetchLeadNames] URL: $url');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));
      print(
        'DEBUG: [fetchLeadNames] Response: ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final items = data['data'] as List<dynamic>? ?? [];
        final Map<String, String> nameMap = {};
        for (var item in items) {
          final id = item['name']?.toString() ?? '';
          final leadName = item['lead_name']?.toString() ?? 'Unknown Lead';
          if (id.isNotEmpty) {
            nameMap[id] = leadName;
          }
        }
        return nameMap;
      }
      return {};
    } catch (e) {
      print('Error fetching lead names: $e');
      return {};
    }
  }

  static Future<LeadTransfer?> fetchLeadTransferDetail(String name) async {
    try {
      final headers = await AuthService.getHeaders();
      final url = Uri.parse('$baseUrl/api/resource/Lead Transfer/$name');
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (AuthService.checkResponse(response)) return null;

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] != null) {
          return LeadTransfer.fromJson(data['data']);
        }
      }
      return null;
    } catch (e) {
      print('Error fetching lead transfer detail: $e');
      return null;
    }
  }

  static Future<List<LeadTransfer>> fetchLeadTransfers() async {
    try {
      final headers = await AuthService.getHeaders();

      final userData = await AuthService.getUserData();
      final userEmail = userData?['email'];

      String filterParams = '';
      if (userEmail != null) {
        final filters = jsonEncode([
          ["owner", "=", userEmail],
        ]);
        filterParams = '&filters=$filters';
      }

      // Fetching all fields to get initial list
      final url = Uri.parse(
        '$baseUrl/api/resource/Lead Transfer?fields=["*"]$filterParams&order_by=creation desc',
      );
      final response = await _httpClient
          .get(url, headers: headers)
          .timeout(const Duration(seconds: 20));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        if (data['data'] is List) {
          final List<dynamic> items = data['data'];
          final List<LeadTransfer> basicList = items
              .map((item) => LeadTransfer.fromJson(item))
              .toList();

          // To fix the "0 leads" issue in list, we must fetch full details for each
          // Re-fetching full objects to include child tables (selected_leads)
          final List<LeadTransfer> enrichedList = [];
          for (var basic in basicList) {
            final full = await fetchLeadTransferDetail(basic.name);
            if (full != null) {
              enrichedList.add(full);
            } else {
              enrichedList.add(basic);
            }
          }
          return enrichedList;
        }
      }
      return [];
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'LeadService',
        action: 'fetchLeadTransfers',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      print('Error fetching lead transfers: $e');
      return [];
    }
  }

  static Future<bool> cancelLeadTransfer(String name) async {
    try {
      final headers = await AuthService.getHeaders();
      headers['Content-Type'] = 'application/json';

      final url = Uri.parse('$baseUrl/api/resource/Lead Transfer/$name');
      final response = await _httpClient
          .put(
            url,
            headers: headers,
            body: jsonEncode({
              "docstatus": 2,
            }), // docstatus 2 is Cancelled in Frappe
          )
          .timeout(const Duration(seconds: 20));

      if (AuthService.checkResponse(response)) return false;

      if (response.statusCode == 200) {
        print('✅ Lead transfer cancelled successfully');
        return true;
      } else {
        print(
          '❌ Failed to cancel lead transfer: ${response.statusCode} - ${response.body}',
        );
        return false;
      }
    } catch (e) {
      print('Error cancelling lead transfer: $e');
      return false;
    }
  }
}
