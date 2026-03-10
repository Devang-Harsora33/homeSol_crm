import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Homesol/models/lead.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/lead_database.dart';
import 'package:Homesol/services/databases/follow_up_database.dart';
import 'package:Homesol/services/databases/channel_partner_database.dart';
import 'package:Homesol/services/databases/developer_database.dart';
import 'package:Homesol/services/databases/project_database.dart';
import 'package:Homesol/services/databases/site_visit_database.dart';
import 'package:Homesol/services/databases/sales_team_database.dart';
import 'package:Homesol/services/databases/user_profile_database.dart';

// Mocks
class MockHttpClient extends Mock implements http.Client {}
class MockAuthService extends Mock implements AuthService {}
class MockSharedPreferences extends Mock implements SharedPreferences {}
class MockLeadDatabase extends Mock implements LeadDatabase {}
class MockFollowUpDatabase extends Mock implements FollowUpDatabase {}
class MockChannelPartnerDatabase extends Mock implements ChannelPartnerDatabase {}
class MockDeveloperDatabase extends Mock implements DeveloperDatabase {}
class MockProjectDatabase extends Mock implements ProjectDatabase {}
class MockSiteVisitDatabase extends Mock implements SiteVisitDatabase {}
class MockSalesTeamDatabase extends Mock implements SalesTeamDatabase {}
class MockUserProfileDatabase extends Mock implements UserProfileDatabase {}


void main() {
  group('LeadService', () {
    late MockHttpClient mockHttpClient;
    late MockSharedPreferences mockSharedPreferences;
    late MockLeadDatabase mockLeadDatabase;
    late LeadService leadService;

    // A dummy base URL for testing
    const String testBaseUrl = 'http://localhost:8080';
    const String testCookie = 'sid=test_session_id';
    final Map<String, dynamic> testUserData = {'email': 'test@example.com'};

    setUp(() {
      mockHttpClient = MockHttpClient();
      mockSharedPreferences = MockSharedPreferences();
      mockLeadDatabase = MockLeadDatabase();

      // Clear and set AuthService test values
      AuthService.clearTestValues();
      AuthService.setTestValues(
        baseUrl: testBaseUrl,
        cookie: testCookie,
        userData: testUserData,
      );

      // Inject mocked dependencies
      LeadService.setTestClient(mockHttpClient); // Inject mock for static methods
      leadService = LeadService(client: mockHttpClient); // Inject mock for instance methods
    });

    tearDown(() {
      AuthService.clearTestValues(); // Clean up AuthService static state after each test
      LeadService.setTestClient(null); // Clean up LeadService static client after each test
    });

    test('getHeaders returns correct headers with cookie', () async {
      final headers = await AuthService.getHeaders();
      expect(headers, {
        'Content-Type': 'application/json',
        'Cookie': testCookie,
      });
    });

    test('fetchBrokerLeads returns a list of leads on success', () async {
      final leadJson = {
        "name": "LEAD-00001",
        "owner": "test@example.com",
        "creation": "2023-01-01 10:00:00",
        "modified": "2023-01-01 10:00:00",
        "modified_by": "test@example.com",
        "docstatus": 0,
        "idx": 0,
        "naming_series": "LEAD-",
        "first_name": "Test",
        "last_name": "Lead",
        "lead_name": "Test Lead",
        "lead_owner": "broker1@example.com",
        "status": "New",
        "customer_phone": "1234567890",
        "brokerId": "broker1@example.com",
        "projectId": ["PROJ-001"],
        "budget": 500000,
      };
      final mockResponse = http.Response(json.encode([leadJson]), 200);

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/Lead/?filters=[["lead_owner","=","broker1@example.com"]]'), // Exact Uri for diagnosis
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockResponse);

      final leads = await LeadService.fetchBrokerLeads('broker1@example.com');

      expect(leads.length, 1);
      expect(leads[0].name, 'LEAD-00001');
      expect(leads[0].customerName, 'Test Lead');
      expect(leads[0].customerPhone, '1234567890');
    });

    test('fetchBrokerLeads throws exception on API error', () async {
      final mockResponse = http.Response('Server Error', 500);

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/Lead/?filters=[["lead_owner","=","broker1@example.com"]]'), // Exact Uri for diagnosis - Temporary
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockResponse);

      expect(
        () => LeadService.fetchBrokerLeads('broker1@example.com'),
        throwsA(isA<Exception>().having(
          (e) => e.toString(),
          'message',
          contains('Server error: 500 - Server Error'),
        )),
      );
    });
  });
}
