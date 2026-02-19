
// import 'package:flutter/material.dart';

enum AttendanceStatus {
  present,
  absent,
  onLeave,
  holiday,
  unknown,
}

AttendanceStatus mapAttendanceStatus(String status) {
  switch (status.toLowerCase()) {
    case 'present':
      return AttendanceStatus.present;
    case 'absent':
      return AttendanceStatus.absent;
    case 'on leave':
      return AttendanceStatus.onLeave;
    case 'holiday':
      return AttendanceStatus.holiday;
    default:
      return AttendanceStatus.unknown;
  }
}

class AttendanceRecord {
  final DateTime attendanceDate;
  final AttendanceStatus status;

  AttendanceRecord({
    required this.attendanceDate,
    required this.status,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      attendanceDate: DateTime.parse(json['attendance_date']),
      status: mapAttendanceStatus(json['status']),
    );
  }
}
