import 'package:Homesol/services/apis/workforces/workforce.dart';
import 'package:flutter/material.dart';
import 'package:Homesol/models/salary_slip.dart';
import 'package:Homesol/pages/payroll/salary_breakdown_page.dart';

class SalarySlipsPage extends StatefulWidget {
  @override
  _SalarySlipsPageState createState() => _SalarySlipsPageState();
}

class _SalarySlipsPageState extends State<SalarySlipsPage> {
  late Future<List<SalarySlip>> _salarySlipsFuture;

  @override
  void initState() {
    super.initState();
    _salarySlipsFuture = WorkforceService.getSalarySlips();
  }

  // Helper to calculate total for the UI Summary
  double _calculateTotalNetPay(List<SalarySlip> slips) {
    return slips.fold(0.0, (sum, item) => sum + item.netPay);
  }

  @override
  Widget build(BuildContext context) {
    // A modern background color (Off-white/Light Grey)
    return Scaffold(
      backgroundColor: Color(0xFFF5F7FA), 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        title: Text(
          'My Pay',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w800,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list_rounded, color: Colors.black87),
            onPressed: () {}, // Add filter logic later
          ),
        ],
      ),
      body: FutureBuilder<List<SalarySlip>>(
        future: _salarySlipsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: 3, // Display 3 skeleton cards
              itemBuilder: (context, index) => _SalaryCardSkeleton(), // Removed const
            );
          } else if (snapshot.hasError) {
            return _buildErrorState(snapshot.error.toString());
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _buildEmptyState();
          } else {
            final slips = snapshot.data!;
            return Column(
              children: [
                // 1. Summary Header (UX Improvement)
                _buildSummaryHeader(slips),
                
                // 2. The List
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    itemCount: slips.length,
                    itemBuilder: (context, index) {
                      final slip = slips[index];
                      return _buildSalaryCard(context, slip);
                    },
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildSummaryHeader(List<SalarySlip> slips) {
    return Container(
      width: double.infinity,
      margin: EdgeInsets.fromLTRB(16, 0, 16, 16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF000000), Color(0xFF675d40)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF1E3C72).withOpacity(0.3),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Total Net Earned",
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          SizedBox(height: 8),
          Text(
            "₹${_calculateTotalNetPay(slips).toStringAsFixed(2)}",
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaryCard(BuildContext context, SalarySlip slip) {
    // Splitting month/year logic (Assuming format "January 2026")
    // If your format is different, adjust this logic.
    List<String> dateParts = slip.monthYear.split(' ');
    String month = dateParts.isNotEmpty ? dateParts[0].substring(0, 3).toUpperCase() : "N/A";
    String year = dateParts.length > 1 ? dateParts[1] : "";

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => SalaryBreakdownPage(salarySlipId: slip.name),
                          ),
                        );
                      },          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                // Date Badge
                Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Color(0xFFf0eee6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      Text(
                        month,
                        style: TextStyle(
                          color: Color(0xFF675d40),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        year,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16),
                
                // Money Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Net Pay",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "₹${slip.netPay.toStringAsFixed(2)}",
                        style: TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        "Gross: ₹${slip.grossPay.toStringAsFixed(0)}",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Arrow Icon
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey[300]),
          SizedBox(height: 16),
          Text(
            "No payslips yet",
            style: TextStyle(color: Colors.grey[500], fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: Colors.red[300]),
            SizedBox(height: 16),
            Text(
              "Something went wrong",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _SalaryCardSkeleton extends StatelessWidget {
  const _SalaryCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color? skeletonColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Date Badge Skeleton
          Container(
            width: 60,
            height: 50,
            decoration: BoxDecoration(
              color: skeletonColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(width: 16),
          
          // Money Details Skeleton
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  color: skeletonColor,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 120,
                  height: 18,
                  color: skeletonColor,
                ),
                const SizedBox(height: 4),
                Container(
                  width: 100,
                  height: 12,
                  color: skeletonColor,
                ),
              ],
            ),
          ),
          
          // Arrow Icon Skeleton
          Container(
            width: 16,
            height: 16,
            color: skeletonColor,
          ),
        ],
      ),
    );
  }
}