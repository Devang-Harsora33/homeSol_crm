import 'package:Homesol/models/ticket.dart';
import 'package:Homesol/models/error_log.dart';
import 'package:Homesol/services/databases/error_log_database.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/services/apis/tickets/ticker_service.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

// --- THEME CONSTANTS ---
const Color kAccent = Color(0xFF675D40);
const Color kBackground = Color(0xFFF8F9FA);
const Color kSurface = Colors.white;

// --- STYLES ---
final kInputDecoration = InputDecoration(
  isDense: true,
  filled: true,
  fillColor: kSurface,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: Colors.grey.shade300),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: kAccent, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: const BorderSide(color: Colors.redAccent),
  ),
);

class TicketCreationPage extends StatefulWidget {
  final ErrorLog? initialErrorLog;
  const TicketCreationPage({super.key, this.initialErrorLog});

  @override
  State<TicketCreationPage> createState() => _TicketCreationPageState();
}

class _TicketCreationPageState extends State<TicketCreationPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Form State
  String _category = 'General';
  String _priority = 'Medium';
  final _descriptionController = TextEditingController();
  final _raisedByController = TextEditingController();
  final _dateController = TextEditingController();
  
  bool _isLoading = false;
  List<ErrorLog> _recentLogs = [];
  final List<int> _selectedLogIds = [];
  bool _showMoreLogs = false;

  @override
  void initState() {
    super.initState();
    _loadSystemData();
    _loadRecentLogs();
    
    if (widget.initialErrorLog != null) {
      _category = 'App Bug';
      _priority = 'High';
      _descriptionController.text = "Error encountered: ${widget.initialErrorLog!.message}\nContext: ${widget.initialErrorLog!.module}";
      if (widget.initialErrorLog!.id != null) {
        _selectedLogIds.add(widget.initialErrorLog!.id!);
      }
    }
  }

  Future<void> _loadRecentLogs() async {
    final logs = await ErrorLogDatabase.getRecentErrorLogs(10);
    if (mounted) {
      setState(() {
        _recentLogs = logs;
        
        // If we have an initial error log from the crash dialog, 
        // make sure it's selected in the list once logs are loaded
        if (widget.initialErrorLog != null) {
          final logInList = _recentLogs.where((l) => 
            l.message == widget.initialErrorLog!.message && 
            l.module == widget.initialErrorLog!.module
          ).firstOrNull;
          
          if (logInList != null && logInList.id != null) {
            if (!_selectedLogIds.contains(logInList.id)) {
              _selectedLogIds.add(logInList.id!);
            }
          }
        }
      });
    }
  }

  Future<void> _loadSystemData() async {
    // 1. Set Date
    final now = DateTime.now();
    _dateController.text = DateFormat('yyyy-MM-dd HH:mm').format(now);

    // 2. Set User Email
    final userData = await AuthService.getUserData();
    final email = userData?['email'] ?? 'unknown@example.com';
    if (mounted) {
      setState(() {
        _raisedByController.text = email;
      });
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _raisedByController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _submitTicket() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      String fullDescription = _descriptionController.text;
      
      if (_selectedLogIds.isNotEmpty) {
        fullDescription += "\n\n--- ATTACHED ERROR LOGS ---\n";
        for (final logId in _selectedLogIds) {
          final log = _recentLogs.firstWhere((l) => l.id == logId);
          fullDescription += "\n[${DateFormat('yyyy-MM-dd HH:mm:ss').format(log.timestamp)}]";
          fullDescription += "\nModule: ${log.module} | Action: ${log.action}";
          fullDescription += "\nMessage: ${log.message}";
          fullDescription += "\nDevice: ${log.deviceInfo}";
          if (log.stackTrace.isNotEmpty) {
            fullDescription += "\nStack Trace: ${log.stackTrace}";
          }
          fullDescription += "\n---------------------------";
        }
      }

      final ticketToCreate = Ticket(
        id: '', 
        status: 'Open',
        category: _category,
        priority: _priority,
        description: fullDescription,
        raisedBy: _raisedByController.text,
        creation: '', 
        docstatus: 0,
        doctype: 'Tickets',
        idx: 0,
        modified: '', 
        owner: _raisedByController.text,
      );

      await TicketService.createTicket(ticketToCreate);

      if (mounted) {
        CustomSnackBar.show(context, message: 'Ticket submitted successfully!', isError: false, title: 'Success');
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: const Text(
          'New Ticket', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)
        ),
        backgroundColor: kBackground,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SECTION 1: DETAILS ---
              const _SectionLabel(label: "TICKET DETAILS"),
              _FormCard(
                children: [
                  _ReadOnlyField(
                    label: "Created On", 
                    controller: _dateController, 
                    icon: Icons.calendar_today_outlined
                  ),
                  const SizedBox(height: 16),
                  _ReadOnlyField(
                    label: "Raised By", 
                    controller: _raisedByController, 
                    icon: Icons.person_outline
                  ),
                ],
              ),
              
              const SizedBox(height: 24),

              // --- SECTION 2: CLASSIFICATION ---
              const _SectionLabel(label: "CLASSIFICATION"),
              _FormCard(
                children: [
                  _DropdownField(
                    label: 'Category',
                    value: _category,
                    // UPDATED LIST based on your screenshot
                    items: const [
                      'General', 
                      'Site Visit Issue', 
                      'Attendance', 
                      'App Bug', 
                      'Other'
                    ],
                    onChanged: (val) => setState(() => _category = val),
                  ),
                  const SizedBox(height: 16),
                  _DropdownField(
                    label: 'Priority',
                    value: _priority,
                    items: const ['Low', 'Medium', 'High'],
                    onChanged: (val) => setState(() => _priority = val),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- SECTION 3: DESCRIPTION ---
              const _SectionLabel(label: "THE ISSUE"),
              _FormCard(
                children: [
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 5,
                    decoration: kInputDecoration.copyWith(
                      hintText: "Describe the issue in detail...",
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => v!.isEmpty ? 'Please describe the issue' : null,
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --- SECTION 4: RECENT ERRORS ---
              if (_recentLogs.isNotEmpty) ...[
                const _SectionLabel(label: "ATTACH RECENT ERRORS"),
                _FormCard(
                  children: [
                    const Text(
                      "Select relevant logs to help us debug:",
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    ...(_showMoreLogs ? _recentLogs : _recentLogs.take(5)).map((log) {
                      final isSelected = _selectedLogIds.contains(log.id);
                      return CheckboxListTile(
                        value: isSelected,
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          log.message,
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(
                          "${log.module} | ${DateFormat('HH:mm').format(log.timestamp)}",
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedLogIds.add(log.id!);
                            } else {
                              _selectedLogIds.remove(log.id);
                            }
                          });
                        },
                      );
                    }).toList(),
                    if (!_showMoreLogs && _recentLogs.length > 5)
                      Center(
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showMoreLogs = true),
                          icon: const Icon(Icons.expand_more, size: 18),
                          label: const Text("Show More"),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              const SizedBox(height: 8),

              // --- SUBMIT BUTTON ---
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitTicket,
                  child: _isLoading
                      ? const SizedBox(
                          height: 24, 
                          width: 24, 
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                        )
                      : const Text(
                          "Submit Ticket", 
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                        ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HELPER WIDGETS
// -----------------------------------------------------------------------------

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: TextStyle(
          color: Colors.grey.shade600,
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final IconData icon;

  const _ReadOnlyField({
    required this.label,
    required this.controller,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w500),
      decoration: kInputDecoration.copyWith(
        labelText: label,
        prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
        fillColor: Colors.grey.shade100, 
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }
}

class _DropdownField extends StatelessWidget {
  final String label;
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value,
      dropdownColor: Colors.white, // Makes popup white
      icon: const Icon(Icons.keyboard_arrow_down, color: kAccent),
      decoration: kInputDecoration.copyWith(
        labelText: label,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}