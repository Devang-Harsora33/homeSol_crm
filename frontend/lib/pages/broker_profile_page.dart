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
                  _buildGridSection("Personal Information", Icons.person_outline_rounded, [
                    _buildGridRow(
                      _buildGridTile(FontAwesomeIcons.cakeCandles, "Date of Birth", profile!.dateOfBirth),
                      _buildGridTile(FontAwesomeIcons.person, "Gender", profile!.gender),
                    ),
                    _buildGridRow(
                      _buildGridTile(FontAwesomeIcons.ring, "Marital Status", profile!.maritalStatus),
                      _buildGridTile(FontAwesomeIcons.droplet, "Blood Group", profile!.bloodGroup),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // --- Contact Details ---
                  _buildGridSection("Contact Details", Icons.contact_phone_outlined, [
                    _buildFullWidthTile(Icons.phone_iphone_rounded, "Mobile", profile!.cellNumber, iconColor: Colors.green.shade600),
                    _buildFullWidthTile(Icons.email_outlined, "Personal Email", profile!.personalEmail, iconColor: Colors.blue.shade600),
                    _buildFullWidthTile(Icons.work_outline_rounded, "Work Email", profile!.companyEmail, iconColor: Colors.orange.shade700),
                    _buildFullWidthTile(Icons.location_on_outlined, "Current Address", profile!.currentAddress),
                    _buildFullWidthTile(Icons.home_outlined, "Permanent Address", profile!.permanentAddress),
                  ]),

                  const SizedBox(height: 16),

                  // --- Employment Data ---
                  _buildGridSection("Employment Data", Icons.corporate_fare_rounded, [
                    _buildGridRow(
                      _buildGridTile(Icons.business_rounded, "Company", profile!.company),
                      _buildGridTile(Icons.account_tree_outlined, "Department", profile!.department),
                    ),
                    _buildGridRow(
                      _buildGridTile(Icons.badge_outlined, "Designation", profile!.designation),
                      _buildGridTile(Icons.calendar_month_outlined, "Joined", profile!.dateOfJoining),
                    ),
                    _buildGridRow(
                      _buildGridTile(Icons.assignment_ind_outlined, "Reports To", profile!.reportsTo),
                      _buildGridTile(Icons.assignment_outlined, "Type", profile!.employmentType),
                    ),
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
      backgroundColor: const Color(0xFF1A1A1A),
      leading: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: Colors.white),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Banner color or image
            Container(color: const Color(0xFF1A1A1A)),
            // Profile Info Overlay
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: CircleAvatar(
                        radius: 54,
                        backgroundColor: Colors.white,
                        backgroundImage: provider,
                        child: provider == null 
                            ? Text(
                                _getInitials(profile.employeeName),
                                style: const TextStyle(
                                  color: Color(0xFF1A1A1A),
                                  fontSize: 42,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                              )
                            : null,
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

  String _getInitials(String name) {
    if (name.trim().isEmpty) return 'P';
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
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

  Widget _buildGridSection(String title, IconData titleIcon, List<Widget> children) {
    children = children.where((w) => w is! SizedBox && (w is! Padding || (w.child is! SizedBox))).toList();
    if (children.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade100)),
                child: Icon(titleIcon, size: 18, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 12),
              Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.3)),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildGridRow(Widget child1, [Widget? child2]) {
    final isChild1Empty = child1 is SizedBox;
    final isChild2Empty = child2 == null || child2 is SizedBox;
    if (isChild1Empty && isChild2Empty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: child1),
          const SizedBox(width: 12),
          if (!isChild2Empty) Expanded(child: child2!) else const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
  }

  Widget _buildGridTile(dynamic icon, String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: const Color(0xFF675D40).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: icon is IconData ? Icon(icon, size: 14, color: const Color(0xFF675D40)) : FaIcon(icon, size: 14, color: const Color(0xFF675D40)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600), maxLines: 1)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFullWidthTile(dynamic icon, String label, String? value, {Color? iconColor}) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (iconColor ?? const Color(0xFF675D40)).withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: icon is IconData ? Icon(icon, size: 16, color: iconColor ?? const Color(0xFF675D40)) : FaIcon(icon, size: 16, color: iconColor ?? const Color(0xFF675D40)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}