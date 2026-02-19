import 'package:Homesol/models/ticket.dart';
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
  const TicketCreationPage({super.key});

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

  @override
  void initState() {
    super.initState();
    _loadSystemData();
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
      final ticketToCreate = Ticket(
        id: '', 
        status: 'Open',
        category: _category,
        priority: _priority,
        description: _descriptionController.text,
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ticket raised successfully!'),
            backgroundColor: kAccent,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
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

              const SizedBox(height: 32),

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