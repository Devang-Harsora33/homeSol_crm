import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  int _currentStep = 0;
  bool _isLoading = false;

  // Controllers for form fields
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _firmNameController = TextEditingController();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _reraController = TextEditingController();
  bool? _freelancing;
  String? _workmode; // e.g., Remote, Hybrid, On-site
  String? _teamSize; // <10, 10-20, 20-50, >50

  // Profile image
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firmNameController.dispose();
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _reraController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _profileImage = File(image.path);
      });
    }
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });
    final theme = Theme.of(context);

    try {
      final result = await AuthService.registerBroker(
        username: _usernameController.text.trim(),
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firmName: _firmNameController.text.trim(),
        name: _nameController.text.trim(),
        address: _addressController.text.trim(),
        phoneNo: _phoneController.text.trim(),
        reraNumber: _reraController.text.trim(),
        profileImage: _profileImage?.path,
        freelancing: _freelancing ?? false,
        workmode: _workmode ?? '',
        teamSize: _teamSize ?? '',
      );

      if (!mounted) return;

      if (result['success']) {
        // Show success message and navigate to login
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Registration successful! Please login.'),
            backgroundColor: theme.colorScheme.primary,
          ),
        );

        // Navigate back to login page
        Navigator.of(context).pop();
      } else {
        // Show error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error']), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _nextStep() {
    if (_currentStep < 3) {
      setState(() {
        _currentStep++;
      });
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // final isDark = theme.brightness == Brightness.dark; // unused

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Create Account',
          style: TextStyle(
            color: theme.textTheme.headlineSmall?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Stepper
            Container(
              padding: const EdgeInsets.all(16),
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: _nextStep,
                onStepCancel: _previousStep,
                controlsBuilder: (context, details) {
                  if (_currentStep == 3) {
                    return const SizedBox.shrink();
                  }
                  return Row(
                    children: [
                      if (_currentStep > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: theme.textTheme.bodyLarge?.color,
                              side: BorderSide(color: theme.dividerColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text('Previous'),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFddbe6c),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text('Next'),
                        ),
                      ),
                    ],
                  );
                },
                steps: [
                  // Step 1: Basic Information
                  Step(
                    title: Text(
                      'Basic Info',
                      style: TextStyle(
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    content: Column(
                      children: [
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _usernameController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Username',
                            Icons.person_outline,
                            theme,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Username is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // moved work details to Personal Info step
                        TextFormField(
                          controller: _emailController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Email',
                            Icons.email_outlined,
                            theme,
                          ),
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value)) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Password',
                            Icons.lock_outline,
                            theme,
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Password is required';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _confirmPasswordController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Confirm Password',
                            Icons.lock_outline,
                            theme,
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (value != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                    isActive: _currentStep >= 0,
                  ),

                  // Step 2: Personal Information
                  Step(
                    title: Text(
                      'Personal Info',
                      style: TextStyle(
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    content: Column(
                      children: [
                        // Freelancing Toggle
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Full Name',
                            Icons.person,
                            theme,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Full name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Phone Number',
                            Icons.phone,
                            theme,
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Phone number is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        SwitchListTile(
                          value: _freelancing ?? false,
                          onChanged: (v) => setState(() => _freelancing = v),
                          title: Text(
                            'Freelancing',
                            style: TextStyle(
                              color: theme.textTheme.bodyLarge?.color,
                            ),
                          ),
                          subtitle: Text(
                            'Are you working as a freelancer?',
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color
                                  ?.withOpacity(0.7),
                            ),
                          ),
                          activeColor: const Color(0xFFddbe6c),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                    isActive: _currentStep >= 1,
                  ),

                  // Step 3: Business Information
                  Step(
                    title: Text(
                      'Business Info',
                      style: TextStyle(
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    content: Column(
                      children: [
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _firmNameController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Firm Name',
                            Icons.business,
                            theme,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Firm name is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        // Work Mode
                        DropdownButtonFormField<String>(
                          value: _workmode,
                          decoration: _buildInputDecoration(
                            'Work Mode',
                            Icons.work_outline,
                            theme,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Remote',
                              child: Text('Remote'),
                            ),
                            DropdownMenuItem(
                              value: 'Hybrid',
                              child: Text('Hybrid'),
                            ),
                            DropdownMenuItem(
                              value: 'On-site',
                              child: Text('On-site'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _workmode = v),
                        ),
                        const SizedBox(height: 16),
                        // Team Size
                        DropdownButtonFormField<String>(
                          value: _teamSize,
                          decoration: _buildInputDecoration(
                            'Team Size',
                            Icons.group_outlined,
                            theme,
                          ),
                          items: const [
                            DropdownMenuItem(value: '<10', child: Text('<10')),
                            DropdownMenuItem(
                              value: '10-20',
                              child: Text('10-20'),
                            ),
                            DropdownMenuItem(
                              value: '20-50',
                              child: Text('20-50'),
                            ),
                            DropdownMenuItem(value: '>50', child: Text('>50')),
                          ],
                          onChanged: (v) => setState(() => _teamSize = v),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _reraController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'RERA Number',
                            Icons.verified,
                            theme,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'RERA number is required';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                          decoration: _buildInputDecoration(
                            'Address',
                            Icons.location_on,
                            theme,
                          ),

                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Address is required';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                    isActive: _currentStep >= 2,
                  ),

                  // Step 4: Profile Image
                  Step(
                    title: Text(
                      'Profile Image',
                      style: TextStyle(
                        color: theme.textTheme.titleMedium?.color,
                      ),
                    ),
                    content: Column(
                      children: [
                        GestureDetector(
                          onTap: _pickImage,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: theme.cardColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(60),
                              border: Border.all(
                                color: theme.dividerColor.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: _profileImage != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(58),
                                    child: Image.file(
                                      _profileImage!,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_a_photo,
                                        color: theme.iconTheme.color
                                            ?.withOpacity(0.7),
                                        size: 40,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Add Photo',
                                        style: TextStyle(
                                          color: theme
                                              .textTheme
                                              .bodyMedium
                                              ?.color
                                              ?.withOpacity(0.7),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Tap to add your profile image',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    isActive: _currentStep >= 3,
                  ),
                ],
              ),
            ),

            // Register Button (only show on last step)
            if (_currentStep == 3)
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _register,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFddbe6c),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Create Account',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(
    String label,
    IconData icon,
    ThemeData theme,
  ) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
      ),
      prefixIcon: Icon(icon, color: theme.iconTheme.color?.withOpacity(0.7)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: theme.dividerColor.withOpacity(0.3)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFddbe6c), width: 2),
      ),
      filled: true,
      fillColor: theme.cardColor.withOpacity(0.1),
    );
  }
}
