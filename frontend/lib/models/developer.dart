import 'dart:convert';

class BankDetails {
  final String accountNumber;
  final String ifscCode;
  final String bankName;

  BankDetails({
    required this.accountNumber,
    required this.ifscCode,
    required this.bankName,
  });

  factory BankDetails.fromJson(Map<String, dynamic> json) {
    return BankDetails(
      accountNumber: json['account_number'] ?? '',
      ifscCode: json['ifsc_code'] ?? '',
      bankName: json['bank_name'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_number': accountNumber,
      'ifsc_code': ifscCode,
      'bank_name': bankName,
    };
  }
}

class LocationCoordinates {
  final double latitude;
  final double longitude;

  LocationCoordinates({required this.latitude, required this.longitude});

  factory LocationCoordinates.fromJson(Map<String, dynamic> json) {
    return LocationCoordinates(
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'latitude': latitude, 'longitude': longitude};
  }
}

class DeveloperProject {
  final String project;
  final String projectName;
  final String startDate;
  final String status;

  DeveloperProject({
    required this.project,
    required this.projectName,
    required this.startDate,
    required this.status,
  });

  factory DeveloperProject.fromJson(Map<String, dynamic> json) {
    return DeveloperProject(
      project: json['project'] ?? '',
      projectName: json['project_name'] ?? '',
      startDate: json['start_date'] ?? '',
      status: json['status'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project': project,
      'project_name': projectName,
      'start_date': startDate,
      'status': status,
    };
  }
}

class Developer {
  final String id;
  final String createdAt;
  final String updatedAt;
  final String username;
  final String email;
  final String developerName;
  final String reraNumber;
  final String gstNumber;
  final String panNumber;
  final String officeAddress;
  final String contactPerson;
  final String contactEmail;
  final String contactPhone;
  final String companySize;
  final List<String> specializations;
  final List<String> certifications;
  final BankDetails bankDetails;
  final String kycStatus;
  final bool isVerified;
  final bool isActive;
  final String websiteUrl;
  final String logoUrl;
  final String companyDescription;
  final int yearEstablished;
  final int totalProjectsCompleted;
  final int currentProjectsCount;
  final List<String> stories;
  final List<DeveloperProject> projectsList;
  final LocationCoordinates? locationCoordinates;

  Developer({
    required this.id,
    required this.createdAt,
    required this.updatedAt,
    required this.username,
    required this.email,
    required this.developerName,
    required this.reraNumber,
    required this.gstNumber,
    required this.panNumber,
    required this.officeAddress,
    required this.contactPerson,
    required this.contactEmail,
    required this.contactPhone,
    required this.companySize,
    required this.specializations,
    required this.certifications,
    required this.bankDetails,
    required this.kycStatus,
    required this.isVerified,
    required this.isActive,
    required this.websiteUrl,
    required this.logoUrl,
    required this.companyDescription,
    required this.yearEstablished,
    required this.totalProjectsCompleted,
    required this.currentProjectsCount,
    required this.stories,
    required this.projectsList,
    this.locationCoordinates,
  });

  factory Developer.fromJson(Map<String, dynamic> json) {
    // Parse year_established from date string
    int yearEstablished = 0;
    if (json['year_established'] != null) {
      try {
        final dateStr = json['year_established'].toString();
        if (dateStr.contains('-')) {
          yearEstablished = int.parse(dateStr.split('-')[0]);
        } else {
          yearEstablished = int.tryParse(dateStr) ?? 0;
        }
      } catch (e) {
        yearEstablished = 0;
      }
    }

    // Parse projects from projects_list
    List<DeveloperProject> projectsList = [];
    if (json['projects_list'] != null) {
      final projectsListJson = json['projects_list'] as List<dynamic>;
      projectsList = projectsListJson
          .map((p) => DeveloperProject.fromJson(p))
          .toList();
    }

    // Parse location from GeoJSON string
    LocationCoordinates? locationCoordinates;
    if (json['location'] != null) {
      try {
        final locationJson = jsonDecode(json['location']);
        if (locationJson['type'] == 'FeatureCollection' &&
            locationJson['features'] != null &&
            locationJson['features'].isNotEmpty) {
          final geometry = locationJson['features'][0]['geometry'];
          if (geometry['type'] == 'Point' && geometry['coordinates'] != null) {
            final coords = geometry['coordinates'] as List;
            locationCoordinates = LocationCoordinates(
              latitude: coords[1].toDouble(),
              longitude: coords[0].toDouble(),
            );
          }
        }
      } catch (e) {
        // Ignore parsing errors
      }
    }

    List<String> specializations = (json['specializations'] as String? ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    List<String> certifications = (json['certifications'] as String? ?? '')
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Developer(
      id: json['name'] ?? '',
      createdAt: json['creation'] ?? '',
      updatedAt: json['modified'] ?? '',
      username: json['username'] ?? '',
      email: json['email'] ?? '',
      developerName: json['developer_name'] ?? '',
      reraNumber: json['rera_number'] ?? '',
      gstNumber: json['gst_number'] ?? '',
      panNumber: json['pan_number'] ?? '',
      officeAddress: json['office_address'] ?? '',
      contactPerson: json['contact_person'] ?? '',
      contactEmail: json['contact_email'] ?? '',
      contactPhone: json['contact_phone'] ?? '',
      companySize: json['company_size'] ?? '',
      specializations: specializations,
      certifications: certifications,
      bankDetails: json['bank_details'] != null
          ? BankDetails.fromJson(json['bank_details'])
          : BankDetails(accountNumber: '', ifscCode: '', bankName: ''),
      kycStatus: json['kyc_status'] ?? '',
      isVerified: (json['is_verified'] ?? 0) == 1,
      isActive: (json['is_active'] ?? 0) == 1,
      websiteUrl: json['website_url'] ?? '',
      logoUrl: json['logo'] ?? '',
      companyDescription: json['company_description'] ?? '',
      yearEstablished: yearEstablished,
      totalProjectsCompleted: json['total_projects_completed'] ?? 0,
      currentProjectsCount: json['current_projects_count'] ?? 0,
      stories: List<String>.from(json['stories'] ?? []),
      projectsList: projectsList,
      locationCoordinates: locationCoordinates,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'username': username,
      'email': email,
      'developer_name': developerName,
      'rera_number': reraNumber,
      'gst_number': gstNumber,
      'pan_number': panNumber,
      'office_address': officeAddress,
      'contact_person': contactPerson,
      'contact_email': contactEmail,
      'contact_phone': contactPhone,
      'company_size': companySize,
      'specializations': specializations,
      'certifications': certifications,
      'bank_details': bankDetails.toJson(),
      'kyc_status': kycStatus,
      'is_verified': isVerified,
      'is_active': isActive,
      'website_url': websiteUrl,
      'logo_url': logoUrl,
      'company_description': companyDescription,
      'year_established': yearEstablished,
      'total_projects_completed': totalProjectsCompleted,
      'current_projects_count': currentProjectsCount,
      'stories': stories,
      'projects_list': projectsList.map((p) => p.toJson()).toList(),
      'location_coordinates': locationCoordinates?.toJson(),
    };
  }
}

