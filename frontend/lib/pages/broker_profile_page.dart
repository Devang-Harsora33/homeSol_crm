import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:io';
import '../models/profile.dart';
import '../utils.dart';

// --- Design System Constants ---
const Color kPrimaryColor = Color(0xFF675E40); // Olive/Khaki
const Color kScaffoldBg = Color(0xFFF5F5F7); // Light grey
const Color kCardBg = Colors.white;
const Color kTextPrimary = Color(0xFF1A1A1A); // Almost Black
const Color kTextSecondary = Color(0xFF757575); // Grey for labels
const Color kDivider = Color(0xFFEEEEEE);

class BrokerProfilePage extends StatelessWidget {
  final ThemeData theme;
  final Profile? profile;

  const BrokerProfilePage({super.key, required this.theme, this.profile});

  @override
  Widget build(BuildContext context) {
    if (profile == null) {
      return Scaffold(
        backgroundColor: kScaffoldBg,
        appBar: AppBar(
          backgroundColor: kPrimaryColor,
          title: const Text('Profile', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const FaIcon(FontAwesomeIcons.arrowLeft, color: Colors.white, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(FontAwesomeIcons.userSlash, size: 64, color: kTextSecondary),
              SizedBox(height: 16),
              Text('No profile data available', style: TextStyle(color: kTextSecondary)),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: kScaffoldBg,
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
      final fullImageUrl = buildImageUrl(profile.image!);
      if (fullImageUrl.startsWith('http')) {
        provider = NetworkImage(fullImageUrl);
      } else if (File(fullImageUrl).existsSync()) {
        provider = FileImage(File(fullImageUrl));
      }
    }

    return SliverAppBar(
      expandedHeight: 220.0,
      pinned: true,
      stretch: true,
      backgroundColor: kPrimaryColor,
      leading: IconButton(
        icon: const FaIcon(FontAwesomeIcons.chevronLeft, size: 20, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            Container(color: kPrimaryColor),
            
            // Decorative background icon
            Positioned(
              right: -40,
              top: -40,
              child: FaIcon(
                FontAwesomeIcons.solidCircle, 
                size: 300, 
                color: Colors.white.withOpacity(0.05)
              ),
            ),

            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.white,
                    backgroundImage: provider,
                    child: provider == null
                        ? Text(
                            (profile.employeeName.isNotEmpty) ? profile.employeeName[0].toUpperCase() : 'U',
                            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: kPrimaryColor),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  profile.employeeName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    profile.designation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionContainer(String title, List<Widget> children) {
    final visibleChildren = children.where((c) => c is _DetailItem && c.value != null && c.value!.isNotEmpty).toList();
    
    if (visibleChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text(
              title.toUpperCase(),
              style: const TextStyle(
                color: kTextSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
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
  final IconData icon;
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            // Updated to FaIcon for better rendering of FontAwesome glyphs
            child: FaIcon(icon, size: 18, color: kPrimaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: kTextSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value!,
                  style: TextStyle(
                    color: isHighlight ? kPrimaryColor : kTextPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
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