class PropertyUnit {
  final String name;
  final String floorNumber;
  final String flatNo;
  final String configuration;
  final double carpetArea;
  final String unitStatus;
  final String? clientName; // This will hold the lead name
  final String? modifiedBy;
  final String? paymentMethod;
  final String? wing;
  final String? side;

  PropertyUnit({
    required this.name,
    required this.floorNumber,
    required this.flatNo,
    required this.configuration,
    required this.carpetArea,
    required this.unitStatus,
    this.clientName,
    this.modifiedBy,
    this.paymentMethod,
    this.wing,
    this.side,
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
      paymentMethod: json['payment_method'],
      wing: json['wing'],
      side: json['side'],
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
      'payment_method': paymentMethod,
      'wing': wing,
      'side': side,
    };
  }
}
