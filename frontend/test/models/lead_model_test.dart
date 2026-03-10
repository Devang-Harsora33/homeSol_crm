import 'package:flutter_test/flutter_test.dart';
import 'package:Homesol/models/lead.dart';

void main() {
  group('Lead Model', () {
    test('LeadNote.fromJson creates a valid LeadNote object', () {
      final Map<String, dynamic> json = {
        'note': 'Test Note Content',
        'added_by': 'Test User',
        'added_on': '2023-01-01T10:00:00.000Z',
      };

      final leadNote = LeadNote.fromJson(json);

      expect(leadNote.note, 'Test Note Content');
      expect(leadNote.addedBy, 'Test User');
      expect(leadNote.addedOn, DateTime.parse('2023-01-01T10:00:00.000Z'));
    });

    test('LeadNote.toJson converts a LeadNote object to JSON', () {
      final leadNote = LeadNote(
        note: 'Test Note Content',
        addedBy: 'Test User',
        addedOn: DateTime.parse('2023-01-01T10:00:00.000Z'),
      );

      final json = leadNote.toJson();

      expect(json['note'], 'Test Note Content');
      expect(json['added_by'], 'Test User');
      expect(json['added_on'], '2023-01-01T10:00:00.000Z');
    });

    test('Lead.fromJson creates a valid Lead object', () {
      final Map<String, dynamic> json = {
        'name': 'LEAD-0001',
        'lead_owner': 'broker123',
        'mobile_no': '1234567890',
        'lead_name': 'John Doe',
        'status': 'Open',
        'budget': 500000,
        'custom_interested_project': 'Project Alpha',
        'creation': '2023-01-01T10:00:00.000Z',
        'modified': '2023-01-02T11:00:00.000Z',
        'notes': [
          {
            'note': 'Initial contact',
            'added_by': 'Agent 1',
            'added_on': '2023-01-01T10:05:00.000Z',
          }
        ],
        // Required fields not directly in the JSON but derived
        // customerPhone: json['mobile_no'] ?? json['customer_phone'] ?? json['phone'] ?? '',
        // customerName: json['lead_name'] ?? json['customer_name'] ?? '',
        // brokerId: json['lead_owner'] ?? json['broker_id']?.toString() ?? '',
        // projectId: derived from 'custom_interested_project' or 'project_id'
        // status: json['status'] ?? 'pending',
        // budget: (json['budget'] ?? json['annual_revenue'] ?? 0).toInt(),
      };

      final lead = Lead.fromJson(json);

      expect(lead.name, 'LEAD-0001');
      expect(lead.leadOwner, 'broker123');
      expect(lead.customerPhone, '1234567890');
      expect(lead.customerName, 'John Doe');
      expect(lead.status, 'Open');
      expect(lead.budget, 500000);
      expect(lead.projectId, ['Project Alpha']);
      expect(lead.creation, DateTime.parse('2023-01-01T10:00:00.000Z'));
      expect(lead.modified, DateTime.parse('2023-01-02T11:00:00.000Z'));
      expect(lead.notes.length, 1);
      expect(lead.notes.first.note, 'Initial contact');
    });

    test('Lead.toJson converts a Lead object to JSON', () {
      final lead = Lead(
        name: 'LEAD-0001',
        leadOwner: 'broker123',
        customerPhone: '1234567890',
        customerName: 'John Doe',
        status: 'Open',
        budget: 500000,
        projectId: ['Project Alpha'],
        creation: DateTime.parse('2023-01-01T10:00:00.000Z'),
        modified: DateTime.parse('2023-01-02T11:00:00.000Z'),
        notes: [
          LeadNote(
            note: 'Initial contact',
            addedBy: 'Agent 1',
            addedOn: DateTime.parse('2023-01-01T10:05:00.000Z'),
          )
        ],
        // The toJson only includes a subset of fields for sending to the server
        // Make sure required fields are passed to the constructor
        brokerId: 'broker123', // required
      );

      final json = lead.toJson();

      expect(json['name'], 'LEAD-0001');
      expect(json['mobile_no'], '1234567890');
      expect(json['customer_name'], 'John Doe');
      expect(json['lead_owner'], 'broker123');
      expect(json['project_id'], ['Project Alpha']);
      expect(json['status'], 'Open');
      expect(json['budget'], 500000);
      expect(json['notes'].length, 1);
      expect(json['notes'][0]['note'], 'Initial contact');
    });

    test('Lead.fromJson handles missing fields gracefully', () {
      final Map<String, dynamic> json = {
        'mobile_no': '1112223333',
        'lead_name': 'Jane Smith',
        'status': 'Pending',
        'budget': 100000,
        'lead_owner': 'broker456',
      };

      final lead = Lead.fromJson(json);

      expect(lead.customerPhone, '1112223333');
      expect(lead.customerName, 'Jane Smith');
      expect(lead.status, 'Pending');
      expect(lead.budget, 100000);
      expect(lead.brokerId, 'broker456');
      expect(lead.name, isNull); // 'name' was not in JSON
      expect(lead.creation, isNull); // 'creation' was not in JSON
      expect(lead.projectId, isEmpty); // 'custom_interested_project' was not in JSON
      expect(lead.notes, isEmpty); // 'notes' was not in JSON
    });

    test('Lead.toJson handles null fields gracefully', () {
      final lead = Lead(
        customerPhone: '9876543210',
        customerName: 'Alice Wonderland',
        status: 'Closed',
        budget: 750000,
        brokerId: 'broker789',
        projectId: [],
        notes: [],
        name: null, // explicitly null
      );

      final json = lead.toJson();

      expect(json['mobile_no'], '9876543210');
      expect(json['customer_name'], 'Alice Wonderland');
      expect(json['status'], 'Closed');
      expect(json['budget'], 750000);
      expect(json['lead_owner'], 'broker789');
      expect(json['project_id'], isEmpty);
      expect(json['notes'], isEmpty);
      expect(json.containsKey('name'), isTrue); // 'name' key should still exist, with null value
      expect(json['name'], isNull);
    });

     test('Lead.fromJson handles various budget/revenue fields for budget', () {
      // Test with 'budget'
      var json1 = {'mobile_no': '1', 'lead_name': 'A', 'status': 'Open', 'budget': 100, 'lead_owner': 'X'};
      expect(Lead.fromJson(json1).budget, 100);

      // Test with 'annual_revenue' if 'budget' is missing
      var json2 = {'mobile_no': '2', 'lead_name': 'B', 'status': 'Open', 'annual_revenue': 200.50, 'lead_owner': 'Y'};
      expect(Lead.fromJson(json2).budget, 200); // Should be int after conversion

      // Test with neither, defaults to 0
      var json3 = {'mobile_no': '3', 'lead_name': 'C', 'status': 'Open', 'lead_owner': 'Z'};
      expect(Lead.fromJson(json3).budget, 0);
    });

    test('LeadNote.plainText returns plain text from HTML content', () {
      final leadNote = LeadNote(
        note: '<p>This is a <b>test</b> note with <i>HTML</i> tags.</p>',
      );

      expect(leadNote.plainText, 'This is a test note with HTML tags.');
    });

    test('LeadNote.plainText returns empty string for null note', () {
      final leadNote = LeadNote(note: null);
      expect(leadNote.plainText, '');
    });
  });
}
