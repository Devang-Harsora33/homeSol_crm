import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import '../models/lead.dart';
import '../models/project.dart';
import '../services/api_service.dart';
import '../services/apis/leads/lead_service.dart';

class AddEnquirySheet {
  static Future<void> show(
    BuildContext context, {
    required List<Project> projects,
    required String? brokerId,
    VoidCallback? onCreated,
    String? initialSelectedProjectId,
    bool lockProjectSelection = false,
  }) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    bool accepted = false;

    // Controllers
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    bool isFormattingPhone = false;
    final commentController = TextEditingController();
    final budgetController = TextEditingController();
    int budgetNumericCache = 0;

    List<String> selectedProjectIds = initialSelectedProjectId != null
        ? [initialSelectedProjectId]
        : <String>[];
    String? selectedConfiguration;
    String? errorMessage;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SizedBox(
              height: MediaQuery.of(context).size.height * 0.85,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Add New Enquiry',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.close,
                            color: (isDark ? Colors.white : Colors.black)
                                .withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (lockProjectSelection)
                              _LockedProjectField(
                                label: 'Selected Projects',
                                value: projects
                                    .map((p) => p.projectName)
                                    .join(', '),
                              )
                            else
                              _LabeledMultiSelectProjects(
                                label: 'Select Projects',
                                projects: projects,
                                selectedIds: selectedProjectIds,
                                onChanged: (ids) {
                                  setSheetState(() {
                                    selectedProjectIds = ids;
                                    selectedConfiguration = null;
                                  });
                                },
                              ),
                            const SizedBox(height: 12),
                            // Configuration dropdown - shows BHK options from selected project
                            if (lockProjectSelection)
                              _LabeledDropdown(
                                label: 'Select Configuration',
                                hint: 'Choose BHK Type',
                                items: projects
                                    .expand((p) => p.configurations)
                                    .map((c) => c.name)
                                    .toSet()
                                    .toList(), // Remove duplicates
                                value: selectedConfiguration,
                                onChanged: (value) {
                                  selectedConfiguration = value;
                                },
                              )
                            else if (selectedProjectIds.isNotEmpty)
                              _LabeledDropdown(
                                label: 'Select Configuration',
                                hint: 'Choose BHK Type',
                                items: projects
                                    .where(
                                      (p) => selectedProjectIds.contains(p.id),
                                    )
                                    .expand((p) => p.configurations)
                                    .map((c) => c.name)
                                    .toSet()
                                    .toList(),
                                value: selectedConfiguration,
                                onChanged: (value) {
                                  selectedConfiguration = value;
                                },
                              ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              label: 'Client Name',
                              hint: 'Enter Name',
                              keyboardType: TextInputType.name,
                              controller: nameController,
                            ),
                            const SizedBox(height: 12),
                            _LabeledTextField(
                              label: 'Client Phone',
                              hint: 'Enter Phone (10 digits or 5 Digits)',
                              keyboardType: TextInputType.phone,
                              controller: phoneController,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              onChanged: (value) {
                                if (isFormattingPhone) {
                                  isFormattingPhone = false;
                                  return;
                                }

                                // Clear error message when user starts typing
                                if (errorMessage != null) {
                                  setSheetState(() {
                                    errorMessage = null;
                                  });
                                }

                                // Extract only digits
                                final digits = value.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );

                                // Limit to 10 digits
                                final limitedDigits = digits.length > 10
                                    ? digits.substring(0, 10)
                                    : digits;

                                String formatted = '';
                                if (limitedDigits.length < 6) {
                                  // Show asterisks first, then the digits, until 6 digits are added
                                  formatted =
                                      '*' * (6 - limitedDigits.length) +
                                      limitedDigits;
                                } else {
                                  // Show all digits (6 to 10)
                                  formatted = limitedDigits;
                                }

                                if (formatted != value) {
                                  isFormattingPhone = true;
                                  phoneController.value = TextEditingValue(
                                    text: formatted,
                                    selection: TextSelection.collapsed(
                                      offset: formatted.length,
                                    ),
                                  );
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            // Removed Email Address field as per updated schema
                            _LabeledTextField(
                              label: 'Budget (₹)',
                              hint: 'Enter Budget (e.g., 5Cr, 50L, 500K)',
                              keyboardType: TextInputType.text,
                              controller: budgetController,
                              onChanged: (value) {
                                // Clear error message when user starts typing
                                if (errorMessage != null) {
                                  setSheetState(() {
                                    errorMessage = null;
                                  });
                                }

                                // Parse the input to extract number and unit
                                final parsed = _parseBudgetInput(value);
                                budgetNumericCache =
                                    parsed['numericValue'] ?? 0;

                                // Debug print to see what's happening
                                print(
                                  'Input: $value, Parsed: $parsed, Numeric: $budgetNumericCache',
                                );
                              },
                            ),
                            if (budgetNumericCache > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                '≈ ₹${_formatNumber(budgetNumericCache)}',
                                style: TextStyle(
                                  color: (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.6),
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            _LabeledMultiline(
                              label: 'Comment',
                              hint: 'Enter Comments',
                              controller: commentController,
                            ),
                            // Error message display
                            if (errorMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: Colors.red,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        errorMessage!,
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Checkbox(
                          value: accepted,
                          onChanged: (v) =>
                              setSheetState(() => accepted = v ?? false),
                        ),
                        Expanded(
                          child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.85),
                                fontSize: 14,
                              ),
                              children: [
                                const TextSpan(text: 'I accept the '),
                                TextSpan(
                                  text: 'Terms and Conditions',
                                  style: TextStyle(
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: accepted
                            ? () async {
                                // Clear previous error
                                setSheetState(() {
                                  errorMessage = null;
                                });

                                // Validate required fields
                                if (nameController.text.isEmpty ||
                                    phoneController.text.isEmpty ||
                                    budgetController.text.isEmpty ||
                                    (!lockProjectSelection &&
                                        selectedProjectIds.isEmpty) ||
                                    selectedConfiguration == null ||
                                    brokerId == null) {
                                  setSheetState(() {
                                    errorMessage =
                                        'Please fill all required fields';
                                  });
                                  return;
                                }

                                // Validate phone number
                                final phoneDigits = phoneController.text
                                    .replaceAll(RegExp(r'[^0-9]'), '');
                                if (phoneDigits.length != 5 &&
                                    phoneDigits.length != 10) {
                                  setSheetState(() {
                                    errorMessage =
                                        'Please enter either last 5 digits or complete 10-digit phone number';
                                  });
                                  return;
                                }

                                // Format phone number for backend
                                String phoneForBackend;
                                if (phoneDigits.length == 5) {
                                  phoneForBackend = '*****$phoneDigits';
                                } else {
                                  phoneForBackend = phoneDigits;
                                }

                                // Validate budget input
                                if (budgetNumericCache <= 0) {
                                  setSheetState(() {
                                    errorMessage =
                                        'Please enter a valid budget amount (e.g., 5Cr, 50L, 500K)';
                                  });
                                  return;
                                }

                                try {
                                  // Get all project IDs - if lockProjectSelection is true, use all projects
                                  final projectIds = lockProjectSelection
                                      ? projects.map((p) => p.id).toList()
                                      : List<String>.from(selectedProjectIds);

                                  final lead = Lead(
                                    customerPhone: phoneForBackend,
                                    customerName: nameController.text,
                                    brokerId:
                                        brokerId ?? '', // Should not be null here
                                    projectId: projectIds,
                                    status: 'pending',
                                    budget: budgetNumericCache,
                                    notes: commentController.text.isNotEmpty
                                        ? [
                                            LeadNote(
                                              note: commentController.text,
                                              addedBy:
                                                  'User', // You can change this if you have the user's name
                                              addedOn: DateTime.now(),
                                            ),
                                          ]
                                        : [],
                                    configuration: [selectedConfiguration!],
                                  );

                                  await LeadService.createLead(lead);
                                  Navigator.pop(context);
                                  onCreated?.call();

                                  // Show success message
                                  CustomSnackBar.show(context, 
                                    message: lockProjectSelection && projects.length > 1
                                            ? 'Enquiry initiated for ${projects.length} projects!'
                                            : 'Enquiry initiated successfully!',
                                    isError: false, 
                                    title: 'Notice'
                                  );
                                } catch (e) {
                                  String errorMsg = 'Failed to create enquiry';

                                  // Parse specific error messages
                                  if (e.toString().contains('network') ||
                                      e.toString().contains('connection')) {
                                    errorMsg =
                                        'Network error. Please check your internet connection.';
                                  } else if (e.toString().contains('timeout')) {
                                    errorMsg =
                                        'Request timed out. Please try again.';
                                  } else if (e.toString().contains('server')) {
                                    errorMsg =
                                        'Server error. Please try again later.';
                                  } else if (e.toString().contains(
                                        'validation',
                                      ) ||
                                      e.toString().contains('invalid')) {
                                    errorMsg =
                                        'Invalid data provided. Please check your inputs.';
                                  } else if (e.toString().isNotEmpty) {
                                    errorMsg =
                                        'Error: ${e.toString().replaceAll('Exception: ', '')}';
                                  }

                                  setSheetState(() {
                                    errorMessage = errorMsg;
                                  });
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: theme.colorScheme.primary
                              .withOpacity(0.15),
                          disabledForegroundColor: theme.colorScheme.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Create'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// Local UI helpers duplicated here for reusability without coupling to CRM page
class _LabeledText extends StatelessWidget {
  final String text;
  const _LabeledText(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.85),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _FieldContainer extends StatelessWidget {
  final Widget child;
  const _FieldContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
        ),
      ),
      child: child,
    );
  }
}

class _LabeledTextField extends StatelessWidget {
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final TextEditingController? controller;
  final Function(String)? onChanged;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;

  const _LabeledTextField({
    required this.label,
    required this.hint,
    required this.keyboardType,
    this.controller,
    this.onChanged,
    this.maxLength,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledText(label),
        _FieldContainer(
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            onChanged: onChanged,
            maxLength: maxLength,
            inputFormatters: inputFormatters,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              counterText: "",
              hintStyle: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockedProjectField extends StatelessWidget {
  final String label;
  final String value;
  const _LockedProjectField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledText(label),
        _FieldContainer(
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(
                Icons.lock,
                size: 18,
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LabeledDropdown extends StatelessWidget {
  final String label;
  final String hint;
  final List<String> items;
  final Function(String?)? onChanged;
  final String? value;
  const _LabeledDropdown({
    required this.label,
    required this.hint,
    required this.items,
    this.onChanged,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    String? selected = value;
    return StatefulBuilder(
      builder: (context, setState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LabeledText(label),
            _FieldContainer(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: selected,
                  hint: Text(
                    hint,
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        0.6,
                      ),
                      fontSize: 16,
                    ),
                  ),
                  dropdownColor: theme.scaffoldBackgroundColor,
                  items: items
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text(
                            e,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    setState(() => selected = v);
                    onChanged?.call(v);
                  },
                  icon: Icon(
                    Icons.keyboard_arrow_down,
                    color: (isDark ? Colors.white : Colors.black).withOpacity(
                      0.8,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _LabeledMultiSelectProjects extends StatelessWidget {
  final String label;
  final List<Project> projects;
  final List<String> selectedIds;
  final ValueChanged<List<String>> onChanged;

  const _LabeledMultiSelectProjects({
    required this.label,
    required this.projects,
    required this.selectedIds,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledText(label),
        _FieldContainer(
          child: InkWell(
            onTap: () async {
              final result = await showModalBottomSheet<List<String>>(
                context: context,
                isScrollControlled: true,
                backgroundColor: theme.scaffoldBackgroundColor,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                builder: (context) {
                  final Set<String> temp = selectedIds.toSet();
                  String query = '';
                  return StatefulBuilder(
                    builder: (context, setSheetState) {
                      final filtered = projects.where((p) {
                        if (query.isEmpty) return true;
                        final q = query.toLowerCase();
                        return p.projectName.toLowerCase().contains(q);
                      }).toList();

                      return SafeArea(
                        child: Padding(
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Container(
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color:
                                                (isDark
                                                        ? Colors.white
                                                        : Colors.black)
                                                    .withOpacity(0.06),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color:
                                                  (isDark
                                                          ? Colors.white
                                                          : Colors.black)
                                                      .withOpacity(0.12),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const SizedBox(width: 12),
                                              Icon(
                                                Icons.search,
                                                color:
                                                    (isDark
                                                            ? Colors.white
                                                            : Colors.black)
                                                        .withOpacity(0.7),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: TextField(
                                                  autofocus: true,
                                                  onChanged: (v) =>
                                                      setSheetState(
                                                        () => query = v,
                                                      ),
                                                  decoration:
                                                      const InputDecoration(
                                                        hintText:
                                                            'Search projects',
                                                        border:
                                                            InputBorder.none,
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed: () => setSheetState(() {
                                          temp
                                            ..clear()
                                            ..addAll(projects.map((p) => p.id));
                                        }),
                                        child: const Text('Select All'),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(height: 1),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    itemBuilder: (context, index) {
                                      final p = filtered[index];
                                      final checked = temp.contains(p.id);
                                      return CheckboxListTile(
                                        value: checked,
                                        onChanged: (v) => setSheetState(() {
                                          if (v == true) {
                                            temp.add(p.id);
                                          } else {
                                            temp.remove(p.id);
                                          }
                                        }),
                                        controlAffinity:
                                            ListTileControlAffinity.leading,
                                        title: Text(
                                          p.projectName,
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : Colors.black,
                                            fontWeight: checked
                                                ? FontWeight.w700
                                                : FontWeight.w500,
                                          ),
                                        ),
                                        secondary: checked
                                            ? Icon(
                                                Icons.check_circle,
                                                color:
                                                    theme.colorScheme.primary,
                                              )
                                            : null,
                                      );
                                    },
                                  ),
                                ),
                                const Divider(height: 1),
                                Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: OutlinedButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            selectedIds,
                                          ),
                                          child: const Text('Cancel'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton(
                                          onPressed: () => Navigator.pop(
                                            context,
                                            temp.toList(),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                theme.colorScheme.primary,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: const Text('Done'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              );

              if (result != null) {
                onChanged(result);
              }
            },
            child: Row(
              children: [
                Expanded(
                  child: selectedIds.isEmpty
                      ? Text(
                          'Tap to select projects',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                        )
                      : Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: projects
                              .where((p) => selectedIds.contains(p.id))
                              .map(
                                (p) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: theme.colorScheme.primary
                                          .withOpacity(0.4),
                                    ),
                                  ),
                                  child: Text(
                                    p.projectName,
                                    style: TextStyle(
                                      color: theme.colorScheme.primary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                ),
                Icon(
                  Icons.keyboard_arrow_down,
                  color: (isDark ? Colors.white : Colors.black).withOpacity(
                    0.8,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LabeledMultiline extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController? controller;
  const _LabeledMultiline({
    required this.label,
    required this.hint,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LabeledText(label),
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: (isDark ? Colors.white : Colors.black).withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (isDark ? Colors.white : Colors.black).withOpacity(0.12),
            ),
          ),
          child: TextField(
            controller: controller,
            maxLines: null,
            expands: true,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: (isDark ? Colors.white : Colors.black).withOpacity(0.6),
                fontSize: 16,
              ),
            ),
            style: TextStyle(
              color: isDark ? Colors.white : Colors.black,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }
}

String _formatNumber(int number) {
  return number.toString().replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (Match m) => '${m[1]},',
  );
}

// Parse budget input like "5Cr", "50L", "500K" to numeric value
Map<String, dynamic> _parseBudgetInput(String input) {
  if (input.isEmpty) return {'numericValue': 0, 'unit': '', 'number': 0};

  // Remove spaces and convert to lowercase
  final cleanInput = input.trim().toLowerCase();
  print('Clean input: "$cleanInput"');

  // Extract number and unit using regex - more flexible pattern
  final regex = RegExp(r'^(\d+(?:\.\d+)?)\s*([crlkm]?)$');
  final match = regex.firstMatch(cleanInput);
  print('Regex match: $match');

  // Also try a simpler pattern for debugging
  final simpleRegex = RegExp(r'(\d+)\s*([crlkm]?)');
  final simpleMatch = simpleRegex.firstMatch(cleanInput);
  print('Simple regex match: $simpleMatch');

  if (match == null) {
    // Try simple regex as fallback
    if (simpleMatch != null) {
      final numberStr = simpleMatch.group(1)!;
      final unit = simpleMatch.group(2) ?? '';
      final number = double.tryParse(numberStr) ?? 0;

      print('Simple match - Number: $number, Unit: "$unit"');

      int multiplier = 1;
      switch (unit) {
        case 'cr':
        case 'c':
          multiplier = 10000000; // 1 crore = 10 million
          break;
        case 'l':
          multiplier = 100000; // 1 lakh = 100 thousand
          break;
        case 'k':
          multiplier = 1000; // 1 thousand
          break;
        case 'm':
          multiplier = 1000000; // 1 million
          break;
        default:
          multiplier = 1; // No unit, treat as is
      }

      final numericValue = (number * multiplier).round();
      print('Simple match - Final numeric value: $numericValue');
      return {'numericValue': numericValue, 'unit': unit, 'number': number};
    }

    // Try to extract just numbers if no unit found
    final numberMatch = RegExp(r'(\d+(?:\.\d+)?)').firstMatch(cleanInput);
    if (numberMatch != null) {
      final number = double.tryParse(numberMatch.group(1)!) ?? 0;
      print('Number only match: $number');
      return {'numericValue': number.toInt(), 'unit': '', 'number': number};
    }
    print('No match found');
    return {'numericValue': 0, 'unit': '', 'number': 0};
  }

  final numberStr = match.group(1)!;
  final unit = match.group(2) ?? '';
  final number = double.tryParse(numberStr) ?? 0;

  print('Number: $number, Unit: "$unit"');

  int multiplier = 1;
  switch (unit) {
    case 'cr':
    case 'c':
      multiplier = 10000000; // 1 crore = 10 million
      break;
    case 'l':
      multiplier = 100000; // 1 lakh = 100 thousand
      break;
    case 'k':
      multiplier = 1000; // 1 thousand
      break;
    case 'm':
      multiplier = 1000000; // 1 million
      break;
    default:
      multiplier = 1; // No unit, treat as is
  }

  final numericValue = (number * multiplier).round();
  print('Final numeric value: $numericValue');
  return {'numericValue': numericValue, 'unit': unit, 'number': number};
}
