import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import '../models/lead.dart' as model_lead;
import '../services/databases/lead_database.dart';

const kAccent = Color(0xFF675D40);
const kBackgroundColor = Color(0xFFF2F2F7);

const kInputDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
  isDense: true,
  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: kAccent, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.redAccent),
  ),
);

class CreateFollowUpScreen extends StatefulWidget {
  final String? preselectedLeadId;
  final VoidCallback? onFollowUpCreated;

  const CreateFollowUpScreen({
    super.key,
    this.preselectedLeadId,
    this.onFollowUpCreated,
  });

  @override
  State<CreateFollowUpScreen> createState() => _CreateFollowUpScreenState();
}

class _CreateFollowUpScreenState extends State<CreateFollowUpScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String? _selectedLead;
  String? _assignedTo;
  String _status = 'Open';
  String _type = 'Call';

  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _nextFollowUpController = TextEditingController();
  final TextEditingController _assignedToController = TextEditingController();
  final TextEditingController _leadSearchController = TextEditingController();
  final TextEditingController _leadDisplayController = TextEditingController();

  List<model_lead.Lead> _leadOptions = [];
  bool _isLeadsLoading = true;

  final List<String> _statusOptions = ['Open', 'Completed', 'Cancelled'];
  final List<String> _typeOptions = ['Call', 'Visit', 'Email', 'WhatsApp'];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    _fetchLeads();
  }

  Future<void> _fetchLeads() async {
    setState(() => _isLeadsLoading = true);
    try {
      final List<Map<String, dynamic>> rawLeads = await LeadDatabase().getAllLeads();
      final List<model_lead.Lead> leads = rawLeads.map((data) {
        final leadJson = json.decode(data['data']);
        return model_lead.Lead.fromJson(leadJson);
      }).toList();

      if (mounted) {
        setState(() {
          _leadOptions = leads;
          if (widget.preselectedLeadId != null) {
            _selectedLead = widget.preselectedLeadId;
            final lead = _leadOptions.where((l) => l.name == _selectedLead);
            if (lead.isNotEmpty) {
              final selectedLeadObj = lead.first;
              _leadDisplayController.text = selectedLeadObj.leadName ?? selectedLeadObj.name ?? 'Selected Lead';
              _assignedTo = selectedLeadObj.owner ?? selectedLeadObj.leadOwner;
              _assignedToController.text = _assignedTo ?? '';
            }
          }
          _isLeadsLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching leads: $e');
      if (mounted) setState(() => _isLeadsLoading = false);
    }
  }

  Future<void> _selectDateTime(TextEditingController controller) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAccent,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
            dialogBackgroundColor: Colors.white,
            scaffoldBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (context, child) {
          return Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(
                primary: kAccent,
                onPrimary: Colors.white,
                surface: Colors.white,
                onSurface: Colors.black,
              ),
              dialogBackgroundColor: Colors.white,
              scaffoldBackgroundColor: Colors.white,
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        setState(() {
          final dt = DateTime(pickedDate.year, pickedDate.month, pickedDate.day, pickedTime.hour, pickedTime.minute);
          controller.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
        });
      }
    }
  }
  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLead == null) {
      CustomSnackBar.show(context, message: 'Please select a lead', isError: false, title: 'Notice');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final body = {
        "lead_id": _selectedLead,
        "follow_up_date": _dateController.text,
        "next_follow_up": _nextFollowUpController.text,
        "assigned_to": _assignedTo,
        "status": _status,
        "type": _type,
        "remarks": _remarksController.text,
      };

      final error = await LeadService.createFollowup(body);
      if (error == null) {
        CustomSnackBar.show(context, message: 'Follow-up created successfully', isError: false, title: 'Notice');
        widget.onFollowUpCreated?.call();
        Navigator.pop(context);
      } else {
        CustomSnackBar.show(context, message: error, isError: true, title: 'Error');
      }
    } catch (e) {
      CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showLeadSearchPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: TextField(
                      controller: _leadSearchController,
                      decoration: kInputDecoration.copyWith(
                        hintText: 'Search leads...',
                        prefixIcon: const Icon(Icons.search),
                      ),
                      onChanged: (val) => setModalState(() {}),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _leadOptions.where((l) {
                        final q = _leadSearchController.text.toLowerCase();
                        return (l.leadName ?? '').toLowerCase().contains(q) || (l.name ?? '').toLowerCase().contains(q);
                      }).length,
                      itemBuilder: (context, index) {
                        final filtered = _leadOptions.where((l) {
                          final q = _leadSearchController.text.toLowerCase();
                          return (l.leadName ?? '').toLowerCase().contains(q) || (l.name ?? '').toLowerCase().contains(q);
                        }).toList();
                        final lead = filtered[index];
                        return ListTile(
                          title: Text(lead.leadName ?? lead.name ?? ''),
                          subtitle: Text(lead.name ?? ''),
                          onTap: () {
                            setState(() {
                              _selectedLead = lead.name;
                              _leadDisplayController.text = lead.leadName ?? lead.name ?? '';
                              _assignedTo = lead.owner ?? lead.leadOwner;
                              _assignedToController.text = _assignedTo ?? '';
                            });
                            Navigator.pop(context);
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
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Follow-up', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _card("Follow-up Details", [
                InkWell(
                  onTap: _showLeadSearchPicker,
                  child: IgnorePointer(
                    child: _styledTextField(
                      controller: _leadDisplayController,
                      label: "Select Lead",
                      icon: Icons.search,
                    ),
                  ),
                ),
                
                _styledTextField(
                  controller: _dateController,
                  label: "Follow-up Date & Time",
                  readOnly: true,
                  icon: Icons.calendar_today,
                  onTap: () => _selectDateTime(_dateController),
                ),
                
                _styledDropdown(
                  label: "Type",
                  value: _type,
                  items: _typeOptions,
                  onChanged: (val) => setState(() => _type = val as String),
                ),
                _styledDropdown(
                  label: "Status",
                  value: _status,
                  items: _statusOptions,
                  onChanged: (val) => setState(() => _status = val as String),
                ),
                _styledTextField(
                  controller: _nextFollowUpController,
                  label: "Next Follow-up Date & Time",
                  readOnly: true,
                  icon: Icons.event,
                  onTap: () => _selectDateTime(_nextFollowUpController),
                  isRequired: false,
                ),
                _styledTextField(
                  controller: _remarksController,
                  label: "Remarks",
                  maxLines: 3,
                  isRequired: false,
                ),
                _styledTextField(
                  controller: _assignedToController,
                  label: "Assigned To",
                  readOnly: true,
                  icon: Icons.person_outline,
                ),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: kAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
          onPressed: _isLoading ? null : _submitForm,
          child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('Create Follow-up', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Divider(height: 24),
          ...children.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16), child: e)),
        ],
      ),
    );
  }

  Widget _styledTextField({required TextEditingController controller, required String label, int maxLines = 1, bool readOnly = false, VoidCallback? onTap, IconData? icon, bool isRequired = true}) {
    return TextFormField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      maxLines: maxLines,
      decoration: kInputDecoration.copyWith(labelText: label, suffixIcon: icon != null ? Icon(icon) : null),
      validator: (v) => isRequired && (v == null || v.isEmpty) ? 'Required' : null,
    );
  }

Widget _styledDropdown({
  required String label,
  required String value,
  required List<String> items,
  required void Function(String?) onChanged, // Improved typing from dynamic
}) {
  return DropdownButtonFormField<String>(
    value: value,
    isExpanded: true, // UX: Prevents overflow errors if an item's text is too long
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.grey), // UX: More modern icon
    dropdownColor: Colors.white, // UI: Makes the popup menu background white
    elevation: 4, // UI: Adds a subtle, modern shadow to the popup menu
    borderRadius: BorderRadius.circular(12), // UI: Rounds the corners of the popup menu
    items: items.map((i) => DropdownMenuItem(
      value: i, 
      child: Text(
        i, 
        style: const TextStyle(fontSize: 16, color: Colors.black87),
      ),
    )).toList(),
    onChanged: onChanged,
    // We merge your kInputDecoration with our new white/modern styling
    decoration: kInputDecoration.copyWith(
      labelText: label,
      filled: true,
      fillColor: Colors.white, // UI: Makes the text field background white
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14), // UX: Better touch target size
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.grey, width: 2), // UI: Clear focus state
      ),
    ),
  );
}
}
