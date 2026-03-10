import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:Homesol/services/databases/lead_database.dart';
import 'package:Homesol/models/lead.dart';

void main() {
  sqfliteFfiInit(); // Initialize FFI

  group('LeadDatabase', () {
    late LeadDatabase leadDatabase;
    late Database database;

    setUp(() async {
      // Use an in-memory database for testing
      databaseFactory = databaseFactoryFfi;
      database = await databaseFactory.openDatabase(inMemoryDatabasePath);

      // Create the table for each test
      await database.execute('''
        CREATE TABLE leads(
          name TEXT PRIMARY KEY,
          modified TEXT,
          data TEXT
        )
      ''');

      // Re-initialize LeadDatabase to use the mock database
      leadDatabase = LeadDatabase();
      LeadDatabase.setDatabaseForTesting(database);
    });

    tearDown(() async {
      await database.close();
      LeadDatabase.setDatabaseForTesting(null); // Clear the injected database
    });

    test('upsertLead inserts a new lead', () async {
      final leadJson = {
        'name': 'LEAD-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'customerPhone': '1234567890',
        'customerName': 'Test Lead 1',
        'brokerId': 'BrokerA',
        'projectId': ['ProjectX'],
        'status': 'New',
        'budget': 100000,
      };

      await leadDatabase.upsertLead(leadJson);

      final result = await leadDatabase.getLeadByName('LEAD-001');
      expect(result, isNotNull);
      expect(result!['name'], 'LEAD-001');
      expect(result['customerName'], 'Test Lead 1');
    });

    test('upsertLead updates an existing lead', () async {
      final initialLeadJson = {
        'name': 'LEAD-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'customerPhone': '1234567890',
        'customerName': 'Test Lead 1',
        'brokerId': 'BrokerA',
        'projectId': ['ProjectX'],
        'status': 'New',
        'budget': 100000,
      };

      await leadDatabase.upsertLead(initialLeadJson);

      final updatedLeadJson = {
        'name': 'LEAD-001',
        'modified': '2023-01-02T11:00:00.000Z',
        'customerPhone': '0987654321',
        'customerName': 'Updated Lead 1',
        'brokerId': 'BrokerB',
        'projectId': ['ProjectY'],
        'status': 'Contacted',
        'budget': 150000,
      };

      await leadDatabase.upsertLead(updatedLeadJson);

      final result = await leadDatabase.getLeadByName('LEAD-001');
      expect(result, isNotNull);
      expect(result!['name'], 'LEAD-001');
      expect(result['customerName'], 'Updated Lead 1');
      expect(result['modified'], '2023-01-02T11:00:00.000Z');
      expect(result['customerPhone'], '0987654321');
    });

    test('getAllLeads returns all leads', () async {
      final lead1Json = {
        'name': 'LEAD-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'customerPhone': '123',
        'customerName': 'Lead A',
        'brokerId': 'B1',
        'projectId': [],
        'status': 'N',
        'budget': 1,
      };
      final lead2Json = {
        'name': 'LEAD-002',
        'modified': '2023-01-02T10:00:00.000Z',
        'customerPhone': '456',
        'customerName': 'Lead B',
        'brokerId': 'B2',
        'projectId': [],
        'status': 'N',
        'budget': 2,
      };

      await leadDatabase.upsertLead(lead1Json);
      await leadDatabase.upsertLead(lead2Json);

      final allLeads = await leadDatabase.getAllLeads();
      expect(allLeads.length, 2);
      expect(allLeads.any((lead) => lead['name'] == 'LEAD-001'), isTrue);
      expect(allLeads.any((lead) => lead['name'] == 'LEAD-002'), isTrue);
    });

    test('getLeadByName returns null for non-existent lead', () async {
      final result = await leadDatabase.getLeadByName('NON-EXISTENT-LEAD');
      expect(result, isNull);
    });

    test('deleteLead removes a lead', () async {
      final leadJson = {
        'name': 'LEAD-TO-DELETE',
        'modified': '2023-01-01T10:00:00.000Z',
        'customerPhone': '123',
        'customerName': 'Delete Me',
        'brokerId': 'B',
        'projectId': [],
        'status': 'N',
        'budget': 1,
      };
      await leadDatabase.upsertLead(leadJson);

      var result = await leadDatabase.getLeadByName('LEAD-TO-DELETE');
      expect(result, isNotNull);

      await leadDatabase.deleteLead('LEAD-TO-DELETE');

      result = await leadDatabase.getLeadByName('LEAD-TO-DELETE');
      expect(result, isNull);
    });

    test('deleteAllLeads removes all leads', () async {
      final lead1Json = {
        'name': 'LEAD-001',
        'modified': '2023-01-01T10:00:00.000Z',
        'customerPhone': '123',
        'customerName': 'Lead A',
        'brokerId': 'B1',
        'projectId': [],
        'status': 'N',
        'budget': 1,
      };
      final lead2Json = {
        'name': 'LEAD-002',
        'modified': '2023-01-02T10:00:00.000Z',
        'customerPhone': '456',
        'customerName': 'Lead B',
        'brokerId': 'B2',
        'projectId': [],
        'status': 'N',
        'budget': 2,
      };

      await leadDatabase.upsertLead(lead1Json);
      await leadDatabase.upsertLead(lead2Json);

      var allLeads = await leadDatabase.getAllLeads();
      expect(allLeads.length, 2);

      await leadDatabase.deleteAllLeads();

      allLeads = await leadDatabase.getAllLeads();
      expect(allLeads, isEmpty);
    });
  });
}
