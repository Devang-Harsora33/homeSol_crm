import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/apis/finance/finance_service.dart';
import '../../models/finance/construction_finance_application.dart';
import 'construction_finance_detail_page.dart';

const Color kAccent = Color(0xFF675D40);

class ConstructionFinanceListPage extends StatefulWidget {
  final String developerId;

  const ConstructionFinanceListPage({super.key, required this.developerId});

  @override
  State<ConstructionFinanceListPage> createState() => _ConstructionFinanceListPageState();
}

class _ConstructionFinanceListPageState extends State<ConstructionFinanceListPage> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ConstructionFinanceApplication> _applications = [];

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  Future<void> _fetchApplications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final apps = await FinanceService.fetchConstructionFinanceApplications(widget.developerId);
      apps.sort((a, b) => b.creation.compareTo(a.creation));
      if (mounted) {
        setState(() {
          _applications = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Finance Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchApplications,
        color: kAccent,
        child: _isLoading
            ? ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: 3,
                itemBuilder: (context, index) => const _ApplicationCardSkeleton(),
              )
            : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchApplications,
                          style: ElevatedButton.styleFrom(backgroundColor: kAccent),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  )
                : _applications.isEmpty
                    ? const Center(
                        child: Text(
                          'No Applications Found',
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _applications.length,
                        itemBuilder: (context, index) {
                          final app = _applications[index];
                          return _ApplicationCard(
                            application: app,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ConstructionFinanceDetailPage(
                                    application: app,
                                  ),
                                ),
                              ).then((_) => _fetchApplications());
                            },
                          );
                        },
                      ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  final ConstructionFinanceApplication application;
  final VoidCallback onTap;

  const _ApplicationCard({required this.application, required this.onTap});

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'submitted':
        return Colors.blueAccent;
      case 'approved':
        return Colors.green;
      case 'rejected':
        return Colors.redAccent;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(application.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.apartment_rounded, color: kAccent, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          application.project.isNotEmpty ? application.project : 'Application Details',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                            color: Colors.black87,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          application.name,
                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: statusColor),
                        const SizedBox(width: 6),
                        Text(
                          application.status,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            
            // Body Section
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Fund Required
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.monetization_on_rounded, size: 14, color: Colors.grey.shade500),
                            const SizedBox(width: 4),
                            Text('Fund Required', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${application.fundRequirement.toStringAsFixed(application.fundRequirement.truncateToDouble() == application.fundRequirement ? 0 : 1)} Cr',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  
                  Container(width: 1.5, height: 40, color: Colors.grey.shade200),
                  
                  // Meeting Schedule
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(left: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                application.meetingType.toLowerCase() == 'online' ? Icons.videocam_rounded : Icons.handshake_rounded, 
                                size: 14, 
                                color: Colors.grey.shade500
                              ),
                              const SizedBox(width: 4),
                              Text('${application.meetingType} Meeting', style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            application.meetingSchedule.isNotEmpty 
                                ? DateFormat('dd MMM, hh:mm a').format(DateTime.parse(application.meetingSchedule))
                                : 'Pending',
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApplicationCardSkeleton extends StatelessWidget {
  const _ApplicationCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(width: 120, height: 16, color: Colors.grey.shade200),
              Container(width: 60, height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20))),
            ],
          ),
          const SizedBox(height: 16),
          Container(width: double.infinity, height: 14, color: Colors.grey.shade200),
          const SizedBox(height: 12),
          Container(width: 150, height: 14, color: Colors.grey.shade200),
        ],
      ),
    );
  }
}
