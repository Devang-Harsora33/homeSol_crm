import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:Homesol/services/apis/projects/project_service.dart';
import 'package:Homesol/services/apis/site_visits/sitevisit_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'dart:convert'; // Add this import
import '../models/lead.dart' as model_lead; // Alias this import
import '../services/databases/lead_database.dart'; // Add this import
// import '../services/auth_service.dart'; // Uncomment if needed

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

class CreateSiteVisitScreen extends StatefulWidget {
  final String? preselectedLeadId;
  final String? preselectedLeadDisplayName;
  final String? preselectedProjectId;
  final VoidCallback? onSiteVisitCreated; // New callback parameter

  const CreateSiteVisitScreen({
    super.key,
    this.preselectedLeadId,
    this.preselectedLeadDisplayName,
    this.preselectedProjectId,
    this.onSiteVisitCreated, // Initialize the new parameter
  });

  @override
  State<CreateSiteVisitScreen> createState() => _CreateSiteVisitScreenState();
}

class _CreateSiteVisitScreenState extends State<CreateSiteVisitScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  late LeadService _leadService; // Declare LeadService instance

  // Form field values
  String? _selectedLead;
  Map<String, String>? _selectedProject;
  String _status = 'Scheduled';

  DateTime? _selectedDateTime; // For Visit Date
  DateTime? _selectedScheduledDateTime; // For Scheduled Date (New)

  final TextEditingController _remarkController = TextEditingController();
  final TextEditingController _dateController =
      TextEditingController(); // Visit Date
  final TextEditingController _scheduledDateController =
      TextEditingController(); // Scheduled Date

  // Dropdown data
  List<model_lead.Lead> _leadOptions = []; // Use aliased Lead
  bool _isLeadsLoading = true;
  List<Map<String, String>> _projectOptions = [];
  bool _isProjectsLoading = true;
  final List<String> _statusOptions = [
    'Scheduled',
    'Visit Done',
    'Revisit Done',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _leadService = LeadService(); // Initialize LeadService
    _selectedDateTime = DateTime.now();
    _dateController.text = DateFormat(
      'yyyy-MM-dd HH:mm:ss',
    ).format(_selectedDateTime!);
    _initializeDropdownDataAndPreselect();
  }

  Future<void> _initializeDropdownDataAndPreselect() async {
    await _fetchDropdownData(); // Wait for data to be fetched

    if (mounted) {
      setState(() {
        if (widget.preselectedLeadId != null) {
          _selectedLead = widget.preselectedLeadId;
        } else if (_leadOptions.isNotEmpty) {
           // Fallback to first lead if no preselected and options exist, but only if _selectedLead is not already set by preselectedLeadId
           if (_selectedLead == null) {
              _selectedLead = _leadOptions.first.name;
           }
        }
                          if (widget.preselectedProjectId != null) {
                            try {
                              _selectedProject = _projectOptions.firstWhere((p) => p['id'] == widget.preselectedProjectId);
                            } catch (e) {
                              _selectedProject = null; // Not found
                            }
                          }        });
    }
  }
  Future<void> _fetchDropdownData() async {
    setState(() {
      _isLeadsLoading = true;
      _isProjectsLoading = true;
    });

    try {
      await _leadService.syncMyLeads(); // Sync data from API to local DB

      final List<Map<String, dynamic>> rawLeads = await LeadDatabase().getAllLeads();
      final List<model_lead.Lead> leads = rawLeads.map((data) {
        final leadJson = json.decode(data['data']);
        return model_lead.Lead.fromJson(leadJson);
      }).toList();

      final projects = await ProjectService.fetchApiProjects();

      if (mounted) {
        setState(() {
          _leadOptions = leads;
          // No longer initializing _selectedLead with the first lead here
          // It will be set from widget.preselectedLeadId if available
          _projectOptions = projects;
          print('DEBUG: _projectOptions after fetch: $_projectOptions'); // Debug print for project options
          // No longer initializing _selectedProject with the first project here
          // It will be set from widget.preselectedProjectId if available
        });
      }
    } catch (e) {
      _showSnackBar('Failed to load dropdown data: $e', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isLeadsLoading = false;
          _isProjectsLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _remarkController.dispose();

    _dateController.dispose();

    _scheduledDateController.dispose();

    super.dispose();
  }

  // ───────────────────────── LOGIC ─────────────────────────

  // Helper to pick date time (reusable)

  Future<DateTime?> _pickDateTime(DateTime? initialDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,

      initialDate: initialDate ?? DateTime.now(),

      firstDate: DateTime(2000),

      lastDate: DateTime(2101),

      builder: (context, child) {
        return Theme(
          data: Theme.of(
            context,
          ).copyWith(colorScheme: const ColorScheme.light(primary: kAccent)),

          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,

        initialTime: TimeOfDay.fromDateTime(initialDate ?? DateTime.now()),

        builder: (context, child) {
          return Theme(
            data: Theme.of(
              context,
            ).copyWith(colorScheme: const ColorScheme.light(primary: kAccent)),

            child: child!,
          );
        },
      );

      if (pickedTime != null) {
        return DateTime(
          pickedDate.year,

          pickedDate.month,

          pickedDate.day,

          pickedTime.hour,

          pickedTime.minute,
        );
      }
    }

    return null;
  }

  // Logic for Main Visit Date

  // Future<void> _selectDateTime() async {

  //   final dt = await _pickDateTime(_selectedDateTime);

  //   if (dt != null) {

  //     setState(() {

  //       _selectedDateTime = dt;

  //       _dateController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);

  //     });

  //   }

  // }

  // Logic for Scheduled Date

  Future<void> _selectScheduledDateTime() async {
    final dt = await _pickDateTime(_selectedScheduledDateTime);

    if (dt != null) {
      setState(() {
        _selectedScheduledDateTime = dt;

        _scheduledDateController.text = DateFormat(
          'yyyy-MM-dd HH:mm:ss',
        ).format(dt);
      });
    }
  }

    Future<void> _submitForm() async {
      if (!_formKey.currentState!.validate()) return;

      setState(() => _isLoading = true);

      try {
        final body = {
          "lead": _selectedLead,
          "project": _selectedProject?['id'],
          "remark": _remarkController.text,
          "visit_date": _dateController.text,
          "status": _status,
          // Only send scheduled time if status is Scheduled, otherwise default to visit_date
          "visit_scheduled_datetime": _status == 'Scheduled'
              ? _scheduledDateController.text
              : _dateController.text,
        };

        final String? errorMessage = await SiteVisitService.createSiteVisit(body);

        if (errorMessage == null) {
          _showSnackBar('Site visit created successfully!', isError: false);
          if (mounted) {
            widget.onSiteVisitCreated?.call(); // Invoke the callback
            Navigator.of(context).pop();
          }
        } else {
          _showSnackBar('Failed to create site visit: $errorMessage', isError: true);
        }
      } catch (e) {
        _showSnackBar('Error: $e', isError: true);
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),

        // Use kAccent (0xFF675D40) for success, Red for error
        backgroundColor: isError ? Colors.redAccent : kAccent,

        behavior: SnackBarBehavior.floating,

        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ───────────────────────── UI HELPERS ─────────────────────────

  Widget _card(String title, List<Widget> children) {
    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 16),

      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: Colors.white,

        borderRadius: BorderRadius.circular(20),

        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),

            blurRadius: 15,

            offset: const Offset(0, 5),
          ),
        ],
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),

          const Divider(height: 24),

          ...children.map(
            (e) =>
                Padding(padding: const EdgeInsets.only(bottom: 16.0), child: e),
          ),
        ],
      ),
    );
  }

  Widget _styledDropdown({
    required String label,
    required dynamic value, // This can be String for Lead/Status or Map<String,String> for Project
    required List<dynamic> items,
    required Function(dynamic) onChanged, // Now accepts dynamic
    bool isLoading = false,
    String? displayKey,
    String? valueKey,
  }) {
    dynamic resolvedValue = value;
    if (value is String) {
      if (items.isNotEmpty && items.first is Map && valueKey != null) {
        try {
          resolvedValue = items.firstWhere((item) => item is Map && item[valueKey] == value, orElse: () => null);
        }
        catch (e) {
          resolvedValue = null;
        }
      }
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<dynamic>( // Keep as dynamic for flexibility
          value: resolvedValue,
          decoration: kInputDecoration.copyWith(
            labelText: label,
            labelStyle: TextStyle(color: Colors.grey.shade600),
            suffixIcon: isLoading 
            ? Transform.scale(scale: 0.5, child: const CircularProgressIndicator(strokeWidth: 2))             
            : null,
          ),
          dropdownColor: Colors.white,
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          items: items.map((dynamic item) {
            String displayValue = '';
            dynamic itemValue = null; // Can be null

            if (item is model_lead.Lead) {
              displayValue = item.leadName ?? item.name ?? '';
              itemValue = item.name; // This is a String
            } else if (item is Map<String, String>) { // For project options
              displayValue = item[displayKey] ?? '';
              itemValue = item; // This is a Map
            } else if (item is String) { // For status options
              displayValue = item;
              itemValue = item; // This is a String
            }
            
            return DropdownMenuItem<dynamic>( // Keep dynamic
              value: itemValue,
              child: Text(displayValue, style: const TextStyle(fontWeight: FontWeight.w500)),
            );
          }).toList(),
          onChanged: isLoading ? null : onChanged,
          validator: (val) => val == null || (val is String && val.isEmpty) ? 'Required' : null,
          selectedItemBuilder: (BuildContext context) {
            return items.map<Widget>((dynamic item) {
              String displayValue = '';
              if (item is model_lead.Lead) {
                displayValue = item.leadName ?? item.name ?? '';
              } else if (item is Map<String, String>) {
                displayValue = item[displayKey] ?? '';
              }
              else if (item is String) {
                displayValue = item;
              }
              return Text(displayValue, overflow: TextOverflow.ellipsis);
            }).toList();
          },
        ),
      ],
    );
  }

  Widget _styledTextField({
    required TextEditingController controller,

    required String label,

    int maxLines = 1,

    bool readOnly = false,

    VoidCallback? onTap,

    IconData? icon,

    bool isRequired = true, // Added isRequired param
  }) {
    return TextFormField(
      controller: controller,

      readOnly: readOnly,

      onTap: onTap,

      maxLines: maxLines,

      style: const TextStyle(fontWeight: FontWeight.w500),

      decoration: kInputDecoration.copyWith(
        labelText: label,

        labelStyle: TextStyle(color: Colors.grey.shade600),

        alignLabelWithHint: maxLines > 1,

        suffixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
      ),

      validator: (val) =>
          isRequired && (val == null || val.isEmpty) && !readOnly
          ? 'Required'
          : null,
    );
  }

  // ───────────────────────── BUILD ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Create Site Visit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              // 1. Visit Details Card
              _card("Visit Details", [
                _styledDropdown(
                  label: "Select Lead",
                  value: _selectedLead,
                  items: _leadOptions,
                  isLoading: _isLeadsLoading,
                  onChanged: (val) => setState(() => _selectedLead = val as String?), // Cast to String?
                  displayKey: 'lead_name', // Display lead_name
                  valueKey: 'name', // Use 'name' as the actual value
                ),
                _styledDropdown(
                  label: "Select Project",
                  value: _selectedProject,
                  items: _projectOptions,
                  isLoading: _isProjectsLoading,
                  onChanged: (val) {
                    setState(() {
                      _selectedProject = val as Map<String, String>?; // Cast to Map<String, String>?
                    });
                  },
                  displayKey: 'name',
                  valueKey: 'id',
                ),
                _styledTextField(
                  controller: _dateController,
                  label: "Entry Date & Time",
                  readOnly: true,
                  icon: Icons.calendar_today,
                  // onTap: _selectDateTime,
                ),
              ]),

              // 2. Status & Remarks Card
              _card("Status & Remarks", [
                _styledDropdown(
                  label: "Current Status",
                  value: _status,
                  items: _statusOptions,
                  onChanged: (val) => setState(() => _status = val!),
                ),
                
                // ★★★ CONDITIONAL FIELD: Scheduled Date ★★★
                if (_status == 'Scheduled')
                  _styledTextField(
                    controller: _scheduledDateController,
                    label: "Scheduled Date & Time",
                    readOnly: true,
                    icon: Icons.schedule,
                    onTap: _selectScheduledDateTime,
                    isRequired: true,
                  ),

                _styledTextField(
                  controller: _remarkController,
                  label: "Remarks (Optional)",
                  maxLines: 3,
                  isRequired: false,
                ),
              ]),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: Colors.white,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _submitForm,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    'Create Site Visit',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}
