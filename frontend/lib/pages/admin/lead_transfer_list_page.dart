import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:Homesol/models/lead_transfer.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/components/lead_detail_view.dart';
import 'bulk_lead_transfer_page.dart';

class LeadTransferListPage extends StatefulWidget {
  const LeadTransferListPage({super.key});

  @override
  State<LeadTransferListPage> createState() => _LeadTransferListPageState();
}

class _LeadTransferListPageState extends State<LeadTransferListPage> {
  bool _isLoading = true;
  List<LeadTransfer> _transfers = [];
  Map<String, String> _projectIdToNameMap = {};

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    setState(() => _isLoading = true);
    try {
      final projects = await ProjectService.fetchProjects();
      for (final p in projects) {
        _projectIdToNameMap[p.id] = p.projectName;
      }
      await _fetchTransfers();
    } catch (e) {
      print('Error fetching projects: $e');
      await _fetchTransfers();
    }
  }

  Future<void> _fetchTransfers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final transfers = await LeadService.fetchLeadTransfers();
      if (mounted) {
        setState(() {
          _transfers = transfers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CustomSnackBar.show(
          context,
          message: 'Failed to load transfers: $e',
          isError: true,
        );
      }
    }
  }

  Future<void> _cancelTransfer(String name) async {
    final bool confirm =
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
                SizedBox(width: 10),
                Text(
                  'Cancel Transfer',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Text(
              'Are you sure you want to cancel the transfer $name?\n\nThis action will revert the lead assignments.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text(
                  'Go Back',
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Confirm Cancel',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    setState(() => _isLoading = true);
    try {
      final success = await LeadService.cancelLeadTransfer(name);
      if (success) {
        CustomSnackBar.show(
          context,
          message: 'Transfer cancelled successfully.',
          isError: false,
        );
        _fetchTransfers();
      } else {
        setState(() => _isLoading = false);
        CustomSnackBar.show(
          context,
          message: 'Failed to cancel transfer.',
          isError: true,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      CustomSnackBar.show(context, message: 'Error: $e', isError: true);
    }
  }

  void _showLeadDetails(LeadTransfer transfer) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        bool namesLoading = true;
        Map<String, String> leadNames = {};

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            if (namesLoading) {
              final leadIds = transfer.selectedLeads
                  .map((e) => e.lead)
                  .toList();
              if (leadIds.isNotEmpty) {
                LeadService.fetchLeadNames(leadIds).then((names) {
                  if (context.mounted) {
                    setModalState(() {
                      leadNames = names;
                      namesLoading = false;
                    });
                  }
                });
              } else {
                namesLoading = false;
              }
            }

            return Container(
              height: MediaQuery.of(ctx).size.height * 0.7,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            transfer.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Transferred Leads (${transfer.selectedLeads.length})',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.black54,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.grey[100],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: transfer.selectedLeads.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  size: 48,
                                  color: Colors.grey[300],
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'No leads found in this transfer.',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        : namesLoading
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF675d40),
                            ),
                          )
                        : ListView.separated(
                            itemCount: transfer.selectedLeads.length,
                            separatorBuilder: (c, i) =>
                                Divider(height: 1, color: Colors.grey[100]),
                            itemBuilder: (c, index) {
                              final item = transfer.selectedLeads[index];
                              final leadName =
                                  leadNames[item.lead] ??
                                  item.lead; // Fallback to ID if name not found

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 4,
                                ),
                                leading: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF1A1A1A,
                                    ).withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.person_outline_rounded,
                                      color: Color(0xFF1A1A1A),
                                      size: 22,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  leadName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                                subtitle: Text(
                                  'ID: ${item.lead}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[500],
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                trailing: const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: Colors.black26,
                                ),
                                onTap: () async {
                                  // Show small loader
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF675d40),
                                      ),
                                    ),
                                  );
                                  try {
                                    final lead = await LeadService.fetchLead(
                                      item.lead,
                                    );
                                    if (!context.mounted) return;
                                    Navigator.pop(context); // Close loader

                                    if (lead != null) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              LeadDetailView(lead: lead),
                                        ),
                                      );
                                    } else {
                                      CustomSnackBar.show(
                                        context,
                                        message:
                                            'Could not fetch lead details.',
                                        isError: true,
                                      );
                                    }
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    Navigator.pop(context); // Close loader
                                    CustomSnackBar.show(
                                      context,
                                      message: 'Error: $e',
                                      isError: true,
                                    );
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lead Transfers',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF675d40),
        elevation: 0,
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _fetchTransfers,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      backgroundColor: const Color(0xFFF7F8FA),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF675d40)),
            )
          : _transfers.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _transfers.length,
              itemBuilder: (context, index) {
                return _buildTransferCard(_transfers[index]);
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const BulkLeadTransferPage(),
            ),
          );
          if (result == true) {
            _fetchTransfers();
          }
        },
        backgroundColor: const Color(0xFF1A1A1A), // Black color as requested
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'New Transfer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Icon(
              Icons.swap_horiz_rounded,
              size: 56,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Transfers Found',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Colors.grey[800],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'You haven\'t initiated any lead transfers yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 15,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferCard(LeadTransfer transfer) {
    final bool isTemporary = transfer.transferType == 'Temporary';
    final bool isCancelled = transfer.status == 'Cancelled';
    final Color statusColor = isCancelled
        ? Colors.redAccent
        : (transfer.status == 'Active' ? Colors.green : Colors.grey);

    final String projectName =
        _projectIdToNameMap[transfer.project] ?? transfer.project;

    return InkWell(
      onTap: () => _showLeadDetails(transfer),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: Colors.grey.shade100, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    transfer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                      color: Color(0xFF675d40),
                      fontFamily: 'monospace',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    transfer.status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow(Icons.business_rounded, 'Project', projectName),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.person_remove_rounded,
              'From',
              transfer.fromEmployee,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(Icons.person_add_rounded, 'To', transfer.toEmployee),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.category_rounded,
              'Type',
              transfer.transferType,
            ),
            if (isTemporary && transfer.validTill != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.calendar_today_rounded,
                'Valid Till',
                DateFormat('dd MMM yyyy').format(transfer.validTill!),
              ),
            ],
            const Divider(height: 32),
            Row(
              children: [
                Icon(Icons.layers_rounded, size: 18, color: Colors.grey[600]),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${transfer.selectedLeads.length} Leads Transferred',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[800],
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isCancelled && transfer.status != 'Completed')
                  IconButton(
                    onPressed: () => _cancelTransfer(transfer.name),
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    tooltip: 'Cancel Transfer',
                    constraints: const BoxConstraints(),
                    padding: const EdgeInsets.only(right: 8),
                  ),
                Text(
                  DateFormat('dd MMM, hh:mm a').format(transfer.creation),
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
