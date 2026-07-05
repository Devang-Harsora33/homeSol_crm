import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/apis/finance/finance_service.dart';
import '../../services/api_service.dart';
import '../../services/apis/projects/project_service.dart';
import '../../models/project.dart';
import '../../models/developer.dart';
import '../../utils/custom_snackbar.dart';
import '../../components/project_card.dart';

const kAccent = Color(0xFF675D40);
const kInputDecoration = InputDecoration(
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
  filled: true,
  fillColor: Colors.white,
);

class ConstructionFinanceFormPage extends StatefulWidget {
  final String developerId;
  final List<Project> projects;

  const ConstructionFinanceFormPage({super.key, required this.developerId, required this.projects});

  @override
  State<ConstructionFinanceFormPage> createState() => _ConstructionFinanceFormPageState();
}

class _ConstructionFinanceFormPageState extends State<ConstructionFinanceFormPage> {
  final _formKey = GlobalKey<FormState>();
  
  bool _isLoading = false;
  List<Project> _projects = [];
  
  String? _selectedProject;
  String? _selectedMeetingType;
  DateTime? _selectedDateTime;
  
  final _customProjectController = TextEditingController();
  final _fundRequirementController = TextEditingController();

  final List<String> _meetingTypes = ['Offline', 'Online'];

  @override
  void initState() {
    super.initState();
    _projects = widget.projects;
  }

  // Helper for dummy developer if needed for HomeProjectCard
  Developer _getDummyDeveloper() {
    return Developer.fromJson({
      'name': widget.developerId,
      'developer_name': 'Developer',
    });
  }

  void _showProjectSelectionModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          builder: (_, controller) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      'Select Project',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: _projects.length + 1, // +1 for "Others"
                      itemBuilder: (context, index) {
                        if (index == _projects.length) {
                          return ListTile(
                            leading: const Icon(Icons.add_circle_outline, color: kAccent),
                            title: const Text('Others (Add Custom)'),
                            onTap: () {
                              setState(() {
                                _selectedProject = 'Others';
                              });
                              Navigator.pop(context);
                            },
                          );
                        }
                        
                        final project = _projects[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _selectedProject = project.projectName;
                                _customProjectController.clear();
                              });
                              Navigator.pop(context);
                            },
                            child: AbsorbPointer( // Prevent clicks inside the card from navigating away
                              child: HomeProjectCard(
                                project: project,
                                developer: _getDummyDeveloper(),
                              ),
                            ),
                          ),
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

  Future<void> _selectDateTime(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kAccent,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && mounted) {
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDateTime ?? DateTime.now()),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: kAccent,
              ),
            ),
            child: child!,
          );
        },
      );

      if (pickedTime != null && mounted) {
        setState(() {
          _selectedDateTime = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedProject == null) {
      CustomSnackBar.show(context, message: 'Please select a project', isError: true, title: 'Error');
      return;
    }

    if (_selectedDateTime == null) {
      CustomSnackBar.show(context, message: 'Please select a meeting schedule', isError: true, title: 'Error');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final String finalProjectName = _selectedProject == 'Others' 
          ? _customProjectController.text.trim() 
          : _selectedProject!;

      final Map<String, dynamic> payload = {
        "developer": widget.developerId,
        "project": finalProjectName,
        "meeting_type": _selectedMeetingType,
        "meeting_schedule": DateFormat('yyyy-MM-dd HH:mm:ss').format(_selectedDateTime!),
        "fund_requirement": double.tryParse(_fundRequirementController.text) ?? 0.0,
      };

      await FinanceService.submitConstructionFinanceApplication(payload);

      if (mounted) {
        CustomSnackBar.show(context, message: 'Application submitted successfully', isError: false, title: 'Success');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackBar.show(context, message: 'Failed to submit application', isError: true, title: 'Error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _customProjectController.dispose();
    _fundRequirementController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Fund Raising Application',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: kAccent))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form Container mimicking Lead Creation card style
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Project Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Project Selector
                        InkWell(
                          onTap: _showProjectSelectionModal,
                          child: IgnorePointer(
                            child: TextFormField(
                              key: const ValueKey('project_selector'),
                              controller: TextEditingController(text: _selectedProject),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              decoration: kInputDecoration.copyWith(
                                labelText: 'Project',
                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                hintText: 'Select Project',
                                suffixIcon: const Icon(Icons.arrow_drop_down, color: kAccent),
                              ),
                              validator: (value) => _selectedProject == null ? 'Please select a project' : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Custom Project Name if 'Others' is selected
                        if (_selectedProject == 'Others') ...[
                          TextFormField(
                            controller: _customProjectController,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            decoration: kInputDecoration.copyWith(
                              labelText: 'Enter Project Name',
                              labelStyle: TextStyle(color: Colors.grey.shade600),
                            ),
                            validator: (value) => value == null || value.isEmpty 
                                ? 'Please enter project name' 
                                : null,
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Meeting Type Selector
                        FormField<String>(
                          initialValue: _selectedMeetingType,
                          validator: (value) => value == null ? 'Please select a meeting type' : null,
                          builder: (FormFieldState<String> state) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '  Meeting Type',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: _meetingTypes.map((type) {
                                    final isSelected = state.value == type;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedMeetingType = type;
                                          });
                                          state.didChange(type);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          margin: EdgeInsets.only(
                                            right: type == _meetingTypes.first ? 6 : 0,
                                            left: type == _meetingTypes.last ? 6 : 0,
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          decoration: BoxDecoration(
                                            color: isSelected ? kAccent : Colors.white,
                                            border: Border.all(
                                              color: isSelected ? kAccent : Colors.black12,
                                              width: 1.5,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: kAccent.withOpacity(0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    )
                                                  ]
                                                : null,
                                          ),
                                          alignment: Alignment.center,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                type == 'Offline' 
                                                    ? Icons.storefront_rounded 
                                                    : Icons.video_camera_front_rounded,
                                                color: isSelected ? Colors.white : Colors.grey.shade600,
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                type,
                                                style: TextStyle(
                                                  color: isSelected ? Colors.white : Colors.black87,
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  fontSize: 15,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                if (state.hasError)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8, left: 12),
                                    child: Text(
                                      state.errorText!,
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.error,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 16),

                        // Meeting Schedule Picker
                        InkWell(
                          onTap: () => _selectDateTime(context),
                          child: IgnorePointer(
                            child: TextFormField(
                              controller: TextEditingController(
                                text: _selectedDateTime == null 
                                    ? '' 
                                    : DateFormat('yyyy-MM-dd HH:mm').format(_selectedDateTime!),
                              ),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                              decoration: kInputDecoration.copyWith(
                                labelText: 'Meeting Schedule',
                                labelStyle: TextStyle(color: Colors.grey.shade600),
                                hintText: 'Select Date & Time',
                                suffixIcon: const Icon(Icons.calendar_today, color: kAccent, size: 20),
                              ),
                              validator: (value) => _selectedDateTime == null ? 'Please select schedule' : null,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Fund Requirement
                        TextFormField(
                          controller: _fundRequirementController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          decoration: kInputDecoration.copyWith(
                            labelText: 'Fund Requirement',
                            labelStyle: TextStyle(color: Colors.grey.shade600),
                            prefixText: '₹ ',
                            prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: kAccent),
                            suffixText: ' Cr',
                            suffixStyle: const TextStyle(fontWeight: FontWeight.bold, color: kAccent),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter fund requirement';
                            }
                            if (double.tryParse(value) == null) {
                              return 'Please enter a valid number';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kAccent,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Submit Application', 
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
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
