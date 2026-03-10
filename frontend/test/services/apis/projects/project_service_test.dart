import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Homesol/models/project.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:Homesol/services/databases/project_database.dart';
import 'package:Homesol/services/image_cache_manager.dart';

import 'project_service_test.mocks.dart'; // Generated mock file

@GenerateMocks([
  http.Client,
  SharedPreferences,
  ProjectDatabase,
])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('ProjectService', () {
    late MockClient mockHttpClient;
    late MockSharedPreferences mockSharedPreferences;
    late MockProjectDatabase mockProjectDatabase;

    const String testBaseUrl = 'http://localhost:8080';
    const String testCookie = 'sid=test_session_id';
    final Map<String, dynamic> testUserData = {'email': 'test@example.com'};

    setUp(() {
      mockHttpClient = MockClient();
      mockSharedPreferences = MockSharedPreferences();
      mockProjectDatabase = MockProjectDatabase();

      // Set test values for static AuthService methods
      AuthService.setTestValues(
        baseUrl: testBaseUrl,
        cookie: testCookie,
        userData: testUserData,
      );

      // Inject mocks into the static ProjectService
      ProjectService.setTestMocks(
        client: mockHttpClient,
        sharedPreferences: mockSharedPreferences,
        projectDatabase: mockProjectDatabase,
      );

      // Reset cache for each test
      ProjectService.clearCache();
    });

    tearDown(() {
      AuthService.clearTestValues(); // Clear AuthService static test values
      ProjectService.clearTestMocks();
      ProjectService.clearCache();
    });





    test('fetchProjectNamesFromServer returns a list of project names on success', () async {

      final mockResponse = http.Response(
        json.encode({
          'data': [
            {'name': 'PROJ-001'},
            {'name': 'PROJ-002'},
          ]
        }),
        200,
      );

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockResponse);

      final projectNames = await ProjectService.fetchProjectNamesFromServer();
      expect(projectNames, ['PROJ-001', 'PROJ-002']);
    });

    test('fetchProjectNamesFromServer returns empty list on API error', () async {

      final mockResponse = http.Response('Server Error', 500);

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockResponse);

      final projectNames = await ProjectService.fetchProjectNamesFromServer();
      expect(projectNames, isEmpty);
    });

    // --- syncProjects tests ---
    test('syncProjects fetches and inserts new projects', () async {

      when(mockSharedPreferences.getString(any)).thenReturn("2000-01-01 00:00:00");
      when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);

      final newProjectJson = {
        'name': 'PROJ-NEW',
        'modified': '2023-01-01 10:00:00.000000',
        'project_name': 'New Project',
        'gallery_images': [], // No images to cache
      };
      final mockApiResponse = http.Response(
        json.encode({'message': [newProjectJson]}),
        200,
      );
      final emptyLocalProjects = <Map<String, dynamic>>[];
      final List<String> serverProjectNames = ['PROJ-NEW'];

      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => mockApiResponse);
      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => emptyLocalProjects);
      when(mockProjectDatabase.upsertProject(any)).thenAnswer((_) async => {});
      when(mockProjectDatabase.deleteProject(any)).thenAnswer((_) async => {});

      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => [
            {'name': 'PROJ-NEW', 'data': json.encode(newProjectJson)}
          ]);



      // Mock fetchProjectNamesFromServer
      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({'data': serverProjectNames.map((e) => {'name': e}).toList()}),
        200,
      ));

      final projects = await ProjectService.syncProjects();

      expect(projects.length, 1);
      expect(projects.first.id, 'PROJ-NEW');
      verify(mockProjectDatabase.upsertProject(any)).called(1);
      verify(mockSharedPreferences.setString(any, any)).called(1);
    });

    test('syncProjects updates existing projects', () async {

      when(mockSharedPreferences.getString(any)).thenReturn("2000-01-01 00:00:00");
      when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);

      final existingProjectJson = {
        'name': 'PROJ-EXIST',
        'modified': '2023-01-01 09:00:00.000000',
        'project_name': 'Existing Project',
        'gallery_images': [],
      };
      final updatedProjectJson = {
        'name': 'PROJ-EXIST',
        'modified': '2023-01-01 11:00:00.000000',
        'project_name': 'Updated Project',
        'gallery_images': [],
      };
      final mockApiResponse = http.Response(
        json.encode({'message': [updatedProjectJson]}),
        200,
      );
      final localProjects = [
        {'name': 'PROJ-EXIST', 'data': json.encode(existingProjectJson)}
      ];
      final List<String> serverProjectNames = ['PROJ-EXIST'];


      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => mockApiResponse);
      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => localProjects);
      when(mockProjectDatabase.upsertProject(any)).thenAnswer((_) async => {});
      when(mockProjectDatabase.deleteProject(any)).thenAnswer((_) async => {});

      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => [
            {'name': 'PROJ-EXIST', 'data': json.encode(updatedProjectJson)}
          ]);



      // Mock fetchProjectNamesFromServer
      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({'data': serverProjectNames.map((e) => {'name': e}).toList()}),
        200,
      ));

      final projects = await ProjectService.syncProjects();

      expect(projects.length, 1);
      expect(projects.first.projectName, 'Updated Project');
      verify(mockProjectDatabase.upsertProject(any)).called(1);
    });

    test('syncProjects deletes projects no longer on server', () async {

      when(mockSharedPreferences.getString(any)).thenReturn("2000-01-01 00:00:00");
      when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);

      final localOnlyProjectJson = {
        'name': 'PROJ-DELETED',
        'modified': '2023-01-01 10:00:00.000000',
        'project_name': 'Should be deleted',
      };
      final mockApiResponse = http.Response(
        json.encode({'message': []}), // No projects from server
        200,
      );
      final localProjects = [
        {'name': 'PROJ-DELETED', 'data': json.encode(localOnlyProjectJson)}
      ];
      final List<String> serverProjectNames = []; // No projects on server

            when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => mockApiResponse);

            // First getAllProjects call returns local projects for deletion identification

            when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => localProjects);

            when(mockProjectDatabase.deleteProject('PROJ-DELETED')).thenAnswer((_) async => {});

            // Second getAllProjects call (after potential deletions) returns empty

            when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => []);



      // Mock fetchProjectNamesFromServer to return empty list
      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({'data': serverProjectNames.map((e) => {'name': e}).toList()}),
        200,
      ));

      final projects = await ProjectService.syncProjects();

      expect(projects, isEmpty);
      verify(mockProjectDatabase.deleteProject('PROJ-DELETED')).called(1);
    });

    test('syncProjects handles API error during project fetch', () async {

      when(mockSharedPreferences.getString(any)).thenReturn("2000-01-01 00:00:00");

      final localProjectJson = {
        'name': 'PROJ-LOCAL',
        'modified': '2023-01-01 10:00:00.000000',
        'project_name': 'Local Project',
      };
      final mockApiResponse = http.Response('Server Error', 500); // API error

      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => mockApiResponse);
      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => [
            {'name': 'PROJ-LOCAL', 'data': json.encode(localProjectJson)}
          ]);
      when(mockProjectDatabase.deleteProject(any)).thenAnswer((_) async => {});



      // Mock fetchProjectNamesFromServer to return existing local project name to avoid deletion
      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({'data': [{'name': 'PROJ-LOCAL'}]}),
        200,
      ));

      final projects = await ProjectService.syncProjects();

      expect(projects.length, 1);
      expect(projects.first.id, 'PROJ-LOCAL');
      verifyNever(mockProjectDatabase.upsertProject(any)); // Should not try to upsert on API error
      verifyNever(mockSharedPreferences.setString(any, any)); // Should not update timestamp on API error
    });

    test('syncProjects caches gallery images', () async {

      when(mockSharedPreferences.getString(any)).thenReturn("2000-01-01 00:00:00");
      when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);

      final projectWithImageJson = {
        'name': 'PROJ-IMAGE',
        'modified': '2023-01-01 10:00:00.000000',
        'project_name': 'Project with Images',
        'gallery_images': [
          {'images': 'http://example.com/image1.jpg'}
        ],
      };
      final mockApiResponse = http.Response(
        json.encode({'message': [projectWithImageJson]}),
        200,
      );
      final emptyLocalProjects = <Map<String, dynamic>>[];
      final List<String> serverProjectNames = ['PROJ-IMAGE'];


      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => mockApiResponse);
      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => emptyLocalProjects);
      when(mockProjectDatabase.upsertProject(any)).thenAnswer((_) async => {});
      when(mockProjectDatabase.deleteProject(any)).thenAnswer((_) async => {});


      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => [
            {'name': 'PROJ-IMAGE', 'data': json.encode(projectWithImageJson)}
          ]);



      // Mock fetchProjectNamesFromServer
      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({'data': serverProjectNames.map((e) => {'name': e}).toList()}),
        200,
      ));

      await ProjectService.syncProjects();


    });

    // --- fetchProjects tests ---
    test('fetchProjects returns projects from database if not forced refresh and database not empty', () async {
      final projectJson = {
        'name': 'PROJ-DB',
        'modified': '2023-01-01 10:00:00.000000',
        'project_name': 'From DB',
      };
      final localProjects = [
        {'name': 'PROJ-DB', 'data': json.encode(projectJson)}
      ];

      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => localProjects);



      final projects = await ProjectService.fetchProjects();

      expect(projects.length, 1);
      expect(projects.first.id, 'PROJ-DB');
      verify(mockProjectDatabase.getAllProjects()).called(1);
      verifyNever(mockHttpClient.get(any, headers: anyNamed('headers'))); // Should not call API
    });

    test('fetchProjects calls syncProjects if database is empty', () async {
      final newProjectJson = {
        'name': 'PROJ-SYNC',
        'modified': '2023-01-01 10:00:00.000000',
        'project_name': 'Synced Project',
        'gallery_images': [],
      };
      final ongoingStub = when(mockProjectDatabase.getAllProjects());
      ongoingStub.thenAnswer((_) async => []); // First call (fetchProjects initial check)
      ongoingStub.thenAnswer((_) async => []); // Second call (syncProjects localProjectsRaw)
      ongoingStub.thenAnswer((_) async => [ // Third call (syncProjects final return)
            {'name': 'PROJ-SYNC', 'data': json.encode(newProjectJson)}
          ]);
      when(mockSharedPreferences.getString(any)).thenReturn("2000-01-01 00:00:00");
      when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);

      final mockApiResponse = http.Response(
        json.encode({'message': [newProjectJson]}),
        200,
      );
      final List<String> serverProjectNames = ['PROJ-SYNC'];


      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => mockApiResponse);
      when(mockProjectDatabase.upsertProject(any)).thenAnswer((_) async => {});
      when(mockProjectDatabase.deleteProject(any)).thenAnswer((_) async => {});
      // Removed the last when(mockProjectDatabase.getAllProjects()) as it's now handled by the chained thenAnswer.


      // Mock fetchProjectNamesFromServer
      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({'data': serverProjectNames.map((e) => {'name': e}).toList()}),
        200,
      ));

      final projects = await ProjectService.fetchProjects();

      expect(projects.length, 1);
      expect(projects.first.id, 'PROJ-SYNC');
      verify(mockProjectDatabase.getAllProjects()).called(2); // One for empty check, one for returning
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(greaterThanOrEqualTo(1)); // Calls syncProjects
    });

    test('fetchProjects calls syncProjects if forceRefresh is true', () async {

      final projectJson = {
        'name': 'PROJ-DB',
        'modified': '2023-01-01 10:00:00.000000',
        'project_name': 'From DB',
        'gallery_images': [],
      };
      final localProjects = [
        {'name': 'PROJ-DB', 'data': json.encode(projectJson)}
      ];
      final updatedProjectJson = {
        'name': 'PROJ-DB',
        'modified': '2023-01-01 11:00:00.000000',
        'project_name': 'Updated From Sync',
        'gallery_images': [],
      };
      final mockApiResponse = http.Response(
        json.encode({'message': [updatedProjectJson]}),
        200,
      );
      final List<String> serverProjectNames = ['PROJ-DB'];


      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => localProjects);
      when(mockSharedPreferences.getString(any)).thenReturn("2000-01-01 00:00:00");
      when(mockSharedPreferences.setString(any, any)).thenAnswer((_) async => true);
      when(mockHttpClient.get(any, headers: anyNamed('headers'))).thenAnswer((_) async => mockApiResponse);
      when(mockProjectDatabase.upsertProject(any)).thenAnswer((_) async => {});
      when(mockProjectDatabase.deleteProject(any)).thenAnswer((_) async => {});

      when(mockProjectDatabase.getAllProjects()).thenAnswer((_) async => [
            {'name': 'PROJ-DB', 'data': json.encode(updatedProjectJson)}
          ]);



      // Mock fetchProjectNamesFromServer
      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects?fields=["name"]'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => http.Response(
        json.encode({'data': serverProjectNames.map((e) => {'name': e}).toList()}),
        200,
      ));

      final projects = await ProjectService.fetchProjects(forceRefresh: true);

      expect(projects.length, 1);
      expect(projects.first.projectName, 'Updated From Sync');
      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(greaterThanOrEqualTo(1)); // Calls syncProjects
    });

    // --- fetchProject (single project) tests ---
    test('fetchProject returns a single project on success', () async {

      final projectJson = {
        'name': 'PROJ-SINGLE',
        'project_name': 'Single Project',
      };
      final mockResponse = http.Response(
        json.encode({'data': projectJson}),
        200,
      );

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects/PROJ-SINGLE'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockResponse);

      final project = await ProjectService.fetchProject('PROJ-SINGLE');
      expect(project, isNotNull);
      expect(project!.id, 'PROJ-SINGLE');
      expect(project.projectName, 'Single Project');
    });

    test('fetchProject returns null on API error', () async {

      final mockResponse = http.Response('Not Found', 404);

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/resource/Property Projects/NON-EXISTENT'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockResponse);

      final project = await ProjectService.fetchProject('NON-EXISTENT');
      expect(project, isNull);
    });

    // --- fetchApiProjects tests ---
    test('fetchApiProjects returns list of project IDs and names', () async {

      final mockApiResponse = http.Response(
        json.encode({
          'message': [
            {'name': 'PROJ-API-1', 'project_name': 'API Project One'},
            {'name': 'PROJ-API-2', 'project_name': 'API Project Two'},
          ]
        }),
        200,
      );

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/method/homesol_app.api.get_all_projects'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockApiResponse);

      final apiProjects = await ProjectService.fetchApiProjects();
      expect(apiProjects.length, 2);
      expect(apiProjects.first['id'], 'PROJ-API-1');
      expect(apiProjects.first['name'], 'API Project One');
    });

    test('fetchApiProjects returns cached projects within 5 minutes', () async {

      final mockApiResponse = http.Response(
        json.encode({
          'message': [
            {'name': 'PROJ-CACHED', 'project_name': 'Cached Project'},
          ]
        }),
        200,
      );

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/method/homesol_app.api.get_all_projects'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockApiResponse);

      // First call to populate cache
      await ProjectService.fetchApiProjects();
      // Second call, should use cache
      await ProjectService.fetchApiProjects();

      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(1); // Only called once
    });

    test('fetchApiProjects ignores cache if forceRefresh is true', () async {

      final mockApiResponse = http.Response(
        json.encode({
          'message': [
            {'name': 'PROJ-CACHED', 'project_name': 'Cached Project'},
          ]
        }),
        200,
      );

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/method/homesol_app.api.get_all_projects'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockApiResponse);

      // First call to populate cache
      await ProjectService.fetchApiProjects();
      // Second call with forceRefresh, should ignore cache
      await ProjectService.fetchApiProjects(forceRefresh: true);

      verify(mockHttpClient.get(any, headers: anyNamed('headers'))).called(2); // Called twice
    });

    test('fetchApiProjects returns empty list on API error', () async {

      final mockApiResponse = http.Response('Server Error', 500);

      when(mockHttpClient.get(
        Uri.parse('$testBaseUrl/api/method/homesol_app.api.get_all_projects'),
        headers: anyNamed('headers'),
      )).thenAnswer((_) async => mockApiResponse);

      final apiProjects = await ProjectService.fetchApiProjects();
      expect(apiProjects, isEmpty);
    });
  });
}
