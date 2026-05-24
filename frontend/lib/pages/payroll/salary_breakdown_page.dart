import 'package:Homesol/services/apis/workforces/workforce.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:Homesol/models/salary_breakdown.dart';
import 'package:Homesol/services/api_service.dart';
import 'package:url_launcher/url_launcher.dart';

class SalaryBreakdownPage extends StatefulWidget {
  final String salarySlipId;

  const SalaryBreakdownPage({Key? key, required this.salarySlipId}) : super(key: key);

  @override
  _SalaryBreakdownPageState createState() => _SalaryBreakdownPageState();
}

class _SalaryBreakdownPageState extends State<SalaryBreakdownPage> {
  late Future<SalaryBreakdown> _breakdownFuture;

  // -- Theme Colors based on your request --
  final Color kPrimaryColor = const Color(0xFF675D40); // The Olive/Brown
  final Color kBackgroundColor = const Color(0xFFF0EEE6); // The Warm White
  final Color kSurfaceColor = const Color(0xFFFFFFFF); // Pure White for Cards

  @override
  void initState() {
    super.initState();
    _breakdownFuture = WorkforceService.getSalaryBreakdown(widget.salarySlipId);
  }

  // Helper to sum up components for section headers
  double _getSectionTotal(List<dynamic> components) {
    return components.fold(0.0, (sum, item) => sum + (item.amount as double));
  }

  void _downloadSalarySlip(BuildContext context) async {
    try {
      final String pdfUrl = await WorkforceService.downloadSalarySlip(widget.salarySlipId);
      if (await canLaunchUrl(Uri.parse(pdfUrl))) {
        await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
        CustomSnackBar.show(context, message: 'Downloading PDF...', isError: false, title: 'Notice');
      } else {
        throw 'Could not launch $pdfUrl';
      }
    } catch (e) {
      CustomSnackBar.show(context, message: 'Failed to download slip: $e', isError: true, title: 'Error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        backgroundColor: kBackgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: kPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Salary Details',
          style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.download, color: kPrimaryColor),
            onPressed: () => _downloadSalarySlip(context),
          ),
        ],
      ),
      body: FutureBuilder<SalaryBreakdown>(
        future: _breakdownFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: kPrimaryColor));
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return Center(child: Text('No data found.'));
          } else {
            final breakdown = snapshot.data!;
            return SingleChildScrollView(
              padding: EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // 1. The Big Summary Card
                  _buildHeroCard(breakdown),
                  
                  SizedBox(height: 24),
                  
                  // 2. Earnings Section
                  _buildSectionHeader('Earnings', breakdown.earnings, isPositive: true),
                  _buildComponentList(breakdown.earnings, isPositive: true),
                  
                  SizedBox(height: 24),
                  
                  // 3. Deductions Section
                  _buildSectionHeader('Deductions', breakdown.deductions, isPositive: false),
                  _buildComponentList(breakdown.deductions, isPositive: false),
                  
                  SizedBox(height: 40),
                ],
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildHeroCard(SalaryBreakdown breakdown) {
    // Calculate percentage for the visual bar
    double netPercentage = (breakdown.netPay / breakdown.grossPay).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: kPrimaryColor.withOpacity(0.08),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // Date Pill
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kBackgroundColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${breakdown.startDate.day} ${_getMonthName(breakdown.startDate.month)} - ${breakdown.endDate.day} ${_getMonthName(breakdown.endDate.month)} ${breakdown.endDate.year}',
              style: TextStyle(
                color: kPrimaryColor.withOpacity(0.8),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(height: 20),
          
          // Net Pay (Hero)
          Text(
            "Net Pay",
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            "₹${breakdown.netPay.toStringAsFixed(2)}",
            style: TextStyle(
              color: kPrimaryColor,
              fontSize: 36,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          
          SizedBox(height: 24),
          
          // Visual Bar (Net vs Gross)
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: netPercentage,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
            ),
          ),
          SizedBox(height: 24),

          // Grid Summary
          Row(
            children: [
              Expanded(
                child: _buildMiniStat(
                  "Gross Pay", 
                  breakdown.grossPay, 
                  Colors.black87
                ),
              ),
              Container(width: 1, height: 40, color: Colors.grey[200]),
              Expanded(
                child: _buildMiniStat(
                  "Deductions", 
                  breakdown.totalDeduction, 
                  Colors.red[400]!
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color valueColor) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey[500], fontSize: 12),
        ),
        SizedBox(height: 4),
        Text(
          "₹${value.toStringAsFixed(0)}",
          style: TextStyle(
            color: valueColor,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, List<dynamic> components, {required bool isPositive}) {
    double total = _getSectionTotal(components);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: kPrimaryColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            "${isPositive ? '+' : '-'} ₹${total.toStringAsFixed(2)}",
            style: TextStyle(
              color: isPositive ? kPrimaryColor : Colors.red[400],
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentList(List<dynamic> components, {required bool isPositive}) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2), // Clean border
      ),
      child: Column(
        children: components.asMap().entries.map((entry) {
          int idx = entry.key;
          var comp = entry.value;
          bool isLast = idx == components.length - 1;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      comp.component,
                      style: TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      "₹${comp.amount.toStringAsFixed(2)}",
                      style: TextStyle(
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isLast) 
                Divider(height: 1, indent: 20, endIndent: 20, color: Colors.grey[100]),
            ],
          );
        }).toList(),
      ),
    );
  }

  // Simple helper for month names
  String _getMonthName(int month) {
    const months = [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun", 
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"
    ];
    return months[month - 1];
  }
}