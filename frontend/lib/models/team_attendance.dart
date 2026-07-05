class TeamAttendance {
  final String name;
  final String employee;
  final String employeeName;
  final double workingHours;
  final String status;
  final String attendanceDate;
  final String? inTime;
  final String? outTime;
  final int lateEntry;
  final int earlyExit;
  final String? department;

  TeamAttendance({
    required this.name,
    required this.employee,
    required this.employeeName,
    required this.workingHours,
    required this.status,
    required this.attendanceDate,
    this.inTime,
    this.outTime,
    required this.lateEntry,
    required this.earlyExit,
    this.department,
  });

  factory TeamAttendance.fromJson(Map<String, dynamic> json) {
    return TeamAttendance(
      name: json['name'] ?? '',
      employee: json['employee'] ?? '',
      employeeName: json['employee_name'] ?? '',
      workingHours: (json['working_hours'] ?? 0.0).toDouble(),
      status: json['status'] ?? '',
      attendanceDate: json['attendance_date'] ?? '',
      inTime: json['in_time'],
      outTime: json['out_time'],
      lateEntry: json['late_entry'] ?? 0,
      earlyExit: json['early_exit'] ?? 0,
      department: json['department'],
    );
  }
}
