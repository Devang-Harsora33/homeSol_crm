class PropertyUnit {
  final String name;
  final String floorNumber;
  final String flatNo;
  final String configuration;
  final double carpetArea;
  final String unitStatus;
  final String? clientName; // This will hold the lead name
  final String? modifiedBy;

  PropertyUnit({
    required this.name,
    required this.floorNumber,
    required this.flatNo,
    required this.configuration,
    required this.carpetArea,
    required this.unitStatus,
    this.clientName,
    this.modifiedBy,
  });

  factory PropertyUnit.fromJson(Map<String, dynamic> json) {
    return PropertyUnit(
      name: json['name'] ?? '',
      floorNumber: json['floor_number']?.toString() ?? '',
      flatNo: json['flat_no']?.toString() ?? '',
      configuration: json['configuration'] ?? '',
      carpetArea: (json['carpet_area'] ?? 0.0).toDouble(),
      unitStatus: json['unit_status'] ?? 'Available',
      clientName: json['client_name'],
      modifiedBy: json['modified_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'floor_number': floorNumber,
      'flat_no': flatNo,
      'configuration': configuration,
      'carpet_area': carpetArea,
      'unit_status': unitStatus,
      'client_name': clientName,
      'modified_by': modifiedBy,
    };
  }
}
