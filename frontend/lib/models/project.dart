// import 'dart:convert';
// import 'developer.dart';

class BrokerageSlab {
  final int fromBooking;
  final int toBooking;
  final double percentage;
  final double incentive;

  BrokerageSlab({
    required this.fromBooking,
    required this.toBooking,
    required this.percentage,
    required this.incentive,
  });

  factory BrokerageSlab.fromJson(Map<String, dynamic> json) {
    return BrokerageSlab(
      fromBooking: (json['from_booking'] ?? 0).toInt(),
      toBooking: (json['to_booking'] ?? 0).toInt(),
      percentage: (json['percentage'] ?? 0.0).toDouble(),
      incentive: (json['incentive'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'from_booking': fromBooking,
      'to_booking': toBooking,
      'percentage': percentage,
      'incentive': incentive,
    };
  }
}

class Configuration {
  final String name;
  final double carpetArea;
  final double price;

  Configuration({
    required this.name,
    required this.carpetArea,
    required this.price,
  });

  factory Configuration.fromJson(Map<String, dynamic> json) {
    return Configuration(
      name: json['configuration_name'] ?? '',
      carpetArea: (json['carpet_area'] ?? 0.0).toDouble(),
      price: (json['price'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'configuration_name': name,
      'carpet_area': carpetArea,
      'price': price,
    };
  }
}

class ProjectTimeline {
  final String milestone;
  final String targetDate;
  final String status;

  ProjectTimeline({
    required this.milestone,
    required this.targetDate,
    required this.status,
  });

  factory ProjectTimeline.fromJson(Map<String, dynamic> json) {
    return ProjectTimeline(
      milestone: json['milestone'] ?? '',
      targetDate: json['target_date'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class ProjectAmenity {
  final String data;
  ProjectAmenity({required this.data});
  factory ProjectAmenity.fromJson(Map<String, dynamic> json) {
    return ProjectAmenity(data: json['data'] ?? '');
  }
}

class ProjectDocument {
  final String documentName;
  final String file;
  ProjectDocument({required this.documentName, required this.file});
  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    return ProjectDocument(
      documentName: json['document_name'] ?? '',
      file: json['file'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {'document_name': documentName, 'file': file};
  }
}

class ProjectBrochure {
  final String brochureName;
  final String file;
  ProjectBrochure({required this.brochureName, required this.file});
  factory ProjectBrochure.fromJson(Map<String, dynamic> json) {
    return ProjectBrochure(
      brochureName: json['brochure_name'] ?? '',
      file: json['file'] ?? '',
    );
  }
  Map<String, dynamic> toJson() {
    return {'brochure_name': brochureName, 'file': file};
  }
}

class ProjectImage {
  final String images;
  ProjectImage({required this.images});
  factory ProjectImage.fromJson(Map<String, dynamic> json) {
    return ProjectImage(images: json['images'] ?? '');
  }
}

class Project {
  final String id;
  final String projectName;
  final String developer;
  final String? developerName;
  final String mandate;
  final String? mandateName;
  final String reraId;
  final String constructionStatus;
  final String propertyType;
  final String description;
  final String projectRm;
  final String locationName;
  final String city;
  final String state;
  final String? location;
  final String? loginCoordinates;
  final String nearbyLandmarks;
  final String projectApproval;
  final String developmentScheme;
  final int priceRangeMin;
  final int priceRangeMax;
  final String parkingType;
  final String launchDate;
  final String possessionDate;
  final String targetPossession;
  final String architect;
  final String contractor;
  final String electricalContractor;
  final String reraLiasoning;
  final List<ProjectDocument> documents;
  final List<ProjectBrochure> brochures;
  final List<Configuration> configurations;
  final List<ProjectImage> galleryImages;
  final List<ProjectAmenity> amenities;
  final List<BrokerageSlab> brokerageSlabs;
  final List<ProjectTimeline> projectTimeline;
  final String creation;
  final String modified;

  Project({
    required this.id,
    required this.projectName,
    required this.developer,
    this.developerName,
    required this.mandate,
    this.mandateName,
    required this.reraId,
    required this.constructionStatus,
    required this.propertyType,
    required this.description,
    required this.projectRm,
    required this.locationName,
    required this.city,
    required this.state,
    this.location,
    this.loginCoordinates,
    required this.nearbyLandmarks,
    required this.projectApproval,
    required this.developmentScheme,
    required this.priceRangeMin,
    required this.priceRangeMax,
    required this.parkingType,
    required this.launchDate,
    required this.possessionDate,
    required this.targetPossession,
    required this.architect,
    required this.contractor,
    required this.electricalContractor,
    required this.reraLiasoning,
    required this.documents,
    this.brochures = const [],
    required this.configurations,
    required this.galleryImages,
    required this.amenities,
    required this.brokerageSlabs,
    required this.projectTimeline,
    required this.creation,
    required this.modified,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['name'] ?? '',
      projectName: json['project_name'] ?? '',
      developer: json['developer'] ?? '',
      developerName: json['developer_name'],
      mandate: json['mandate'] ?? '',
      mandateName: json['mandate_name'],
      reraId: json['rera_id'] ?? '',
      constructionStatus: json['construction_status'] ?? '',
      propertyType: json['property_type'] ?? '',
      description: json['description'] ?? '',
      projectRm: json['project_rm'] ?? '',
      locationName: json['location_name'] ?? '',
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      location: json['location'],
      loginCoordinates: json['login_coordinates'],
      nearbyLandmarks: json['nearby_landmarks'] ?? '',
      projectApproval: json['project_approval'] ?? '',
      developmentScheme: json['development_scheme'] ?? '',
      priceRangeMin: (json['price_range_min'] ?? 0).toInt(),
      priceRangeMax: (json['price_range_max'] ?? 0).toInt(),
      parkingType: json['parking_type'] ?? '',
      launchDate: json['launch_date'] ?? '',
      possessionDate: json['possession_date'] ?? '',
      targetPossession: json['target_possession'] ?? '',
      architect: json['architect'] ?? '',
      contractor: json['contractor'] ?? '',
      electricalContractor: json['electrical_contractor'] ?? '',
      reraLiasoning: json['rera_liasoning'] ?? '',
      documents:
          (json['documents'] as List<dynamic>?)
              ?.map((e) => ProjectDocument.fromJson(e))
              .toList() ??
          [],
      brochures:
          (json['brochure'] as List<dynamic>?)
              ?.map((e) => ProjectBrochure.fromJson(e))
              .toList() ??
          [],
      configurations:
          (json['configurations'] as List<dynamic>?)
              ?.map((e) => Configuration.fromJson(e))
              .toList() ??
          [],
      galleryImages:
          (json['gallery_images'] as List<dynamic>?)
              ?.map((e) => ProjectImage.fromJson(e))
              .toList() ??
          [],
      amenities:
          (json['amenities'] as List<dynamic>?)
              ?.map((e) => ProjectAmenity.fromJson(e))
              .toList() ??
          [],
      brokerageSlabs:
          (json['brokerage_slabs'] as List<dynamic>?)
              ?.map((e) => BrokerageSlab.fromJson(e))
              .toList() ??
          [],
      projectTimeline:
          (json['project_timeline'] as List<dynamic>?)
              ?.map((e) => ProjectTimeline.fromJson(e))
              .toList() ??
          [],
      creation: json['creation'] ?? '',
      modified: json['modified'] ?? '',
    );
  }

  String get locationDisplay {
    final parts = <String>[];
    if (locationName.isNotEmpty) parts.add(locationName);
    if (city.isNotEmpty) parts.add(city);
    if (state.isNotEmpty) parts.add(state);
    if (parts.isNotEmpty) return parts.join(', ');
    return location ?? '';
  }

  // Alias getters to match UI expectations (snake_case or different names)
  String get location_name => locationName;
  String get priceRange => '₹${priceRangeMin}L - ₹${priceRangeMax}L';
  List<ProjectImage> get images => galleryImages;

  // Developer ID alias
  String get developerId => developer;

  // Location coordinates placeholder (if needed)
  Map<String, double>? get locationCoordinates => null;
}
