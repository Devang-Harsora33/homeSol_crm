import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../auth_service.dart';
import '../../../models/finance/construction_finance_application.dart';

class FinanceService {
  static Future<Map<String, dynamic>?> submitConstructionFinanceApplication(Map<String, dynamic> data) async {
    try {
      final cookie = await AuthService.getCookie();
      final headers = {
        'Content-Type': 'application/json',
        'Cookie': cookie ?? '',
      };

      final url = Uri.parse('${AuthService.baseUrl}/api/resource/Construction Finance Application');

      final response = await http.post(
        url,
        headers: headers,
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        print('Error submitting finance application: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to submit application: ${response.body}');
      }
    } catch (e) {
      print('Error submitting construction finance application: $e');
      throw Exception('Failed to connect to server: $e');
    }
  }

  static Future<List<ConstructionFinanceApplication>> fetchConstructionFinanceApplications(String developerId) async {
    try {
      final cookie = await AuthService.getCookie();
      final url = Uri.parse('${AuthService.baseUrl}/api/method/homesol_app.api.get_my_construction_finance_applications');

      final response = await http.get(
        url,
        headers: {
          'Cookie': cookie ?? '',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> records = data['message'] ?? [];
        return records.map((e) => ConstructionFinanceApplication.fromJson(e)).toList();
      } else {
        print('Error fetching applications: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch applications: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching applications: $e');
      throw Exception('Failed to connect to server: $e');
    }
  }

  static Future<ConstructionFinanceApplication> fetchConstructionFinanceApplicationDetails(String name) async {
    try {
      final cookie = await AuthService.getCookie();
      final url = Uri.parse('${AuthService.baseUrl}/api/resource/Construction Finance Application/$name');

      final response = await http.get(
        url,
        headers: {
          'Cookie': cookie ?? '',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return ConstructionFinanceApplication.fromJson(data['data']);
      } else {
        print('Error fetching application details: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to fetch application details: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching application details: $e');
      throw Exception('Failed to connect to server: $e');
    }
  }
}
