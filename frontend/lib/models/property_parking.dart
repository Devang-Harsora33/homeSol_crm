class PropertyParking {
  final String name;
  final String project;
  final String parkingNumber;
  final String level;
  final String parkingType;
  final String parkingStatus;
  final String? linkedUnit;
  final String? modifiedBy;

  PropertyParking({
    required this.name,
    required this.project,
    required this.parkingNumber,
    required this.level,
    required this.parkingType,
    required this.parkingStatus,
    this.linkedUnit,
    this.modifiedBy,
  });

  factory PropertyParking.fromJson(Map<String, dynamic> json) {
    return PropertyParking(
      name: json['name'] ?? '',
      project: json['project'] ?? '',
      parkingNumber: json['parking_number']?.toString() ?? '',
      level: json['level']?.toString() ?? '',
      parkingType: json['parking_type'] ?? '',
      parkingStatus: json['parking_status'] ?? 'Available',
      linkedUnit: json['linked_unit'],
      modifiedBy: json['modified_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'project': project,
      'parking_number': parkingNumber,
      'level': level,
      'parking_type': parkingType,
      'parking_status': parkingStatus,
      'linked_unit': linkedUnit,
      'modified_by': modifiedBy,
    };
  }
}
