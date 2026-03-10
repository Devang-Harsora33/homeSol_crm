import 'package:flutter_test/flutter_test.dart';
import 'package:Homesol/models/project.dart';

void main() {
  group('Project Models', () {
    // --- BrokerageSlab Tests ---
    test('BrokerageSlab.fromJson creates a valid object', () {
      final Map<String, dynamic> json = {
        'from_booking': 1,
        'to_booking': 10,
        'percentage': 0.05,
        'incentive': 5000.0,
      };
      final slab = BrokerageSlab.fromJson(json);
      expect(slab.fromBooking, 1);
      expect(slab.toBooking, 10);
      expect(slab.percentage, 0.05);
      expect(slab.incentive, 5000.0);
    });

    test('BrokerageSlab.fromJson handles missing/null values', () {
      final Map<String, dynamic> json = {};
      final slab = BrokerageSlab.fromJson(json);
      expect(slab.fromBooking, 0);
      expect(slab.toBooking, 0);
      expect(slab.percentage, 0.0);
      expect(slab.incentive, 0.0);
    });

    test('BrokerageSlab.toJson converts object to JSON', () {
      final slab = BrokerageSlab(
          fromBooking: 1, toBooking: 10, percentage: 0.05, incentive: 5000.0);
      final json = slab.toJson();
      expect(json['from_booking'], 1);
      expect(json['to_booking'], 10);
      expect(json['percentage'], 0.05);
      expect(json['incentive'], 5000.0);
    });

    // --- Configuration Tests ---
    test('Configuration.fromJson creates a valid object', () {
      final Map<String, dynamic> json = {
        'configuration_name': '2BHK',
        'carpet_area': 1200.5,
        'price': 7500000.0,
      };
      final config = Configuration.fromJson(json);
      expect(config.name, '2BHK');
      expect(config.carpetArea, 1200.5);
      expect(config.price, 7500000.0);
    });

    test('Configuration.fromJson handles missing/null values', () {
      final Map<String, dynamic> json = {};
      final config = Configuration.fromJson(json);
      expect(config.name, '');
      expect(config.carpetArea, 0.0);
      expect(config.price, 0.0);
    });

    test('Configuration.toJson converts object to JSON', () {
      final config =
          Configuration(name: '2BHK', carpetArea: 1200.5, price: 7500000.0);
      final json = config.toJson();
      expect(json['configuration_name'], '2BHK');
      expect(json['carpet_area'], 1200.5);
      expect(json['price'], 7500000.0);
    });

    // --- ProjectTimeline Tests ---
    test('ProjectTimeline.fromJson creates a valid object', () {
      final Map<String, dynamic> json = {
        'milestone': 'Foundation',
        'target_date': '2024-12-31',
        'status': 'Completed',
      };
      final timeline = ProjectTimeline.fromJson(json);
      expect(timeline.milestone, 'Foundation');
      expect(timeline.targetDate, '2024-12-31');
      expect(timeline.status, 'Completed');
    });

    test('ProjectTimeline.fromJson handles missing/null values', () {
      final Map<String, dynamic> json = {};
      final timeline = ProjectTimeline.fromJson(json);
      expect(timeline.milestone, '');
      expect(timeline.targetDate, '');
      expect(timeline.status, '');
    });

    // --- ProjectAmenity Tests ---
    test('ProjectAmenity.fromJson creates a valid object', () {
      final Map<String, dynamic> json = {'data': 'Swimming Pool'};
      final amenity = ProjectAmenity.fromJson(json);
      expect(amenity.data, 'Swimming Pool');
    });

    test('ProjectAmenity.fromJson handles missing/null values', () {
      final Map<String, dynamic> json = {};
      final amenity = ProjectAmenity.fromJson(json);
      expect(amenity.data, '');
    });

    // --- ProjectDocument Tests ---
    test('ProjectDocument.fromJson creates a valid object', () {
      final Map<String, dynamic> json = {'document_name': 'RERA Approval', 'file': 'rera.pdf'};
      final document = ProjectDocument.fromJson(json);
      expect(document.documentName, 'RERA Approval');
      expect(document.file, 'rera.pdf');
    });

    test('ProjectDocument.fromJson handles missing/null values', () {
      final Map<String, dynamic> json = {};
      final document = ProjectDocument.fromJson(json);
      expect(document.documentName, '');
      expect(document.file, '');
    });

    test('ProjectDocument.toJson converts object to JSON', () {
      final document =
          ProjectDocument(documentName: 'RERA Approval', file: 'rera.pdf');
      final json = document.toJson();
      expect(json['document_name'], 'RERA Approval');
      expect(json['file'], 'rera.pdf');
    });

    // --- ProjectImage Tests ---
    test('ProjectImage.fromJson creates a valid object', () {
      final Map<String, dynamic> json = {'images': 'image1.jpg'};
      final image = ProjectImage.fromJson(json);
      expect(image.images, 'image1.jpg');
    });

    test('ProjectImage.fromJson handles missing/null values', () {
      final Map<String, dynamic> json = {};
      final image = ProjectImage.fromJson(json);
      expect(image.images, '');
    });

    // --- Project Main Model Tests ---
    test('Project.fromJson creates a valid Project object', () {
      final Map<String, dynamic> json = {
        'name': 'PROJ-001',
        'project_name': 'Grand Residency',
        'developer': 'DEV-001',
        'developer_name': 'Mega Developers',
        'mandate': 'MAND-001',
        'mandate_name': 'Exclusive Mandate',
        'rera_id': 'RERA-123',
        'construction_status': 'Under Construction',
        'property_type': 'Residential',
        'description': 'Luxury apartments',
        'project_rm': 'RM-001',
        'location_name': 'Downtown',
        'city': 'Mumbai',
        'state': 'Maharashtra',
        'location': '19.0760, 72.8777',
        'nearby_landmarks': 'Near Metro Station',
        'project_approval': 'Approved',
        'development_scheme': 'Mixed Use',
        'price_range_min': 10000000,
        'price_range_max': 20000000,
        'parking_type': 'Basement',
        'launch_date': '2023-01-01',
        'possession_date': '2025-12-31',
        'target_possession': '2025-Q4',
        'architect': 'Ar. Sharma',
        'contractor': 'BuildIt Pvt Ltd',
        'electrical_contractor': 'PowerUp Inc',
        'rera_liasoning': 'Legal Corp',
        'documents': [
          {'document_name': 'Brochure', 'file': 'brochure.pdf'}
        ],
        'configurations': [
          {
            'configuration_name': '1BHK',
            'carpet_area': 600.0,
            'price': 5000000.0
          }
        ],
        'gallery_images': [
          {'images': 'image_gallery_1.jpg'}
        ],
        'amenities': [
          {'data': 'Gym'}
        ],
        'brokerage_slabs': [
          {
            'from_booking': 1,
            'to_booking': 5,
            'percentage': 0.03,
            'incentive': 2000.0
          }
        ],
        'project_timeline': [
          {
            'milestone': 'Excavation',
            'target_date': '2023-03-31',
            'status': 'Done'
          }
        ],
        'creation': '2023-01-01T10:00:00.000Z',
        'modified': '2023-01-02T11:00:00.000Z',
      };

      final project = Project.fromJson(json);

      expect(project.id, 'PROJ-001');
      expect(project.projectName, 'Grand Residency');
      expect(project.developer, 'DEV-001');
      expect(project.developerName, 'Mega Developers');
      expect(project.mandate, 'MAND-001');
      expect(project.mandateName, 'Exclusive Mandate');
      expect(project.reraId, 'RERA-123');
      expect(project.constructionStatus, 'Under Construction');
      expect(project.propertyType, 'Residential');
      expect(project.description, 'Luxury apartments');
      expect(project.projectRm, 'RM-001');
      expect(project.locationName, 'Downtown');
      expect(project.city, 'Mumbai');
      expect(project.state, 'Maharashtra');
      expect(project.location, '19.0760, 72.8777');
      expect(project.nearbyLandmarks, 'Near Metro Station');
      expect(project.projectApproval, 'Approved');
      expect(project.developmentScheme, 'Mixed Use');
      expect(project.priceRangeMin, 10000000);
      expect(project.priceRangeMax, 20000000);
      expect(project.parkingType, 'Basement');
      expect(project.launchDate, '2023-01-01');
      expect(project.possessionDate, '2025-12-31');
      expect(project.targetPossession, '2025-Q4');
      expect(project.architect, 'Ar. Sharma');
      expect(project.contractor, 'BuildIt Pvt Ltd');
      expect(project.electricalContractor, 'PowerUp Inc');
      expect(project.reraLiasoning, 'Legal Corp');
      expect(project.creation, '2023-01-01T10:00:00.000Z');
      expect(project.modified, '2023-01-02T11:00:00.000Z');

      expect(project.documents.length, 1);
      expect(project.documents.first.documentName, 'Brochure');
      expect(project.configurations.length, 1);
      expect(project.configurations.first.name, '1BHK');
      expect(project.galleryImages.length, 1);
      expect(project.galleryImages.first.images, 'image_gallery_1.jpg');
      expect(project.amenities.length, 1);
      expect(project.amenities.first.data, 'Gym');
      expect(project.brokerageSlabs.length, 1);
      expect(project.brokerageSlabs.first.percentage, 0.03);
      expect(project.projectTimeline.length, 1);
      expect(project.projectTimeline.first.milestone, 'Excavation');
    });

    test('Project.fromJson handles empty/null lists', () {
      final Map<String, dynamic> json = {
        'name': 'PROJ-002',
        'project_name': 'Empty Lists Project',
        'developer': 'DEV-002',
        'mandate': 'MAND-002',
        'rera_id': 'RERA-124',
        'construction_status': 'Ready to Move',
        'property_type': 'Commercial',
        'description': '',
        'project_rm': '',
        'location_name': '',
        'city': '',
        'state': '',
        'nearby_landmarks': '',
        'project_approval': '',
        'development_scheme': '',
        'price_range_min': 0,
        'price_range_max': 0,
        'parking_type': '',
        'launch_date': '',
        'possession_date': '',
        'target_possession': '',
        'architect': '',
        'contractor': '',
        'electrical_contractor': '',
        'rera_liasoning': '',
        'documents': null,
        'configurations': [],
        'gallery_images': null,
        'amenities': [],
        'brokerage_slabs': null,
        'project_timeline': [],
        'creation': '2023-01-01T10:00:00.000Z',
        'modified': '2023-01-02T11:00:00.000Z',
      };

      final project = Project.fromJson(json);

      expect(project.id, 'PROJ-002');
      expect(project.projectName, 'Empty Lists Project');
      expect(project.documents, isEmpty);
      expect(project.configurations, isEmpty);
      expect(project.galleryImages, isEmpty);
      expect(project.amenities, isEmpty);
      expect(project.brokerageSlabs, isEmpty);
      expect(project.projectTimeline, isEmpty);
    });

    test('Project.locationDisplay returns correct formatted string', () {
      final project1 = Project(
        id: '1',
        projectName: 'P1',
        developer: 'D1',
        mandate: 'M1',
        reraId: 'R1',
        constructionStatus: 'CS1',
        propertyType: 'PT1',
        description: 'Desc1',
        projectRm: 'RM1',
        locationName: 'Area A',
        city: 'City B',
        state: 'State C',
        nearbyLandmarks: 'NL1',
        projectApproval: 'PA1',
        developmentScheme: 'DS1',
        priceRangeMin: 1,
        priceRangeMax: 2,
        parkingType: 'PK1',
        launchDate: 'LD1',
        possessionDate: 'PD1',
        targetPossession: 'TP1',
        architect: 'A1',
        contractor: 'C1',
        electricalContractor: 'EC1',
        reraLiasoning: 'RL1',
        documents: [],
        configurations: [],
        galleryImages: [],
        amenities: [],
        brokerageSlabs: [],
        projectTimeline: [],
        creation: 'C',
        modified: 'M',
      );
      expect(project1.locationDisplay, 'Area A, City B, State C');

      final project2 = Project(
        id: '1',
        projectName: 'P1',
        developer: 'D1',
        mandate: 'M1',
        reraId: 'R1',
        constructionStatus: 'CS1',
        propertyType: 'PT1',
        description: 'Desc1',
        projectRm: 'RM1',
        locationName: '',
        city: 'City B',
        state: 'State C',
        nearbyLandmarks: 'NL1',
        projectApproval: 'PA1',
        developmentScheme: 'DS1',
        priceRangeMin: 1,
        priceRangeMax: 2,
        parkingType: 'PK1',
        launchDate: 'LD1',
        possessionDate: 'PD1',
        targetPossession: 'TP1',
        architect: 'A1',
        contractor: 'C1',
        electricalContractor: 'EC1',
        reraLiasoning: 'RL1',
        documents: [],
        configurations: [],
        galleryImages: [],
        amenities: [],
        brokerageSlabs: [],
        projectTimeline: [],
        creation: 'C',
        modified: 'M',
      );
      expect(project2.locationDisplay, 'City B, State C');

      final project3 = Project(
        id: '1',
        projectName: 'P1',
        developer: 'D1',
        mandate: 'M1',
        reraId: 'R1',
        constructionStatus: 'CS1',
        propertyType: 'PT1',
        description: 'Desc1',
        projectRm: 'RM1',
        locationName: '',
        city: '',
        state: '',
        location: 'Specific Location',
        nearbyLandmarks: 'NL1',
        projectApproval: 'PA1',
        developmentScheme: 'DS1',
        priceRangeMin: 1,
        priceRangeMax: 2,
        parkingType: 'PK1',
        launchDate: 'LD1',
        possessionDate: 'PD1',
        targetPossession: 'TP1',
        architect: 'A1',
        contractor: 'C1',
        electricalContractor: 'EC1',
        reraLiasoning: 'RL1',
        documents: [],
        configurations: [],
        galleryImages: [],
        amenities: [],
        brokerageSlabs: [],
        projectTimeline: [],
        creation: 'C',
        modified: 'M',
      );
      expect(project3.locationDisplay, 'Specific Location');
    });
  });
}
