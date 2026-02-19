class LeaveBalance {
  final String leaveType;
  final double allocated;
  final double used;
  final double remaining;

  LeaveBalance({
    required this.leaveType,
    required this.allocated,
    required this.used,
    required this.remaining,
  });

  factory LeaveBalance.fromJson(Map<String, dynamic> json) {
    return LeaveBalance(
      leaveType: json['leave_type'],
      allocated: (json['allocated'] as num).toDouble(),
      used: (json['used'] as num).toDouble(),
      remaining: (json['remaining'] as num).toDouble(),
    );
  }
}
