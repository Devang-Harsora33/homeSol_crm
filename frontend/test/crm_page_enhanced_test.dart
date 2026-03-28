import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:Homesol/pages/crm_page.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/models/lead.dart';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/models/site_visit.dart';
import 'package:Homesol/services/databases/lead_database.dart';
import 'package:Homesol/services/databases/project_database.dart';
import 'package:Homesol/services/databases/site_visit_database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'crm_page_enhanced_test.mocks.dart';

@GenerateNiceMocks([
  MockSpec<HttpClient>(),
  MockSpec<HttpClientRequest>(),
  MockSpec<HttpClientResponse>(),
  MockSpec<HttpHeaders>(),
])
void main() {
  late MockHttpClient mockHttpClient;
  late MockHttpClientRequest mockHttpClientRequest;
  late MockHttpClientResponse mockHttpClientResponse;
  late MockHttpHeaders mockHttpHeaders;

  late Database leadDb;
  late Database projectDb;
  late Database siteVisitDb;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    mockHttpClient = MockHttpClient();
    mockHttpClientRequest = MockHttpClientRequest();
    mockHttpClientResponse = MockHttpClientResponse();
    mockHttpHeaders = MockHttpHeaders();

    HttpOverrides.global = _TestHttpOverrides(mockHttpClient);
    
    // Also set a MockClient for LeadService if it uses http.Client internally
    final mockClient = MockClient((request) async {
      return http.Response(jsonEncode({'message': [], 'data': []}), 200);
    });
    LeadService.setTestClient(mockClient);

    AuthService.setTestValues(
      baseUrl: 'https://test.homesolindia.com',
      cookie: 'sid=test_session_id',
    );

    SharedPreferences.setMockInitialValues({
      'user_data': jsonEncode({'broker_id': 'BROKER001', 'email': 'test@test.com'}),
    });

    // In-memory databases
    leadDb = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
      await db.execute('CREATE TABLE leads(name TEXT PRIMARY KEY, modified TEXT, data TEXT)');
    });
    LeadDatabase.setDatabaseForTesting(leadDb);

    projectDb = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
      await db.execute('CREATE TABLE projects(name TEXT PRIMARY KEY, modified TEXT, data TEXT)');
    });
    ProjectDatabase.setDatabaseForTesting(projectDb);

    siteVisitDb = await openDatabase(inMemoryDatabasePath, version: 1, onCreate: (db, version) async {
      await db.execute('CREATE TABLE site_visits(id TEXT PRIMARY KEY, modified TEXT, data TEXT)');
    });
    SiteVisitDatabase.setDatabaseForTesting(siteVisitDb);

    // Default HTTP stubs
    when(mockHttpClient.openUrl(any, any)).thenAnswer((_) async => mockHttpClientRequest);
    when(mockHttpClient.getUrl(any)).thenAnswer((_) async => mockHttpClientRequest);
    when(mockHttpClient.postUrl(any)).thenAnswer((_) async => mockHttpClientRequest);
    when(mockHttpClientRequest.close()).thenAnswer((_) async => mockHttpClientResponse);
    when(mockHttpClientResponse.statusCode).thenReturn(200);
    when(mockHttpClientResponse.headers).thenReturn(mockHttpHeaders);
    when(mockHttpClientResponse.listen(any,
            onError: anyNamed('onError'),
            onDone: anyNamed('onDone'),
            cancelOnError: anyNamed('cancelOnError')))
        .thenAnswer((Invocation invocation) {
      final void Function(List<int>)? onData = invocation.positionalArguments[0];
      final void Function()? onDone = invocation.namedArguments[#onDone];
      onData?.call(utf8.encode(jsonEncode({'data': [], 'message': []})));
      onDone?.call();
      return MockStreamSubscription<List<int>>();
    });
  });

  tearDown(() async {
    AuthService.clearTestValues();
    HttpOverrides.global = null;
    LeadService.setTestClient(null);
    LeadDatabase.setDatabaseForTesting(null);
    ProjectDatabase.setDatabaseForTesting(null);
    SiteVisitDatabase.setDatabaseForTesting(null);
    await leadDb.close();
    await projectDb.close();
    await siteVisitDb.close();
  });

  Lead createMockLead({required String id, required String name, String status = 'Open'}) {
    return Lead(
      id: id,
      name: id,
      leadName: name,
      customerName: name,
      customerPhone: '1234567890',
      brokerId: 'BROKER001',
      projectId: ['PROJ001'],
      status: status,
      budget: 10000000,
      customLeadStatus: status,
      createdAt: DateTime.now(),
      modified: DateTime.now(),
      notes: [],
    );
  }

  testWidgets('CRMPage initial state and loading leads', (WidgetTester tester) async {
    final mockLead = createMockLead(id: 'LEAD001', name: 'John Doe');
    final leadJson = mockLead.toJson();
    await LeadDatabase().upsertLead({
      'name': mockLead.id,
      'modified': DateTime.now().toIso8601String(),
      ...leadJson,
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CRMPage(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('CRM'), findsOneWidget);
    expect(find.text('John Doe'), findsOneWidget);
  });

  testWidgets('CRMPage search functionality', (WidgetTester tester) async {
    final lead1 = createMockLead(id: 'LEAD001', name: 'John Doe');
    final lead2 = createMockLead(id: 'LEAD002', name: 'Jane Smith');
    
    await LeadDatabase().upsertLead({
      'name': lead1.id,
      'modified': DateTime.now().toIso8601String(),
      ...lead1.toJson(),
    });
    await LeadDatabase().upsertLead({
      'name': lead2.id,
      'modified': DateTime.now().toIso8601String(),
      ...lead2.toJson(),
    });

    await tester.pumpWidget(
      const MaterialApp(
        home: CRMPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'John');
    await tester.pumpAndSettle();

    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('Jane Smith'), findsNothing);
  });

  testWidgets('CRMPage filter bottom sheet opens', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CRMPage(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.tune));
    await tester.pumpAndSettle();

    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Apply Filters'), findsOneWidget);
  });
}

class _TestHttpOverrides extends HttpOverrides {
  final HttpClient client;
  _TestHttpOverrides(this.client);
  @override
  HttpClient createHttpClient(SecurityContext? context) => client;
}

class MockStreamSubscription<T> extends Mock implements StreamSubscription<T> {
  @override
  Future<void> cancel() async {}
}
