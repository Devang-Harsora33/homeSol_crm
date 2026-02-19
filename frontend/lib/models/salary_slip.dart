
import 'package:intl/intl.dart';

class SalarySlip {
  final String name;
  final DateTime startDate;
  final DateTime endDate;
  final double netPay;
  final double grossPay;
  final DateTime postingDate;

  SalarySlip({
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.netPay,
    required this.grossPay,
    required this.postingDate,
  });

  String get monthYear {
    return DateFormat('MMMM yyyy').format(startDate);
  }

  factory SalarySlip.fromJson(Map<String, dynamic> json) {
    return SalarySlip(
      name: json['name'],
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      netPay: (json['net_pay'] as num).toDouble(),
      grossPay: (json['gross_pay'] as num).toDouble(),
      postingDate: DateTime.parse(json['posting_date']),
    );
  }
}
