
import 'package:Homesol/models/salary_component.dart';

class SalaryBreakdown {
  final DateTime startDate;
  final DateTime endDate;
  final double netPay;
  final double grossPay;
  final double totalDeduction;
  final List<SalaryComponent> earnings;
  final List<SalaryComponent> deductions;

  SalaryBreakdown({
    required this.startDate,
    required this.endDate,
    required this.netPay,
    required this.grossPay,
    required this.totalDeduction,
    required this.earnings,
    required this.deductions,
  });

  factory SalaryBreakdown.fromJson(Map<String, dynamic> json) {
    var earningsList = json['earnings'] as List;
    var deductionsList = json['deductions'] as List;

    List<SalaryComponent> earnings =
        earningsList.map((i) => SalaryComponent.fromJson(i)).toList();
    List<SalaryComponent> deductions =
        deductionsList.map((i) => SalaryComponent.fromJson(i)).toList();

    return SalaryBreakdown(
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      netPay: (json['net_pay'] as num).toDouble(),
      grossPay: (json['gross_pay'] as num).toDouble(),
      totalDeduction: (json['total_deduction'] as num).toDouble(),
      earnings: earnings,
      deductions: deductions,
    );
  }
}
