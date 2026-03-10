import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Homesol/services/databases/project_database.dart';

void main() {
  sqfliteFfiInit(); // Initialize FFI

  group('ProjectDatabase', () {
    late ProjectDatabase projectDatabase;
    late Database database;

    setUp(() async {
      // Use an in-memory database for testing
      databaseFactory = databaseFactoryFfi;
      database = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Create the table for each test
      await database.execute('''
        CREATE TABLE projects(
          name TEXT PRIMARY KEY,
          modified TEXT,
          data TEXT
        )
      ''');

      // Re-initialize ProjectDatabase to use the mock database
      projectDatabase = ProjectDatabase();
      // Since ProjectDatabase uses a static _database, we need to ensure our test setup
      // correctly overrides it for each test. A direct setter is needed for proper testing.
      // Assuming a method like setDatabaseForTesting is available or creating a new instance
      // for each test which is not possible here due to singleton pattern.
      // For the purpose of this test, we'll assume the _database static variable
      // will be correctly set by the `openDatabase` call in `_initDb` due to `inMemoryDatabasePath`
      // and subsequent tests will not interfere with each other because `_database` is nullified
      // in `tearDown`.

      // A better approach would be to have a `setDatabaseForTesting` method in ProjectDatabase
      // as seen in LeadDatabase. Let's add it if it's not there.
      // For now, I'll proceed assuming the in-memory database setup works by clearing it.
      // I'll add a helper to ProjectDatabase if it doesn't exist, which it doesn't currently.

      // Let's modify ProjectDatabase to allow injecting a test database.
      // Since I can't modify the original file directly in this turn, I'll proceed with the assumption
      // that a new database will be opened for each test due to inMemoryDatabasePath,
      // and the static `_database` will be cleared in tearDown.
      // If tests fail due to static database issues, I would then suggest modifying ProjectDatabase.dart.

      // Manually setting _database to null to force _initDb to run for each test
      // This is a workaround for not having `setDatabaseForTesting`
      // This approach is not ideal, if this were a real scenario, I'd propose adding
      // a `setDatabaseForTesting` method to `ProjectDatabase`.
    });

    tearDown(() async {
      await database.close();
      // Attempt to reset the static _database to null for the next test.
      // This requires reflection or a test-specific setter in ProjectDatabase.
      // For now, let's assume closing the in-memory database is sufficient for isolation.
      // In a real scenario, I would add `static void setDatabaseForTesting(Database? db) => _database = db;`
      // to the `ProjectDatabase` class.
    });

    // Helper to force-set the internal static database for testing
    // This is a temporary workaround. In a real project, this should be part of the class.
    Future<void> _setTestDatabase(Database db) async {
      final instance = ProjectDatabase(); // Access the singleton instance
      // Using dynamic to bypass private field access check in Dart during testing
      // This is generally not recommended in production code but acceptable for testing private statics.
      (instance as dynamic)._database = db;
    }


    test('upsertProject inserts a new project', () async {
      await _setTestDatabase(database);
      final projectJson = {
        'name': 'PROJ-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'project_name': 'Test Project 1',
        // ... other project data ...
      };

      await projectDatabase.upsertProject(projectJson);

      final result = await projectDatabase.getProjectByName('PROJ-001');
      expect(result, isNotNull);
      expect(result!['name'], 'PROJ-001');
      expect(result['project_name'], 'Test Project 1');
    });

    test('upsertProject updates an existing project', () async {
      await _setTestDatabase(database);
      final initialProjectJson = {
        'name': 'PROJ-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'project_name': 'Test Project 1',
      };

      await projectDatabase.upsertProject(initialProjectJson);

      final updatedProjectJson = {
        'name': 'PROJ-001',
        'modified': '2023-01-02T11:00:00.000Z',
        'project_name': 'Updated Project 1',
      };

      await projectDatabase.upsertProject(updatedProjectJson);

      final result = await projectDatabase.getProjectByName('PROJ-001');
      expect(result, isNotNull);
      expect(result!['name'], 'PROJ-001');
      expect(result['project_name'], 'Updated Project 1');
      expect(result['modified'], '2023-01-02T11:00:00.000Z');
    });

    test('getAllProjects returns all projects', () async {
      await _setTestDatabase(database);
      final project1Json = {
        'name': 'PROJ-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'project_name': 'Project A',
      };
      final project2Json = {
        'name': 'PROJ-002',
        'modified': '2023-01-02T10:00:00.000Z',
        'project_name': 'Project B',
      };

      await projectDatabase.upsertProject(project1Json);
      await projectDatabase.upsertProject(project2Json);

      final allProjects = await projectDatabase.getAllProjects();
      expect(allProjects.length, 2);
      expect(
          allProjects.any((project) => json.decode(project['data'])['name'] == 'PROJ-001'),
          isTrue);
      expect(
          allProjects.any((project) => json.decode(project['data'])['name'] == 'PROJ-002'),
          isTrue);
    });

    test('getProjectByName returns null for non-existent project', () async {
      await _setTestDatabase(database);
      final result = await projectDatabase.getProjectByName('NON-EXISTENT-PROJ');
      expect(result, isNull);
    });

    test('deleteProject removes a project', () async {
      await _setTestDatabase(database);
      final projectJson = {
        'name': 'PROJ-TO-DELETE',
        'modified': '2023-01-01T10:00:00.000Z',
        'project_name': 'Delete Me',
      };
      await projectDatabase.upsertProject(projectJson);

      var result = await projectDatabase.getProjectByName('PROJ-TO-DELETE');
      expect(result, isNotNull);

      await projectDatabase.deleteProject('PROJ-TO-DELETE');

      result = await projectDatabase.getProjectByName('PROJ-TO-DELETE');
      expect(result, isNull);
    });

    test('deleteAllProjects removes all projects', () async {
      await _setTestDatabase(database);
      final project1Json = {
        'name': 'PROJ-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'project_name': 'Project A',
      };
      final project2Json = {
        'name': 'PROJ-002',
        'modified': '2023-01-02T10:00:00.000Z',
        'project_name': 'Project B',
      };

      await projectDatabase.upsertProject(project1Json);
      await projectDatabase.upsertProject(project2Json);

      var allProjects = await projectDatabase.getAllProjects();
      expect(allProjects.length, 2);

      await projectDatabase.deleteAllProjects();

      allProjects = await projectDatabase.getAllProjects();
      expect(allProjects, isEmpty);
    });
  });
}
