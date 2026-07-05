import 'package:Homesol/models/follow_up.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/services/apis/leads/lead_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


// ─── STYLING CONSTANTS ───
const kAccent = Color(0xFF675D40);
const kBackgroundColor = Color(0xFFF2F2F7);

// Standard Input Decoration
final kInputDecoration = InputDecoration(
  filled: true,
  fillColor: Colors.white,
  isDense: true,
  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  border: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  enabledBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.black12),
  ),
  focusedBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: kAccent, width: 2),
  ),
  errorBorder: const OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.redAccent),
  ),
);

class FollowUpDetailPage extends StatefulWidget {
  final String followUpName;

  const FollowUpDetailPage({super.key, required this.followUpName});

  @override
  State<FollowUpDetailPage> createState() => _FollowUpDetailPageState();
}

class _FollowUpDetailPageState extends State<FollowUpDetailPage> {
  final _formKey = GlobalKey<FormState>();

  FollowUp? _followUp;
  bool _isLoading = true;
  String? _selectedStatus;

  // Controllers for General Info (Read-Only)
  final TextEditingController _ownerController = TextEditingController();
  final TextEditingController _currentDateController = TextEditingController();
  final TextEditingController _typeController = TextEditingController();

  // Controllers for Editable Fields
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _nextFollowUpController = TextEditingController();

  final List<String> _statusOptions = ['Open', 'Completed', 'Cancelled'];

  @override
  void initState() {
    super.initState();
    _fetchFollowUpDetails();
  }

  Future<void> _fetchFollowUpDetails() async {
    setState(() => _isLoading = true);
    try {
      final followUp = await LeadService.fetchFollowUp(widget.followUpName);
      if (mounted) {
        setState(() {
          _followUp = followUp;
          _selectedStatus = followUp?.status;

          // 1. General Info
          _ownerController.text = followUp?.leadOwner ?? 'N/A';
          _currentDateController.text = followUp?.followUpDate ?? 'N/A';
          _typeController.text = followUp?.type ?? 'N/A';

          // 2. System Info fields will be accessed directly from _followUp
          // 3. Editable Fields
          _remarksController.text = followUp?.remarks ?? '';
          _nextFollowUpController.text = followUp?.nextFollowUp ?? '';

          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: 'Error loading data: $e', isError: true, title: 'Error');
        setState(() => _isLoading = false);
      }
    }
  }

  // ─── DATE PICKER LOGIC ───
  Future<void> _selectNextFollowUpDate() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kAccent),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate == null) return;

    if (!mounted) return;
    final TimeOfDay? pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: kAccent),
          ),
          child: child!,
        );
      },
    );

    if (pickedTime == null) return;

    final DateTime fullDateTime = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    setState(() {
      _nextFollowUpController.text = DateFormat('yyyy-MM-dd HH:mm:ss').format(fullDateTime);
    });
  }

  // ─── API UPDATE LOGIC ───
  Future<void> _updateFollowUp() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final success = await LeadService.updateFollowUp(
        widget.followUpName,
        _selectedStatus!,
        _remarksController.text,
        nextFollowUp: _nextFollowUpController.text,
      );

      if (mounted) {
        if (success) {
          CustomSnackBar.show(context, message: 'Follow-up updated successfully!', isError: false, title: 'Notice');
          Navigator.of(context).pop(true);
        } else {
          CustomSnackBar.show(context, message: 'Failed to update.', isError: true, title: 'Error');
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: 'Error: $e', isError: true, title: 'Error');
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _currentDateController.dispose();
    _typeController.dispose();
    _remarksController.dispose();
    _nextFollowUpController.dispose();
    super.dispose();
  }

  // ─── UI HELPERS ───

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const Divider(height: 24),
          ...children.map((e) => Padding(padding: const EdgeInsets.only(bottom: 16.0), child: e)),
        ],
      ),
    );
  }

  Widget _miniInfo(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text("$k: ", style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, fontFamily: 'monospace'))),
        ],
      ),
    );
  }

  Widget _buildSystemInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("System Info", style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _miniInfo("ID", _followUp!.name ?? '-'),
          _miniInfo("Created", _followUp!.creation ?? '-'),
          _miniInfo("Last Modified", _followUp!.modified ?? '-'),
        ],
      ),
    );
  }

  // Helper method for general info rows (adapted from LeadDetailView)
  Widget _infoRow(IconData icon, String label, String value) {
    if (value == '-' || value.isEmpty || value == 'N/A') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedStatus,
        decoration: kInputDecoration.copyWith(
          labelText: 'Status',
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded),
        items: _statusOptions.map((String item) {
          return DropdownMenuItem<String>(
            value: item,
            child: Text(item, style: const TextStyle(fontWeight: FontWeight.w500)),
          );
        }).toList(),
        onChanged: (val) => setState(() => _selectedStatus = val),
        validator: (val) => val == null || val.isEmpty ? 'Required' : null,
      ),
    );
  }

  Widget _buildNextFollowUpField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _nextFollowUpController,
        readOnly: true,
        onTap: _selectNextFollowUpDate,
        decoration: kInputDecoration.copyWith(
          labelText: 'Next Follow-up Date',
          labelStyle: TextStyle(color: Colors.grey.shade600),
          suffixIcon: const Icon(Icons.calendar_month, color: kAccent),
        ),
      ),
    );
  }

  Widget _buildEditableRemarksField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: _remarksController,
        decoration: kInputDecoration.copyWith(
          labelText: 'Remarks',
          labelStyle: TextStyle(color: Colors.grey.shade600),
        ),
        maxLines: null,
        minLines: 3,
        keyboardType: TextInputType.multiline,
        onSaved: (value) => _remarksController.text = value ?? '',
      ),
    );
  }

  // ─── MAIN BUILD ───

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Follow-up Details', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAccent))
          : _followUp == null
              ? const Center(child: Text('Follow-up not found'))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // 1. General Info
                        _card("General Information", [
                          _infoRow(Icons.person_outline, "Lead Owner", _ownerController.text),
                          _infoRow(Icons.calendar_today, "Follow-up Date", _currentDateController.text),
                          _infoRow(Icons.task_alt, "Activity Type", _typeController.text),
                        ]),

                        // 2. Action Card
                        _card("Update Status & Remarks", [
                          _buildStatusDropdown(),
                          _buildNextFollowUpField(),
                          _buildEditableRemarksField(),
                        ]),

                        // 3. System Info
                        _buildSystemInfoCard(),
                      ],
                    ),
                  ),
                ),

      // Sticky Bottom Button
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Colors.black12)),
        ),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kAccent,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _isLoading ? null : _updateFollowUp,
            child: _isLoading
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text(
                    'Save Changes',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
      ),
    );
  }
}