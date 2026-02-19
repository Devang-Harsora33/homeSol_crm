import 'package:Homesol/services/apis/tickets/ticker_service.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Recommended for better icons
import '../models/ticket.dart';

// Define the Theme Colors locally for this page
const Color kGold = Color(0xFF675E40);
const Color kBlack = Color(0xFF1A1A1A);
const Color kWhite = Colors.white;
const Color kGreyLight = Color(0xFFF5F5F5);
const Color kGreyText = Color(0xFF757575);

class TicketDetailPage extends StatelessWidget {
  final Ticket ticket;
  const TicketDetailPage({super.key, required this.ticket});

  @override
  Widget build(BuildContext context) {
    // Data Preparation
    final String status = ticket.status.isEmpty ? 'Open' : ticket.status;
    final String ticketId = ticket.id; // Or ticket.name if available
    final String createdAt = _formatDate(ticket.creation);

    return Scaffold(
      backgroundColor: kWhite,
      body: CustomScrollView(
        slivers: [
          // 1. Sleek Gold AppBar
          SliverAppBar(
            expandedHeight: 120.0,
            pinned: true,
            backgroundColor: kGold,
            elevation: 0,
            iconTheme: const IconThemeData(color: kWhite),
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
              centerTitle: false,
              title: Text(
                ticketId,
                style: const TextStyle(
                  color: kWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.5,
                ),
              ),
              background: Container(color: kGold),
            ),
          ),

          // 2. Main Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- Header Section: Subject & Status ---
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _StatusBadge(status: status),
                      
                    ],
                  ),
                  const SizedBox(height: 30),

                  // --- Key Metrics Grid (The "Dashboard" look) ---
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: "PRIORITY",
                          value: ticket.priority,
                          icon: FontAwesomeIcons.flag,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: "CATEGORY",
                          value: ticket.category,
                          icon: FontAwesomeIcons.layerGroup,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: "CREATED ON",
                          value: createdAt,
                          icon: FontAwesomeIcons.calendar,
                        ),
                      ),
                      // You can add "Assigned To" or "Modified" here in the 4th slot
                    ],
                  ),

                  const SizedBox(height: 32),

                  // --- Full Description Section ---
                  const _SectionHeader(title: "DESCRIPTION"),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: kGreyLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      ticket.description,
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF424242),
                        height: 1.5,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // --- Action Buttons ---
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.red.shade200),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Colors.red.shade700,
                      ),
                      onPressed: () => _handleDelete(context),
                      icon: const Icon(FontAwesomeIcons.trash, size: 16),
                      label: const Text("Cancel Ticket"),
                    ),
                  ),
                  const SizedBox(height: 40), // Bottom spacing
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleDelete(BuildContext context) async {
    // Show confirmation dialog before deleting
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Ticket?"),
        content: const Text("This action cannot be undone."),
        actions: [
          TextButton(
            child: const Text("No, Keep it", style: TextStyle(color: kBlack)),
            onPressed: () => Navigator.pop(ctx, false),
          ),
          TextButton(
            child: Text("Yes, Delete", style: TextStyle(color: Colors.red[700])),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await TicketService.deleteTicket(ticket.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket cancelled successfully'),
            backgroundColor: kGold,
          ),
        );
        Navigator.of(context).pop('deleted');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(12),
        color: kWhite,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: kGold),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                  color: kGreyText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.isEmpty ? "-" : value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: kBlack,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // Determine colors based on status text
    // Default to the Theme Gold for standard statuses
    Color bgColor = kGold.withOpacity(0.1);
    Color txtColor = kGold;

    final s = status.toLowerCase();
    if (s == 'resolved' || s == 'closed') {
      bgColor = Colors.green.withOpacity(0.1);
      txtColor = Colors.green.shade800;
    } else if (s == 'cancelled' || s == 'lost') {
      bgColor = Colors.grey.withOpacity(0.15);
      txtColor = Colors.grey.shade700;
    } else if (s == 'high') {
      bgColor = Colors.orange.withOpacity(0.1);
      txtColor = Colors.orange.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: txtColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: kGold),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: kBlack,
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// UTILS
// -----------------------------------------------------------------------------

String _formatDate(String raw) {
  if (raw.isEmpty) return '-';
  try {
    final dt = DateTime.parse(raw);
    // Simple format: 24 Jan 2026
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  } catch (_) {
    return raw;
  }
}