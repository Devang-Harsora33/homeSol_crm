import 'package:Homesol/components/lead_detail_view.dart';
import 'package:Homesol/services/apis/workforces/workforce.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/leave_application.dart';

const Color goldAccent = Color(0xFF675D40);
const Color matteBlack = Color(0xFF1A1A1A);
const Color offWhite = Color(0xFFF9F9F9);
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
    borderSide: BorderSide(color: goldAccent, width: 2),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
    borderSide: BorderSide(color: Colors.redAccent),
  ),
);

Future<DateTime?> _showThemedDatePicker({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
}) {
  return showDatePicker(
    context: context,
    initialDate: initialDate,
    firstDate: firstDate,
    lastDate: DateTime(2101),
    builder: (context, child) {
      return Theme(
        data: ThemeData.light().copyWith(
          colorScheme: ColorScheme.light(
            primary: kAccent,
            onPrimary: Colors.white,
            onSurface: Colors.black,
          ),
          dialogBackgroundColor: Colors.white,
          textButtonTheme: TextButtonThemeData(
            style: TextButton.styleFrom(
              foregroundColor: kAccent,
            ),
          ),
        ),
        child: child!,
      );
    },
  );
}

class LeaveScreen extends StatefulWidget {
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

class _LeaveScreenState extends State<LeaveScreen> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  final _searchController = TextEditingController();

  String? _selectedLeaveType;
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isHalfDay = false;
  bool _isLoading = false;
  String? _errorMessage;
  String? _successMessage;

  List<LeaveApplication> _leaveApplications = [];
  bool _isLoadingApplications = true;
  bool _showAllApplications = false;
  String _searchQuery = '';
  String? _selectedStatus;
  List<String> _availableLeaveTypes = []; // New list for fetched leave types

  @override
  void initState() {
    super.initState();
    _fetchLeaveApplications();
    _fetchLeaveTypes(); // Fetch leave types on init
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLeaveTypes() async {
    try {
      final List<String> fetchedTypes = await WorkforceService.fetchLeaveTypes();
      setState(() {
        _availableLeaveTypes = fetchedTypes;
        if (!_availableLeaveTypes.contains(_selectedLeaveType)) {
          _selectedLeaveType = null;
        }
      });
    } catch (e) {
      print('Error fetching leave types: $e');
      setState(() {
        _errorMessage = 'Failed to load leave types: $e';
      });
    }
  }

  Future<void> _fetchLeaveApplications() async {
    setState(() {
      _isLoadingApplications = true;
    });
    try {
      final applications = await WorkforceService.fetchLeaveApplications();
      setState(() {
        _leaveApplications = applications;
        _isLoadingApplications = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingApplications = false;
        _errorMessage = 'Failed to load leave applications.';
      });
    }
  }

  void _toggleShowAllApplications() {
    setState(() {
      _showAllApplications = !_showAllApplications;
    });
  }

  List<LeaveApplication> _getFilteredApplications() {
    List<LeaveApplication> filtered = _leaveApplications;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((app) {
        final query = _searchQuery.toLowerCase();
        return app.leaveType.toLowerCase().contains(query) ||
            app.description.toLowerCase().contains(query) ||
            app.status.toLowerCase().contains(query);
      }).toList();
    }
    
    if (_selectedStatus != null) {
      filtered = filtered.where((app) => app.status == _selectedStatus).toList();
    }

    // Sort by posting date descending to always have the latest first
    filtered.sort((a, b) {
      try {
        final dateA = DateTime.parse(a.postingDate);
        final dateB = DateTime.parse(b.postingDate);
        return dateB.compareTo(dateA);
      } catch (e) {
        return 0;
      }
    });

    if (_showAllApplications) {
      return filtered;
    } else {
      return filtered.isNotEmpty ? [filtered.first] : [];
    }
  }

  Future<void> _submitLeaveApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final String? errorMessage = await WorkforceService.applyLeave(
        leaveType: _selectedLeaveType!,
        fromDate: DateFormat('yyyy-MM-dd').format(_fromDate!),
        toDate: DateFormat(
          'yyyy-MM-dd',
        ).format(_isHalfDay ? _fromDate! : _toDate!),
        reason: _reasonController.text.trim(),
        isHalfDay: _isHalfDay,
      );

