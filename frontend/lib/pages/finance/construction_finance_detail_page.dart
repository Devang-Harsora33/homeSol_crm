import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/apis/finance/finance_service.dart';
import '../../models/finance/construction_finance_application.dart';

const Color kAccent = Color(0xFF675D40);

class ConstructionFinanceDetailPage extends StatelessWidget {
  final ConstructionFinanceApplication application;

  const ConstructionFinanceDetailPage({super.key, required this.application});

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

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        title: const Text(
          'Application Details',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              application.project.isNotEmpty ? application.project : 'Application Details',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              application.name,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade500,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(radius: 4, backgroundColor: statusColor),
                            const SizedBox(width: 8),
                            Text(
                              application.status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: kAccent.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.monetization_on_rounded, color: kAccent, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Fund Required', style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 4),
                            Text(
                              '${application.fundRequirement.toStringAsFixed(application.fundRequirement.truncateToDouble() == application.fundRequirement ? 0 : 1)} Cr',
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black87),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Details Card
            const Padding(
              padding: EdgeInsets.only(left: 8, bottom: 12),
              child: Text(
                'Application Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: Column(
                children: [
                  if (application.developerName != null) ...[
                    _buildDetailRow('Developer', application.developerName!, Icons.person_rounded),
                    const Divider(height: 32, thickness: 1),
                  ],
                  _buildDetailRow('Developer ID', application.developer, Icons.badge_rounded),
                  const Divider(height: 32, thickness: 1),
                  _buildDetailRow('Meeting Type', '${application.meetingType} Meeting', application.meetingType.toLowerCase() == 'online' ? Icons.videocam_rounded : Icons.handshake_rounded),
                  const Divider(height: 32, thickness: 1),
                  _buildDetailRow(
                    'Meeting Schedule',
                    application.meetingSchedule.isNotEmpty ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(application.meetingSchedule)) : 'Pending',
                    Icons.access_time_filled_rounded
                  ),
                  const Divider(height: 32, thickness: 1),
                  _buildDetailRow(
                    'Created On',
                    application.creation.isNotEmpty ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(application.creation)) : 'Unknown',
                    Icons.calendar_today_rounded
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: Colors.grey.shade600),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  color: Colors.black87,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
