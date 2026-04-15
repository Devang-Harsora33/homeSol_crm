import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:Homesol/models/profile.dart';
import 'package:Homesol/services/auth_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:Homesol/services/api_service.dart';

class BrokerProfilePage extends StatefulWidget {
  final ThemeData theme;
  final Profile? profile;

  const BrokerProfilePage({super.key, required this.theme, this.profile});

  @override
  State<BrokerProfilePage> createState() => _BrokerProfilePageState();
}

class _BrokerProfilePageState extends State<BrokerProfilePage> {
  Profile? profile;
  bool isLoading = true;
  final Color kPrimaryColor = const Color(0xFF675D40);
  final Color kTextSecondary = Colors.grey.shade600;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      profile = widget.profile;
      isLoading = false;
    } else {
      _loadProfile();
    }
  }

  Future<void> _loadProfile() async {
    try {
      final p = await AuthService.getMyProfile();
      if (mounted) {
        setState(() {
          profile = p;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (profile == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Profile"),
          backgroundColor: kPrimaryColor,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const FaIcon(FontAwesomeIcons.arrowLeft, color: Colors.white, size: 20),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(FontAwesomeIcons.userSlash, size: 64, color: kTextSecondary),
              const SizedBox(height: 16),
              const Text("No profile data found."),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, profile!),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  
                  // --- Personal Information ---
                  _buildSectionContainer("Personal Information", [
                    _DetailItem(icon: FontAwesomeIcons.cakeCandles, label: "Date of Birth", value: profile!.dateOfBirth),
                    _DetailItem(icon: FontAwesomeIcons.person, label: "Gender", value: profile!.gender),
                    _DetailItem(icon: FontAwesomeIcons.ring, label: "Marital Status", value: profile!.maritalStatus),
                    _DetailItem(icon: FontAwesomeIcons.droplet, label: "Blood Group", value: profile!.bloodGroup),
                  ]),

                  const SizedBox(height: 16),

                  // --- Contact Details ---
                  _buildSectionContainer("Contact Details", [
                    _DetailItem(icon: FontAwesomeIcons.mobileScreen, label: "Mobile", value: profile!.cellNumber, isHighlight: true),
                    _DetailItem(icon: FontAwesomeIcons.envelope, label: "Personal Email", value: profile!.personalEmail),
                    _DetailItem(icon: FontAwesomeIcons.at, label: "Work Email", value: profile!.companyEmail),
                    _DetailItem(icon: FontAwesomeIcons.mapPin, label: "Current Address", value: profile!.currentAddress),
                    _DetailItem(icon: FontAwesomeIcons.house, label: "Permanent Address", value: profile!.permanentAddress),
                  ]),

                  const SizedBox(height: 16),

                  // --- Employment Data ---
                  _buildSectionContainer("Employment Data", [
                    _DetailItem(icon: FontAwesomeIcons.building, label: "Company", value: profile!.company),
                    _DetailItem(icon: FontAwesomeIcons.sitemap, label: "Department", value: profile!.department),
                    _DetailItem(icon: FontAwesomeIcons.idBadge, label: "Designation", value: profile!.designation),
                    _DetailItem(icon: FontAwesomeIcons.calendarCheck, label: "Joined", value: profile!.dateOfJoining),
                    _DetailItem(icon: FontAwesomeIcons.userTie, label: "Reports To", value: profile!.reportsTo),
                    _DetailItem(icon: FontAwesomeIcons.fileContract, label: "Type", value: profile!.employmentType),
                  ]),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Profile profile) {
    ImageProvider<Object>? provider;
    if (profile.image != null && profile.image!.isNotEmpty) {
      String imageUrl = profile.image!;
      if (!imageUrl.startsWith('http')) {
        imageUrl = '${AuthService.baseUrl}$imageUrl';
      }
      provider = NetworkImage(imageUrl);
    }

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: kPrimaryColor,
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: Colors.white),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner color or image
            Container(color: kPrimaryColor.withOpacity(0.9)),
            // Profile Info Overlay
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white,
                      child: CircleAvatar(
                        radius: 56,
                        backgroundColor: Colors.grey.shade200,
                        backgroundImage: provider,
                        child: provider == null ? Icon(Icons.person, size: 60, color: kPrimaryColor) : null,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadImage,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                          ),
                          child: Icon(Icons.camera_alt, size: 20, color: kPrimaryColor),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  profile.employeeName,
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                ),
                Text(
                  profile.designation ?? "",
                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() => isLoading = true);
      try {
        final bytes = await image.readAsBytes();
        final base64Image = 'data:image/${path.extension(image.path).replaceAll('.', '')};base64,${base64.encode(bytes)}';
        
        final fileUrl = await ApiService.uploadFile(
          filename: path.basename(image.path),
          filedata: base64Image,
          doctype: 'Employee',
          docname: profile!.name,
        );

        if (fileUrl != null) {
          // Now update the Employee record with the new file URL
          final result = await ApiService.updateEmployee(profile!.name, {'image': fileUrl});
          if (result['success']) {
            _loadProfile();
          } else {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['message'])));
          }
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error uploading image: $e")));
      } finally {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _buildSectionContainer(String title, List<Widget> children) {
    // Filter out _DetailItems with null/empty values
    final visibleChildren = children.where((c) {
      if (c is _DetailItem) return c.value != null && c.value!.isNotEmpty;
      return true;
    }).toList();

    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          ...visibleChildren,
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String? value;
  final bool isHighlight;

  const _DetailItem({
    required this.icon,
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF675D40).withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: FaIcon(icon, size: 18, color: const Color(0xFF675D40)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                Text(
                  value!,
                  style: TextStyle(
                    color: isHighlight ? const Color(0xFF675D40) : Colors.black87,
                    fontWeight: isHighlight ? FontWeight.bold : FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}