      if (errorMessage == null) {
        setState(() {
          _isLoading = false;
          _successMessage = 'Leave application submitted successfully!';
          _errorMessage = null; // Clear any previous error messages
        });
        _formKey.currentState!.reset();
        _reasonController.clear();
        setState(() {
          _selectedLeaveType = null;
          _fromDate = null;
          _toDate = null;
          _isHalfDay = false;
        });
        _fetchLeaveApplications();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = errorMessage;
          _successMessage = null; // Clear any previous success messages
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      appBar: AppBar(
        title: const Text('Leave Management', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchLeaveApplications();
          await _fetchLeaveTypes();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLeaveApplicationsList(),
              const SizedBox(height: 30),
              _buildLeaveApplicationForm(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveApplicationsList() {
    final displayedApplications = _getFilteredApplications();
    final hasMultipleApplications = _leaveApplications.length > 1;

    return _card(
      [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: kInputDecoration.copyWith(
                  hintText: 'Search...',
                  prefixIcon: const Icon(Icons.search),
                  fillColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 10),
            DropdownButton<String>(
              dropdownColor: Colors.white,
              value: _selectedStatus,
              hint: const Text('Status'),
              items: ['Open', 'Approved', 'Rejected','Cancelled']
                  .map((status) => DropdownMenuItem(
                        value: status,
                        child: Text(status),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        _isLoadingApplications
            ? ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 2, // Display 2 skeleton cards
                itemBuilder: (context, index) => const _LeaveApplicationCardSkeleton(),
              )
            : displayedApplications.isEmpty
                ? const Center(child: Text('No leave applications found.'))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedApplications.length,
                    itemBuilder: (context, index) {
                      final application = displayedApplications[index];
                      return _LeaveApplicationCard(application: application);
                    },
                  ),
        if (hasMultipleApplications && !_showAllApplications)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Center(
              child: OutlinedButton(
                onPressed: _toggleShowAllApplications,
                child: const Text('Show All Applications'),
              ),
            ),
          ),
        if (_showAllApplications)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Center(
              child: OutlinedButton(
                onPressed: _toggleShowAllApplications,
                child: const Text('Hide All Applications'),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLeaveApplicationForm() {
    return Form(
      key: _formKey,
      child: _card(
        [
          const Text(
            'Apply for Leave',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          if (_successMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.green.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Leave application submitted successfully!',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),

          if (_errorMessage != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

          // Leave Type Dropdown
          DropdownButtonFormField<String>(
            value: _selectedLeaveType,
            dropdownColor: Colors.white,
            decoration: kInputDecoration.copyWith(labelText: 'Leave Type'),
            items: _availableLeaveTypes.map((String type) {
              return DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              );
            }).toList(),
            onChanged: (value) {
              setState(() {
                _selectedLeaveType = value;
              });
            },
            validator: (value) =>
                value == null ? 'Please select a leave type' : null,
          ),
          const SizedBox(height: 20),

          // Half Day Switch
          SwitchListTile(
            title: const Text('Half Day'),
            value: _isHalfDay,
            onChanged: (bool value) {
              setState(() {
                _isHalfDay = value;
                if (_isHalfDay) {
                  _toDate = _fromDate; // Ensure toDate is same as fromDate for half day
                }
              });
            },
            activeColor: goldAccent,
            contentPadding: EdgeInsets.zero, // Remove default padding
          ),
          const SizedBox(height: 20),

          // Date Pickers
          Row(
              children: [
                /// FROM DATE
                Expanded(
                  child: TextFormField(
                    decoration: kInputDecoration.copyWith(
                      labelText: 'From Date',
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: _fromDate == null
                          ? ''
                          : DateFormat('yyyy-MM-dd').format(_fromDate!),
                    ),
                    onTap: () async {
                      final pickedDate = await _showThemedDatePicker(
                        context: context,
                        initialDate: _fromDate ?? DateTime.now(),
                        firstDate: DateTime(2000),
                      );

                      if (pickedDate != null) {
                        setState(() {
                          _fromDate = pickedDate;

                          // Reset To Date if it's before From Date
                          if (_toDate != null && _toDate!.isBefore(pickedDate)) {
                            _toDate = null;
                          }
                        });
                      }
                    },
                    validator: (_) =>
                        _fromDate == null ? 'Please select a from date' : null,
                  ),
                ),

                const SizedBox(width: 20),

                /// TO DATE
                if (!_isHalfDay)
                  Expanded(
                    child: TextFormField(
                      decoration: kInputDecoration.copyWith(
                        labelText: 'To Date',
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: _toDate == null
                            ? ''
                            : DateFormat('yyyy-MM-dd').format(_toDate!),
                      ),
                      onTap: () async {
                        final pickedDate = await _showThemedDatePicker(
                          context: context,
                          initialDate: _toDate ?? _fromDate ?? DateTime.now(),
                          firstDate: _fromDate ?? DateTime.now(),
                        );

                        if (pickedDate != null) {
                          setState(() {
                            _toDate = pickedDate;
                          });
                        }
                      },
                      validator: (_) =>
                          _toDate == null ? 'Please select a to date' : null,
                    ),
                  ),
              ],
            ),

          const SizedBox(height: 20),

          // Reason Field
          TextFormField(
            controller: _reasonController,
            decoration: kInputDecoration.copyWith(
              labelText: 'Reason',
              hintText: 'Enter the reason for your leave',
            ),
            maxLines: 3,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a reason';
              }
              return null;
            },
          ),
          const SizedBox(height: 30),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitLeaveApplication,
              style: ElevatedButton.styleFrom(
                backgroundColor: goldAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                  : const Text(
                      'Submit Application',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(List<Widget> children) {
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
        children: children,
      ),
    );
  }
}

class _LeaveApplicationCard extends StatelessWidget {
  const _LeaveApplicationCard({
    required this.application,
  });

  final LeaveApplication application;

 Color _getStatusColor(String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return const Color(0xFFE8F0FE); // Google Blue Tint
    case 'approved':
      return const Color(0xFFE6F4EA); // Google Green Tint
    case 'rejected':
      return const Color(0xFFFCE8E6); // Google Red Tint
    default:
      return const Color(0xFFF1F3F4); // Google Grey Tint
  }
}

Color _getStatusTextColor(String status) {
  switch (status.toLowerCase()) {
    case 'open':
      return const Color(0xFF1967D2); // Corporate Blue
    case 'approved':
      return const Color(0xFF137333); // Corporate Green
    case 'rejected':
      return const Color(0xFFC5221F); // Corporate Red
    default:
      return const Color(0xFF5F6368); // Corporate Grey
  }
}

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  application.leaveType,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Chip(
                  label: Text(
                    application.status,
                    style: TextStyle(color: _getStatusTextColor(application.status)),
                  ),
                  backgroundColor: _getStatusColor(application.status),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Applied on: ${application.postingDate}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            Row(
              children: [
                const Icon(Icons.date_range, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${application.fromDate} to ${application.toDate}',
                ),
                const Spacer(),
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${application.totalLeaveDays} '
                  '${application.totalLeaveDays == 1 ? "day" : "days"}',
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (application.description.isNotEmpty)
              Text(
                'Reason: ${application.description}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }
}

class _LeaveApplicationCardSkeleton extends StatelessWidget {
  const _LeaveApplicationCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    Color? skeletonColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Card(
      color: isDark ? Colors.grey[850] : Colors.white,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 120,
                  height: 18,
                  color: skeletonColor,
                ),
                Container(
                  width: 70,
                  height: 25,
                  color: skeletonColor,
                  // borderRadius: BorderRadius.circular(12),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: 180,
              height: 14,
              color: skeletonColor,
            ),
            const Divider(height: 24),
            Row(
              children: [
                Container(width: 16, height: 16, color: skeletonColor),
                const SizedBox(width: 8),
                Container(
                  width: 100,
                  height: 16,
                  color: skeletonColor,
                ),
                const Spacer(),
                Container(width: 16, height: 16, color: skeletonColor),
                const SizedBox(width: 8),
                Container(
                  width: 50,
                  height: 16,
                  color: skeletonColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 14,
              color: skeletonColor,
            ),
          ],
        ),
      ),
    );
  }
}
