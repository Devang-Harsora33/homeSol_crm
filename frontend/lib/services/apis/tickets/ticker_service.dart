import 'dart:convert';
import 'dart:io';
import 'package:Homesol/models/ticket.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/ticket_database.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TicketService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncTicketsTimestampKey = "last_sync_timestamp_tickets";
  static const String _lastSyncMyTicketsTimestampKey = "last_sync_timestamp_my_tickets";

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  // Helper to fetch all ticket names from server for deletion comparison
  static Future<List<String>> fetchTicketNamesFromServer() async {
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse(
        '${AuthService.baseUrl}/api/method/homesol_app.api.get_my_tickets',
      );

      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toList();
      } else {
        print('❌ Error fetching all ticket names from server: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('❌ Exception fetching all ticket names from server: $e');
      return [];
    }
  }

  // Create a new ticket
  static Future<Ticket> createTicket(Ticket ticket) async {
    try {
      print('🔍 Creating ticket with data: ${ticket.toJson()}');
      print('🔍 Using endpoint: ${AuthService.baseUrl}/api/resource/Tickets');

      final headers = await _getHeaders();

      final response = await http
          .post(
            Uri.parse('${AuthService.baseUrl}/api/resource/Tickets'),
            headers: headers,
            body: json.encode(ticket.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      print('✅ Ticket creation response status: ${response.statusCode}');
      print('📄 Ticket creation response body: ${response.body}');
      print('📄 Ticket creation response headers: ${response.headers}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> ticketData = responseData['data'];
        print('📊 Created ticket JSON data: $ticketData');
        return Ticket.fromJson(ticketData);
      } else {
        print('❌ Ticket creation failed with status: ${response.statusCode}');
        print('❌ Response body: ${response.body}');
        throw Exception(
          'Server error: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ Error creating ticket: $e');
      print('❌ Error type: ${e.runtimeType}');
      throw Exception('Error creating ticket: $e');
    }
  }

  /// Upload a single attachment file to Firebase Storage and return the URL
  static Future<String> _uploadTicketFileToFirebase({
    required String ticketId,
    required File file,
  }) async {
    final String fileName = file.path.split('/').last;
    final String storagePath =
        'HomeSolBrokerConnect/tickets/$ticketId/attachments/${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final ref = FirebaseStorage.instance.ref().child(storagePath);
    final uploadTask = await ref.putFile(file);
    final String downloadUrl = await uploadTask.ref.getDownloadURL();
    return downloadUrl;
  }

  /// Notify backend to attach uploaded URLs to a ticket
  static Future<void> addTicketAttachments({
    required String brokerId,
    required String ticketId,
    required List<String> attachmentUrls,
  }) async {
    if (attachmentUrls.isEmpty) return;
    final token = await AuthService.getCookie();

    final payload = {
      // include multiple possible keys for compatibility with backend expectations
      'attachments': attachmentUrls,
      'urls': attachmentUrls,
    };

    final response = await http
        .post(
          Uri.parse(
            '${AuthService.baseUrl}/api/v1/brokers/$brokerId/tickets/$ticketId/attachments',
          ),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Failed attaching files (status: ${response.statusCode}) - ${response.body}',
      );
    }
  }

  /// Convenience: upload local files to Firebase, then call backend attachment API
  static Future<List<String>> uploadAndAttachTicketFiles({
    required String brokerId,
    required String ticketId,
    required List<File> files,
  }) async {
    if (files.isEmpty) return [];
    final uploadedUrls = <String>[];
    for (final file in files) {
      try {
        final url = await _uploadTicketFileToFirebase(
          ticketId: ticketId,
          file: file,
        );
        uploadedUrls.add(url);
      } catch (e) {
        // continue uploading remaining files; report after
      }
    }
    if (uploadedUrls.isNotEmpty) {
      await addTicketAttachments(
        brokerId: brokerId,
        ticketId: ticketId,
        attachmentUrls: uploadedUrls,
      );
    }
    return uploadedUrls;
  }

  // Fetch a specific ticket by ID
  static Future<Ticket> fetchTicket(String ticketId) async {
    try {
      print('Fetching ticket: $baseUrl/tickets/$ticketId');

      final token = await AuthService.getCookie();
      final response = await http
          .get(
            Uri.parse('$baseUrl/tickets/$ticketId'),
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 30));

      print('Ticket response status: ${response.statusCode}');
      print('Ticket response body: ${response.body}');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Ticket.fromJson(jsonData);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching ticket: $e');
      throw Exception('Error fetching ticket: $e');
    }
  }

  // Delete a ticket by ID
  static Future<void> deleteTicket(String ticketId) async {
    final token = await AuthService.getCookie();
    final user = await AuthService.getUserData();
    final brokerId = user?['broker_id']?.toString();
    final uri = Uri.parse('$baseUrl/tickets/$ticketId').replace(
      queryParameters: brokerId != null && brokerId.isNotEmpty
          ? {'user_id': brokerId}
          : null,
    );

    print('🔍 Deleting ticket: ${uri.toString()}');
    print('🔍 Auth token available: ${token != null ? 'Yes' : 'No'}');

    final response = await http
        .delete(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    print('✅ Delete response status: ${response.statusCode}');
    print('📄 Delete response body: ${response.body}');

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
        'Server error: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Update ticket status (e.g., cancel)
  static Future<Ticket> updateTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    final token = await AuthService.getCookie();
    // Use generic tickets URL per spec
    final response = await http
        .put(
          Uri.parse('$baseUrl/tickets/$ticketId'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode({'status': status}),
        )
        .timeout(const Duration(seconds: 15));

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonData = json.decode(response.body);
      return Ticket.fromJson(jsonData);
    }
    throw Exception('Server error: ${response.statusCode} - ${response.body}');
  }

  static Future<List<Ticket>> fetchMyTickets({bool forceRefresh = false}) async {
    // Load from local database first
    try {
      final cachedTickets = await TicketDatabase.getAllTickets();
      if (cachedTickets.isNotEmpty && !forceRefresh) {
        print('Returning cached my tickets from database');
        return cachedTickets;
      }
    } catch (e) {
      print('Error loading from database: $e');
    }

    // Sync from API if DB is empty or forceRefresh is true
    return await syncMyTickets(forceRefresh: forceRefresh);
  }

  static Future<List<Ticket>> syncMyTickets({bool forceRefresh = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSyncTimestamp = prefs.getString(_lastSyncMyTicketsTimestampKey);

      print(
        'Syncing my tickets from: ${AuthService.baseUrl}/api/method/homesol_app.api.get_my_tickets',
      );
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse(
              '${AuthService.baseUrl}/api/method/homesol_app.api.get_my_tickets',
            ),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        // --- Deletion Handling Start ---
        // Step 1: Get all local Ticket IDs
        final List<Ticket> localTickets = await TicketDatabase.getAllTickets();
        final Set<String> localTicketNames = localTickets.map((t) => t.id).toSet(); // Assuming 'id' is the unique identifier

        // Step 2: Get all active server Ticket IDs
        final List<String> serverTicketNamesList = await fetchTicketNamesFromServer();
        final Set<String> serverTicketNames = serverTicketNamesList.toSet();

        // Step 3: Identify tickets to delete locally
        final List<String> ticketsToDelete = localTicketNames
            .where((name) => !serverTicketNames.contains(name))
            .toList();

        // Step 4: Delete identified tickets from local database
        for (final ticketName in ticketsToDelete) {
          await TicketDatabase.deleteTicket(ticketName);
          print('Deleted local ticket: $ticketName (no longer on server)');
        }
        // --- Deletion Handling End ---

        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];

        final tickets = jsonData.map((json) => Ticket.fromJson(json)).toList();

        // Store in database
        for (final ticket in tickets) {
          await TicketDatabase.upsertTicket(ticket);
        }

        // Update last sync timestamp
        final now = DateTime.now();
        final formattedTimestamp =
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
        await prefs.setString(_lastSyncMyTicketsTimestampKey, formattedTimestamp);

        return tickets;
      } else {
        print('❌ My tickets error: ${response.statusCode} - ${response.body}');
        return await TicketDatabase.getAllTickets();
      }
    } on http.ClientException catch (e) {
      print('❌ ClientException caught: $e');
      return await TicketDatabase.getAllTickets();
    } on FormatException catch (e) {
      print('❌ FormatException caught: $e');
      return await TicketDatabase.getAllTickets();
    } catch (e) {
      print('❌ General exception caught: $e');
      return await TicketDatabase.getAllTickets();
    }
  }



}