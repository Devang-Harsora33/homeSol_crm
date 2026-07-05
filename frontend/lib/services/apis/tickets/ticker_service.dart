import 'dart:convert';
import 'dart:io';
import 'package:Homesol/models/ticket.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/ticket_database.dart';
import 'package:Homesol/services/connectivity_service.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Homesol/utils/error_logger.dart';

class TicketService {
  static String get baseUrl => AuthService.baseUrl;
  static const String _lastSyncMyTicketsTimestampKey = "last_sync_timestamp_my_tickets";

  static Future<Map<String, String>> _getHeaders() async {
    final cookie = await AuthService.getCookie();
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (cookie != null && cookie.isNotEmpty) headers['Cookie'] = cookie;
    return headers;
  }

  // Helper to fetch all ticket names from server for deletion comparison
  static Future<List<String>> fetchTicketNamesFromServer() async {
    if (!ConnectivityService.isOnline) return [];
    try {
      final headers = await _getHeaders();
      final uri = Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_my_tickets');
      final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return [];

      if (response.statusCode == 200) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        return jsonData.map((json) => json['name'].toString()).toList();
      }
    } catch (_) {}
    return [];
  }

  // Create a new ticket
  static Future<Ticket> createTicket(Ticket ticket) async {
    if (!ConnectivityService.isOnline) throw Exception('Internet connection required to create a ticket.');
    try {
      final headers = await _getHeaders();
      final response = await http
          .post(
            Uri.parse('${AuthService.baseUrl}/api/resource/Tickets'),
            headers: headers,
            body: json.encode(ticket.toJson()),
          )
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) throw Exception('Session Expired');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = json.decode(response.body);
        final Map<String, dynamic> ticketData = responseData['data'];
        return Ticket.fromJson(ticketData);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'TicketService',
        action: 'createTicket',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
      throw Exception('Error creating ticket: $e');
    }
  }

  /// Upload a single attachment file to Firebase Storage and return the URL
  static Future<String> _uploadTicketFileToFirebase({
    required String ticketId,
    required File file,
  }) async {
    if (!ConnectivityService.isOnline) throw Exception('Internet connection required for upload.');
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
    if (attachmentUrls.isEmpty || !ConnectivityService.isOnline) return;
    final token = await AuthService.getCookie();
    final payload = {'attachments': attachmentUrls, 'urls': attachmentUrls};

    final response = await http
        .post(
          Uri.parse('${AuthService.baseUrl}/api/v1/brokers/$brokerId/tickets/$ticketId/attachments'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: json.encode(payload),
        )
        .timeout(const Duration(seconds: 20));

    if (AuthService.checkResponse(response)) return;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Failed attaching files: ${response.statusCode}');
    }
  }

  /// Convenience: upload local files to Firebase, then call backend attachment API
  static Future<List<String>> uploadAndAttachTicketFiles({
    required String brokerId,
    required String ticketId,
    required List<File> files,
  }) async {
    if (files.isEmpty || !ConnectivityService.isOnline) return [];
    final uploadedUrls = <String>[];
    for (final file in files) {
      try {
        final url = await _uploadTicketFileToFirebase(ticketId: ticketId, file: file);
        uploadedUrls.add(url);
      } catch (_) {}
    }
    if (uploadedUrls.isNotEmpty) {
      await addTicketAttachments(brokerId: brokerId, ticketId: ticketId, attachmentUrls: uploadedUrls);
    }
    return uploadedUrls;
  }

  // Fetch a specific ticket by ID
  static Future<Ticket> fetchTicket(String ticketId) async {
    // Check local DB first
    final localTickets = await TicketDatabase.getAllTickets();
    try {
      return localTickets.firstWhere((t) => t.id == ticketId);
    } catch (_) {}

    if (!ConnectivityService.isOnline) throw Exception('Internet connection required.');

    try {
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

      if (AuthService.checkResponse(response)) throw Exception('Session Expired');

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        return Ticket.fromJson(jsonData);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching ticket: $e');
    }
  }

  // Delete a ticket by ID
  static Future<void> deleteTicket(String ticketId) async {
    if (!ConnectivityService.isOnline) throw Exception('Internet connection required to delete.');
    final token = await AuthService.getCookie();
    final user = await AuthService.getUserData();
    final brokerId = user?['broker_id']?.toString();
    final uri = Uri.parse('$baseUrl/tickets/$ticketId').replace(
      queryParameters: brokerId != null && brokerId.isNotEmpty ? {'user_id': brokerId} : null,
    );

    final response = await http
        .delete(
          uri,
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
        )
        .timeout(const Duration(seconds: 15));

    if (AuthService.checkResponse(response)) return;

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Server error: ${response.statusCode}');
    }
    await TicketDatabase.deleteTicket(ticketId);
  }

  // Update ticket status (e.g., cancel)
  static Future<Ticket> updateTicketStatus({
    required String ticketId,
    required String status,
  }) async {
    if (!ConnectivityService.isOnline) throw Exception('Internet connection required to update.');
    final token = await AuthService.getCookie();
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

    if (AuthService.checkResponse(response)) throw Exception('Session Expired');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final jsonData = json.decode(response.body);
      final ticket = Ticket.fromJson(jsonData);
      await TicketDatabase.upsertTicket(ticket);
      return ticket;
    }
    throw Exception('Server error: ${response.statusCode}');
  }

  static Future<List<Ticket>> fetchMyTickets({bool forceRefresh = false}) async {
    try {
      final cachedTickets = await TicketDatabase.getAllTickets();
      if (cachedTickets.isNotEmpty && (!forceRefresh || !ConnectivityService.isOnline)) return cachedTickets;
    } catch (_) {}
    return await syncMyTickets(forceRefresh: forceRefresh);
  }

  static Future<List<Ticket>> syncMyTickets({bool forceRefresh = false}) async {
    if (!ConnectivityService.isOnline) return await TicketDatabase.getAllTickets();
    try {
      final prefs = await SharedPreferences.getInstance();
      final headers = await _getHeaders();
      final response = await http
          .get(
            Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_my_tickets'),
            headers: headers,
          )
          .timeout(const Duration(seconds: 30));

      if (AuthService.checkResponse(response)) return await TicketDatabase.getAllTickets();

      if (response.statusCode == 200) {
        // Deletion check
        final List<String> serverTicketNamesList = await fetchTicketNamesFromServer();
        if (serverTicketNamesList.isNotEmpty) {
          final Set<String> serverTicketNames = serverTicketNamesList.toSet();
          final List<Ticket> localTickets = await TicketDatabase.getAllTickets();
          for (final localT in localTickets) {
            if (!serverTicketNames.contains(localT.id)) await TicketDatabase.deleteTicket(localT.id);
          }
        }

        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final List<dynamic> jsonData = responseData['message'] ?? [];
        final tickets = jsonData.map((json) => Ticket.fromJson(json)).toList();
        for (final ticket in tickets) await TicketDatabase.upsertTicket(ticket);

        final now = DateTime.now();
        final formattedTimestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}.${now.microsecond.toString().padLeft(6, '0')}';
        await prefs.setString(_lastSyncMyTicketsTimestampKey, formattedTimestamp);

        return tickets;
      }
    } catch (e, stack) {
      ErrorLogger.logError(
        logLevel: 'ERROR',
        module: 'TicketService',
        action: 'syncMyTickets',
        message: e.toString(),
        stackTrace: stack.toString(),
      );
    }
    return await TicketDatabase.getAllTickets();
  }
}
