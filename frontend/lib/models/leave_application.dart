class LeaveApplication {
  final String name;
  final String leaveType;
  final String fromDate;
  final String toDate;
  final double totalLeaveDays;
  final String status;
  final String postingDate;
  final String description;
  final int halfDay;

  LeaveApplication({
    required this.name,
    required this.leaveType,
    required this.fromDate,
    required this.toDate,
    required this.totalLeaveDays,
    required this.status,
    required this.postingDate,
    required this.description,
    required this.halfDay,
  });

  factory LeaveApplication.fromJson(Map<String, dynamic> json) {
    return LeaveApplication(
      name: json['name'] as String,
      leaveType: json['leave_type'] as String,
      fromDate: json['from_date'] as String,
      toDate: json['to_date'] as String,
      totalLeaveDays: (json['total_leave_days'] as num).toDouble(),
      status: json['status'] as String,
      postingDate: json['posting_date'] as String,
      description: json['description'] as String,
      halfDay: json['half_day'] as int,
    );
  }
}
