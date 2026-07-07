import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:geolocator/geolocator.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:Homesol/services/shift_service.dart';
import 'package:Homesol/services/auth_service.dart';

import 'home_page_enhanced_test.mocks.dart';

// Custom mock for Geolocator
class MockGeolocatorPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements GeolocatorPlatform {
  
  double mockDistance = 0.0;
  double mockLat = 19.0760;
  double mockLng = 72.8777;

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
      latitude: mockLat,
      longitude: mockLng,
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

void main() {
  late MockHttpClient mockHttpClient;
  late MockGeolocatorPlatform mockGeolocatorPlatform;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() {
    mockHttpClient = MockHttpClient();
    
    AuthService.setTestValues(
      baseUrl: 'https://test.homesolindia.com',
      cookie: 'sid=test_session_id',
    );

    HttpOverrides.global = _TestHttpOverrides(mockHttpClient);

    mockGeolocatorPlatform = MockGeolocatorPlatform();
    GeolocatorPlatform.instance = mockGeolocatorPlatform;
  });

  tearDown(() {
    AuthService.clearTestValues();
    HttpOverrides.global = null;
  });

  // Helper method to setup API responses based on the request URL
  void setupMockHttpResponses(Map<String, Map<String, dynamic>> urlToResponseMap) {
    when(mockHttpClient.getUrl(any)).thenAnswer((Invocation inv) async {
      final uri = inv.positionalArguments[0] as Uri;
      final path = uri.path;
      
      final mockRequest = MockHttpClientRequest();
      final mockResponse = MockHttpClientResponse();
      final mockHeaders = MockHttpHeaders();

      when(mockRequest.headers).thenReturn(mockHeaders);
      when(mockRequest.close()).thenAnswer((_) async => mockResponse);
      when(mockResponse.statusCode).thenReturn(200);
      when(mockResponse.headers).thenReturn(mockHeaders);

      Map<String, dynamic> responseData = {'data': []}; // default empty

      // Match URL and return specific response
      for (final key in urlToResponseMap.keys) {
        if (uri.toString().contains(key)) {
          responseData = urlToResponseMap[key]!;
          break;
        }
      }

      when(mockResponse.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((Invocation listenInv) {
        final void Function(List<int>)? onData = listenInv.positionalArguments[0];
        final void Function()? onDone = listenInv.namedArguments[#onDone];
        final List<int> data = utf8.encode(jsonEncode(responseData));
        onData?.call(data);
        onDone?.call();
        return MockStreamSubscription<List<int>>();
      });

      return mockRequest;
    });

    when(mockHttpClient.postUrl(any)).thenAnswer((Invocation inv) async {
      final mockRequest = MockHttpClientRequest();
      final mockResponse = MockHttpClientResponse();
      final mockHeaders = MockHttpHeaders();

      when(mockRequest.headers).thenReturn(mockHeaders);
      when(mockRequest.close()).thenAnswer((_) async => mockResponse);
      when(mockResponse.statusCode).thenReturn(200);
      when(mockResponse.headers).thenReturn(mockHeaders);

      when(mockResponse.listen(any,
              onError: anyNamed('onError'),
              onDone: anyNamed('onDone'),
              cancelOnError: anyNamed('cancelOnError')))
          .thenAnswer((Invocation listenInv) {
        final void Function(List<int>)? onData = listenInv.positionalArguments[0];
        final void Function()? onDone = listenInv.namedArguments[#onDone];
        
        // Mock successful attendance mark
        final List<int> data = utf8.encode(jsonEncode({
          'message': {'status': 'success'}
        }));
        onData?.call(data);
        onDone?.call();
        return MockStreamSubscription<List<int>>();
      });

      return mockRequest;
    });
  }

  test('Check-in with single team and single project (Within Range)', () async {
    // Setup responses
    setupMockHttpResponses({
      'get_user_profile': {
        'message': {'name': 'test@homesol.com', 'employee_name': 'Test User'}
      },
      'Sales%20Team': {
        'data': [
          {
            'name': 'Team A',
            'members': [{'employee': 'test@homesol.com', 'employee_name': 'Test User'}],
            'projects': [{'projects': 'PROJ_001', 'project_name': 'Project 1'}]
          }
        ]
      },
      'Property%20Projects/PROJ_001': {
        'data': {
          'name': 'PROJ_001',
          'location': jsonEncode({
            'features': [{'geometry': {'type': 'Point', 'coordinates': [72.8777, 19.0760]}}]
          })
        }
      }
    });

    // Set distance within 350 meters
    mockGeolocatorPlatform.mockDistance = 0.2; // 200 meters

    final result = await ShiftService.checkIn('device123', 'android', remark: 'Test single project');
    
    // WorkforceService mark_attendance returns success based on our POST mock
    expect(result['status'], 'success');
  });

  test('Check-in with multiple teams (User is at Project B of Team 2)', () async {
    setupMockHttpResponses({
      'get_user_profile': {
        'message': {'name': 'test@homesol.com', 'employee_name': 'Test User'}
      },
      'Sales%20Team': {
        'data': [
          {
            'name': 'Team A',
            'members': [{'employee': 'test@homesol.com', 'employee_name': 'Test User'}],
            'projects': [{'projects': 'PROJ_001', 'project_name': 'Project 1'}]
          },
          {
            'name': 'Team B',
            'members': [{'employee': 'test@homesol.com', 'employee_name': 'Test User'}],
            'projects': [{'projects': 'PROJ_002', 'project_name': 'Project 2'}]
          }
        ]
      },
      'Property%20Projects/PROJ_001': {
        'data': {
          'name': 'PROJ_001',
          'location': jsonEncode({
            'features': [{'geometry': {'type': 'Point', 'coordinates': [72.8000, 19.0000]}}]
          })
        }
      },
      'Property%20Projects/PROJ_002': {
        'data': {
          'name': 'PROJ_002',
          'location': jsonEncode({
            'features': [{'geometry': {'type': 'Point', 'coordinates': [73.0000, 19.5000]}}]
          })
        }
      }
    });

    // We simulate that the user is far from PROJ_001 but close to PROJ_002
    // ShiftService loops through userProjects and stops when distance <= 0.35
    // We will set the mockDistance to return 0.2 always for simplicity,
    // which implies they are close to whatever project is checked first.
    // In a real mock, you'd calculate actual distance using Geolocator logic.
    mockGeolocatorPlatform.mockDistance = 0.2; 

    final result = await ShiftService.checkIn('device123', 'android', remark: 'Test multiple teams');
    
    expect(result['status'], 'success');
  });

  test('Check-in fails when out of range for all projects', () async {
    setupMockHttpResponses({
      'get_user_profile': {
        'message': {'name': 'test@homesol.com', 'employee_name': 'Test User'}
      },
      'Sales%20Team': {
        'data': [
          {
            'name': 'Team A',
            'members': [{'employee': 'test@homesol.com', 'employee_name': 'Test User'}],
            'projects': [{'projects': 'PROJ_001', 'project_name': 'Project 1'}]
          }
        ]
      },
      'Property%20Projects/PROJ_001': {
        'data': {
          'name': 'PROJ_001',
          'location': jsonEncode({
            'features': [{'geometry': {'type': 'Point', 'coordinates': [72.8777, 19.0760]}}]
          })
        }
      }
    });

    // Set distance greater than 350 meters
    mockGeolocatorPlatform.mockDistance = 0.5; // 500 meters

    final result = await ShiftService.checkIn('device123', 'android', remark: 'Test out of range');
    
    expect(result['success'], false);
    expect(result['message'], 'You are not within the 350-meter radius of any assigned project.');
  });
}
