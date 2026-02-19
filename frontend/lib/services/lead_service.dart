import 'dart:convert';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class LeadService {
  static String get _baseUrl => AuthService.baseUrl;

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
    final response = await http.post(
      Uri.parse('$_baseUrl/api/method/homesol_app.api.crm.trigger_otp_lead'),
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
    final response = await http.post(
      Uri.parse('$_baseUrl/api/method/homesol_app.api.crm.verify_otp_lead'),
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

  static Future<bool> markLeadAsLost(String leadId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.put(
        Uri.parse('$_baseUrl/api/resource/Lead/$leadId'),
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


}
