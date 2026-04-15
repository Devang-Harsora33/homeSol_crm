import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:Homesol/pages/home_page.dart';
import 'package:Homesol/services/analytics_service.dart';
import 'package:Homesol/services/shift_service.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/apis/user/user_service.dart';
import 'package:Homesol/models/project.dart';
import 'package:Homesol/models/developer.dart';
import 'package:Homesol/models/user_profile.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'home_page_enhanced_test.mocks.dart';

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
  late MockGeolocatorPlatform mockGeolocatorPlatform;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    mockHttpClientRequest = MockHttpClientRequest();
    mockHttpClientResponse = MockHttpClientResponse();
    mockHttpHeaders = MockHttpHeaders();
    
    AuthService.setTestValues(
      baseUrl: 'https://test.homesolindia.com',
      cookie: 'sid=test_session_id',
    );

    HttpOverrides.global = _TestHttpOverrides(mockHttpClient);

    mockGeolocatorPlatform = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocatorPlatform;

    // Default Stubbing HTTP
    when(mockHttpClient.getUrl(any)).thenAnswer((_) async => mockHttpClientRequest);
    when(mockHttpClient.postUrl(any)).thenAnswer((_) async => mockHttpClientRequest);
    when(mockHttpClient.openUrl(any, any)).thenAnswer((_) async => mockHttpClientRequest);
    when(mockHttpClientRequest.headers).thenReturn(mockHttpHeaders);
    when(mockHttpClientRequest.close()).thenAnswer((_) async => mockHttpClientResponse);
    when(mockHttpClientResponse.statusCode).thenReturn(200);
    when(mockHttpClientResponse.headers).thenReturn(mockHttpHeaders);
    
    // Default response: empty data
    when(mockHttpClientResponse.listen(any,
            onError: anyNamed('onError'),
            onDone: anyNamed('onDone'),
            cancelOnError: anyNamed('cancelOnError')))
        .thenAnswer((Invocation invocation) {
      final void Function(List<int>)? onData = invocation.positionalArguments[0];
      final void Function()? onDone = invocation.namedArguments[#onDone];
      final List<int> data = utf8.encode(jsonEncode({'data': [], 'message': {
        'name': 'test@test.com',
        'employee_name': 'Test User',
        'modified': DateTime.now().toIso8601String(),
      }}));
      onData?.call(data);
      onDone?.call();
      return MockStreamSubscription<List<int>>();
    });
  });

  tearDown(() {
    AuthService.clearTestValues();
    HttpOverrides.global = null;
  });

  Project createMockProject({String? location}) {
    return Project(
      id: 'PROJ001',
      projectName: 'Test Project',
      developer: 'DEV001',
      mandate: 'MAND001',
      reraId: 'RERA123',
      constructionStatus: 'Ready to Move',
      propertyType: 'Residential',
      description: 'Test Description',
      projectRm: 'RM001',
      locationName: 'Test Location',
      city: 'Test City',
      state: 'Test State',
      nearbyLandmarks: 'Test Landmark',
      projectApproval: 'Approved',
      developmentScheme: 'None',
      priceRangeMin: 1000000,
      priceRangeMax: 5000000,
      parkingType: 'Covered',
      launchDate: '2023-01-01',
      possessionDate: '2025-01-01',
      targetPossession: '2025-01-01',
      architect: 'Test Architect',
      contractor: 'Test Contractor',
      electricalContractor: 'Test Elec Contractor',
      reraLiasoning: 'Test RERA',
      documents: [],
      configurations: [],
      galleryImages: [],
      amenities: [],
      brokerageSlabs: [],
      projectTimeline: [],
      creation: '2023-01-01',
      modified: '2023-01-01',
      location: location ?? jsonEncode({
        'features': [
          {
            'geometry': {
              'coordinates': [72.8777, 19.0760]
            }
          }
        ]
      }),
    );
  }

  testWidgets('HomePage initial state and UI elements', (WidgetTester tester) async {
    final projects = [createMockProject()];
    
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          projects: projects,
          developers: const [],
          appAssets: const [],
          onRefresh: () async {},
          initialAttendanceStatus: 'OUT',
          employeeId: 'EMP001',
          userShift: const {
            'start_time': '09:00:00',
            'end_time': '18:00:00',
          },
        ),
      ),
    );

    await tester.pump(); 
    expect(find.text('HomeSol'), findsOneWidget);
    expect(find.text('You are Clocked Out'), findsOneWidget);
    expect(find.text('Test Project'), findsOneWidget);
  });

  testWidgets('Location Range Check', (WidgetTester tester) async {
    final now = DateTime.now();
    final startTime = '${(now.hour - 1).toString().padLeft(2, '0')}:00:00';
    final endTime = '${(now.hour + 1).toString().padLeft(2, '0')}:00:00';

    mockGeolocatorPlatform.mockDistance = 10000.0;

    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          projects: [createMockProject()],
          developers: const [],
          appAssets: const [],
          onRefresh: () async {},
          initialAttendanceStatus: 'OUT',
          employeeId: 'EMP001',
          userShift: {
            'start_time': startTime,
            'end_time': endTime,
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Check In'));
    await tester.pumpAndSettle();

    expect(find.textContaining('You are out of range'), findsOneWidget);
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

class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  
  double mockDistance = 0.0;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    return Position(
      latitude: 19.0760,
      longitude: 72.8777,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 1.0,
      heading: 1.0,
      speed: 1.0,
      speedAccuracy: 1.0,
      altitudeAccuracy: 1.0,
      headingAccuracy: 1.0,
    );
  }

  @override
  double distanceBetween(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return mockDistance;
  }
}
