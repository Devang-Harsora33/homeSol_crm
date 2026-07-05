class TeamCheckin {
  final String name;
  final String employee;
  final String employeeName;
  final String logType; // IN or OUT
  final String time;
  final String? deviceId;
  final double? latitude;
  final double? longitude;
  final String? customRemark;

  TeamCheckin({
    required this.name,
    required this.employee,
    required this.employeeName,
    required this.logType,
    required this.time,
    this.deviceId,
    this.latitude,
    this.longitude,
    this.customRemark,
  });

  factory TeamCheckin.fromJson(Map<String, dynamic> json) {
    return TeamCheckin(
      name: json['name'] ?? '',
      employee: json['employee'] ?? '',
      employeeName: json['employee_name'] ?? '',
      logType: json['log_type'] ?? '',
      time: json['time'] ?? '',
      deviceId: json['device_id'],
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      customRemark: json['custom_remark'],
    );
  }
}
