
class SalaryComponent {
  final String component;
  final double amount;
  final double yearToDate;

  SalaryComponent({
    required this.component,
    required this.amount,
    required this.yearToDate,
  });

  factory SalaryComponent.fromJson(Map<String, dynamic> json) {
    return SalaryComponent(
      component: json['component'],
      amount: (json['amount'] as num).toDouble(),
      yearToDate: (json['year_to_date'] as num).toDouble(),
    );
  }
}
