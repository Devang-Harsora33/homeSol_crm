import 'package:Homesol/services/apis/developers/developer_service.dart';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:Homesol/components/cached_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:Homesol/services/auth_service.dart';

import '../models/project.dart';
import '../models/developer.dart';
// import 'add_enquiry_sheet.dart';
import '../utils.dart';
import '../pages/crm/lead_creation_page.dart';
import 'live_inventory_matrix.dart';

class PropertyDetailPopup extends StatefulWidget {
  final Project project;
  final Developer? developer;
  final String? designation;

  const PropertyDetailPopup({
    super.key,
    required this.project,
    this.developer,
    this.designation,
  });

  @override
  State<PropertyDetailPopup> createState() => _PropertyDetailPopupState();
}

class _PropertyDetailPopupState extends State<PropertyDetailPopup> {
  int _currentImageIndex = 0;
  final PageController _imagePageController = PageController();
  String? _currentDesignation;

  @override
  void initState() {
    super.initState();
    _currentDesignation = widget.designation;
    if (_currentDesignation == null) {
      _fetchDesignation();
    }
  }

  Future<void> _fetchDesignation() async {
    final profile = await AuthService.getMyProfile();
    if (profile != null && mounted) {
      setState(() {
        _currentDesignation = profile.designation;
      });
    }
  }

  // --- Theme Constants ---
  static const Color kPrimaryGold = Color(0xFF675D40);
  static const Color kTextBlack = Color(0xFF1A1A1A);
  static const Color kTextGrey = Color(0xFF757575);
  static const Color kSurfaceWhite = Colors.white;
  static const Color kBackground = Color(0xFFF9F9F9);
  static const Color kSystemInfoBg = Color(0xFFF0F0F0); // Matches your screenshot

  // --- Helpers ---
  String _formatPriceRange(int min, int max) {
    if (min == 0 && max == 0) return 'Price on Request';
    final formatter = NumberFormat.compactCurrency(
        locale: 'en_IN', symbol: '₹ ', decimalDigits: 1);
    String minPrice = formatter.format(min * 10000000);
    String maxPrice = formatter.format(max * 10000000);
    if (min == max) return minPrice;
    return '$minPrice - $maxPrice';
  }

  String _formatDateString(String raw) {
    if (raw.isEmpty) return 'N/A';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      return DateFormat('MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _formatSystemDate(String raw) {
    if (raw.isEmpty) return '-';
    try {
      final dt = DateTime.parse(raw);
      // Format: 2026-01-08 13:58:03
      return DateFormat('yyyy-MM-dd HH:mm:ss').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Future<void> _shareProperty(Developer? developer) async {
    final project = widget.project;
    final developerData = developer;

    // 1. Get logged-in user details (for inquiry)
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? userDataString = prefs.getString('user_data');
    Map<String, dynamic>? userData;
    if (userDataString != null) {
      try {
        userData = jsonDecode(userDataString) as Map<String, dynamic>;
      } catch (e) {
        print("Error decoding user data from SharedPreferences: $e");
      }
    }

    // Build the dynamic Google Maps link
    String googleMapsLink = "https://maps.app.goo.gl/"; // Default placeholder
    if (project.location != null && project.location!.isNotEmpty) {
      try {
        final projectLocationJson = jsonDecode(project.location!) as Map<String, dynamic>;
        if (projectLocationJson.containsKey('features') &&
            projectLocationJson['features'] is List &&
            (projectLocationJson['features'] as List).isNotEmpty &&
            (projectLocationJson['features'][0] as Map).containsKey('geometry') &&
            (projectLocationJson['features'][0]['geometry'] as Map).containsKey('coordinates') &&
            (projectLocationJson['features'][0]['geometry']['coordinates'] as List).length >= 2) {
          final coordinates = projectLocationJson['features'][0]['geometry']['coordinates'] as List<dynamic>;
          final longitude = coordinates[0];
          final latitude = coordinates[1];
          googleMapsLink = 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
        }
      } catch (e) {
        print("Error parsing project location for Google Maps link: $e");
      }
    }

    // Start constructing the share text with formatting
    String shareText = "💫_*Nestled in the Heart of ${project.locationDisplay}*_\n\n";

    shareText += "*${project.projectName} By ${project?.developerName ?? 'HomeSol'}*_ Gateway To your Shine & Happiness ✨\n\n";

    // shareText += "✨  *CC RECEIVED*✨ *\n\n";

    shareText += "✨ Spacious & Luxurious ${project.configurations.isNotEmpty ? "${project.configurations.first.name.split(' ')[0]} & ${project.configurations.last.name.split(' ')[0]}" : "1 & 3"} Bedroom Vastu Compliant Apartments.\n\n";

    shareText += "📍 *Project USP:*\n";
    if (project.description.isNotEmpty) {
      shareText += "${stripHtml(project.description)}\n\n";
    } else {
      // Fallback to hardcoded USPs if project.description is empty
      shareText += "- _*Derasar Within the Premises*_ 🛕\n";
      shareText += "- *Floor Height 10th Feet*\n";
      shareText += "- *Ground floor Amenities*\n";
      shareText += "- *Double Heightened Entrance Lobby*\n\n";
    }


    shareText += "📍 *Configuration & Pricing:*\n";
    if (project.configurations.isNotEmpty) {
      for (var config in project.configurations) {
        final price = config.price;
        final formattedPrice = price > 0 ? '${price.toStringAsFixed(2)} Cr** Onwards' : 'Price on Request';
        shareText += "- *${config.name}*\n${config.carpetArea.toInt()} Sq.Ft - $formattedPrice \n\n";
      }
    } else {
      // Fallback if no configurations are found
      shareText += "- *1 Bhk*\n455 Sq.Ft - 1.29 Cr** Onwards \n\n";
      shareText += "- *2 Bhk*\n706 & 773 Sq.Ft - 2Cr** Onwards\n\n";
      shareText += "- *3 Bhk*\n954 Sq.Ft - 2.68 Cr** Onwards\n\n";
    }

    shareText += "*💸 Hassle-Free Flexible Payment Plan💸 📈*\n\n";

    shareText += "📍 *Indulge in a Luxury Lifestyle Curated for you:* 😎\n";
    if (project.amenities.isNotEmpty) {
      for (var amenity in project.amenities) {
        shareText += "- ${stripHtml(amenity.data)}\n";
      }
    } else {
      // Fallback if no amenities are found, using example text
      shareText += "- Fitness Center 🏋‍♀\n";
      shareText += "- Kids Play Area\n";
      shareText += "- Multipurpose Turf 🏏\n";
      shareText += "- Terrace Garden 🏞️\n";
      shareText += "- Senior Citizen Sit-Out Area\n";
      shareText += "- Roof-top Sitting lounge 🛋️\n";
      shareText += "- Jogging & Walking Track 👣\n";
      shareText += "- And More...\n";
    }
    shareText += "\n";

    if (project.reraId.isNotEmpty) {
      shareText += "*RERA NO*\n*${project.reraId}*\n\n";
    }

    shareText += "📍 *Google Map* 🗾\n$googleMapsLink\n\n";

    // Add inquiry details from logged-in user
    if (userData != null) {
      shareText += "Contact For any Inquiry \n";
      final String userName = userData['full_name'] ?? 'HomeSol Agent';
      final String userPhone = (userData['phone_no']?.toString() ?? '').replaceAll(' ', ''); // Ensure phone number is a string and remove spaces
      final String userEmail = userData['email'] ?? '';

      shareText += "*$userName*";
      if (userPhone.isNotEmpty) {
        shareText += " - $userPhone";
      }
      if (userEmail.isNotEmpty) {
        shareText += " / $userEmail";
      }
      shareText += "\n";
    }

    Share.share(shareText);
  }

  Future<void> _openImageViewer({required int initialIndex}) async {
    final images = widget.project.galleryImages;
    if (images.isEmpty) return;
    await showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) => Stack(
        children: [
          PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: images.length,
            itemBuilder: (_, i) => InteractiveViewer(
              child: CachedImage(
                imageUrl: buildImageUrl(images[i].images),
                fit: BoxFit.contain,
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
// --- New Gallery Section Widget ---
  Widget _buildGallerySection() {
    final images = widget.project.galleryImages;
    if (images.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Gallery'),
            Text(
              '${images.length} Photos',
              style: const TextStyle(color: kTextGrey, fontSize: 12),
            ),
          ],
        ),
        SizedBox(
          height: 180, // Height of the gallery strip
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () => _openImageViewer(initialIndex: index),
                child: Container(
                  width: 260, // Width makes them look like "cards"
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    color: kSurfaceWhite,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // The Image
                        CachedImage(
                          imageUrl: buildImageUrl(images[index].images),
                          fit: BoxFit.cover, // Covers the box cleanly
                        ),
                        // A subtle gradient overlay at the bottom for visibility
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.4),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Expand Icon indicator
                        const Positioned(
                          bottom: 8,
                          right: 8,
                          child: Icon(Icons.fullscreen, color: Colors.white, size: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  // Future<void> _showAddEnquirySheet(BuildContext context) async {
  //   final broker = await AuthService.getUserData();
  //   final brokerId = broker?['broker_id']?.toString();
  //   if (brokerId == null) {
  //     if (!mounted) return;
  //     ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('Please log in')));
  //     return;
  //   }
  //   if (!mounted) return;
  //   await AddEnquirySheet.show(
  //     context,
  //     projects: [widget.project],
  //     brokerId: brokerId,
  //     initialSelectedProjectId: widget.project.id,
  //     lockProjectSelection: true,
  //     onCreated: () {},
  //   );
  // }

  Future<void> _launchGoogleMaps() async {
    final projectLocation = widget.project.location;
    if (projectLocation == null || projectLocation.isEmpty) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Location data not available for this project.', isError: false, title: 'Notice');
      return;
    }

    try {
      final projectLocationJson = jsonDecode(projectLocation) as Map<String, dynamic>;
      final coordinates = projectLocationJson['features'][0]['geometry']['coordinates'] as List<dynamic>;
      // GeoJSON stores coordinates as [longitude, latitude]
      final longitude = coordinates[0];
      final latitude = coordinates[1];

      final googleMapsUrl = Uri.parse(
          'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude');

      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        if (!mounted) return;
        CustomSnackBar.show(context, message: 'Could not launch Google Maps.', isError: false, title: 'Notice');
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(context, message: 'Error parsing location data: $e', isError: true, title: 'Error');
    }
  }

  // --- UI Construction ---

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Developer?>(
      future: widget.developer != null
          ? Future.value(widget.developer)
          : DeveloperService.fetchDeveloperById(widget.project.developer),
      builder: (context, snapshot) {
        final developer = snapshot.data;

        return Dialog(
          insetPadding: EdgeInsets.zero,
          backgroundColor: kBackground,
          child: Scaffold(
            backgroundColor: kBackground,
            bottomNavigationBar: (_currentDesignation?.toLowerCase().contains('sourcing') ?? false)
                ? null
                : _buildBottomAction(context),
            body: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                _buildSliverAppBar(developer),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeaderSection(developer),
                        
                        const SizedBox(height: 24),
                        _buildKeyDetailsGrid(),
                        if (widget.project.galleryImages.isNotEmpty) ...[
                           const SizedBox(height: 30),
                           _buildGallerySection(),
                        ],
                        if (widget.project.configurations.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _buildSectionTitle('Configurations'),
                          _buildConfigList(),
                        ],
                        if (widget.project.amenities.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _buildSectionTitle('Amenities'),
                          _buildAmenitiesWrap(),
                        ],
                        if (widget.project.brokerageSlabs.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _buildSectionTitle('Brokerage Slabs'),
                          _buildBrokerageList(),
                        ],
                        if (widget.project.documents.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _buildSectionTitle('Documents'),
                          _buildDocumentsList(),
                        ],
                        if (widget.project.brochures.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _buildSectionTitle('Brochures'),
                          _buildBrochuresList(),
                        ],
                        const SizedBox(height: 30),
                        _buildSectionTitle('Inventory Matrix'),
                        LiveInventoryMatrix(
                          projectId: widget.project.id,
                          designation: _currentDesignation,
                        ),
                        const SizedBox(height: 24),
                        _buildSystemInfoCard(), 
                        const SizedBox(height: 40), // Bottom padding
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // 1. Sliver App Bar (Collapsible Image Header)
  Widget _buildSliverAppBar(Developer? developer) {
    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      backgroundColor: kSurfaceWhite,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.black),
              onPressed: () => _shareProperty(developer),
            ),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            if (widget.project.galleryImages.isNotEmpty)
              PageView.builder(
                controller: _imagePageController,
                onPageChanged: (i) => setState(() => _currentImageIndex = i),
                itemCount: widget.project.galleryImages.length,
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _openImageViewer(initialIndex: i),
                  child: CachedImage(
                    imageUrl: buildImageUrl(widget.project.galleryImages[i].images),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[200],
                child: const Center(child: Icon(Icons.apartment, size: 50, color: Colors.grey)),
              ),
            
            // Image Counter
            if (widget.project.galleryImages.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1} / ${widget.project.galleryImages.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // 2. Main Header Info
  Widget _buildHeaderSection(Developer? developer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (developer != null)
          Text(
            developer.developerName.toUpperCase(),
            style: const TextStyle(
              color: kTextGrey,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        const SizedBox(height: 4),
        Text(
          widget.project.projectName,
          style: const TextStyle(
            color: kTextBlack,
            fontSize: 26,
            fontWeight: FontWeight.w700,
            fontFamily: 'Serif', // Adds that luxury feel
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () {
            _launchGoogleMaps();
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                const Icon(Icons.location_on, color: kPrimaryGold, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    widget.project.locationDisplay,
                    style: const TextStyle(color: kTextBlack, fontSize: 14),
                    maxLines: 2,
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: kTextGrey, size: 14),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _formatPriceRange(widget.project.priceRangeMin, widget.project.priceRangeMax),
          style: const TextStyle(
            color: kPrimaryGold,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  // 3. System Info Card (Matches your Screenshot)
  Widget _buildSystemInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSystemInfoBg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'System Info',
            style: TextStyle(
              color: Color(0xFF666666), // Slightly darker grey for title
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildSystemInfoRow('ID', widget.project.id),
          const SizedBox(height: 8),
          _buildSystemInfoRow('Created', _formatSystemDate(widget.project.creation)),
          const SizedBox(height: 8),
          _buildSystemInfoRow('Last Modified', _formatSystemDate(widget.project.modified)),
        ],
      ),
    );
  }

  Widget _buildSystemInfoRow(String label, String value) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, fontFamily: 'Roboto'),
        children: [
          TextSpan(
            text: '$label: ',
            style: TextStyle(color: Colors.grey[600]),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: Color(0xFF333333), 
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // 4. Key Details Grid
  Widget _buildKeyDetailsGrid() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              _buildGridItem('Status', widget.project.constructionStatus),
              _buildVerticalDivider(),
              _buildGridItem('Type', widget.project.propertyType),
            ],
          ),
          const Divider(height: 30, color: Color(0xFFEEEEEE)),
          Row(
            children: [
              _buildGridItem('Possession', _formatDateString(widget.project.possessionDate)),
              _buildVerticalDivider(),
              _buildGridItem('RERA', widget.project.reraId),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: kTextGrey, fontSize: 11, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(color: kTextBlack, fontSize: 14, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() => Container(height: 30, width: 1, color: const Color(0xFFEEEEEE));

  // 5. Configs, Amenities, etc.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(color: kTextBlack, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildConfigList() {
    return Column(
      children: widget.project.configurations.map((config) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryGold.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.bed_outlined, color: kPrimaryGold, size: 20),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(config.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  Text('${config.carpetArea.toInt()} sq.ft', style: const TextStyle(fontSize: 13, color: kTextGrey)),
                ],
              ),
              const Spacer(),
              Text('${config.price} Cr', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kPrimaryGold)),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAmenitiesWrap() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: widget.project.amenities.map((amenity) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: kSurfaceWhite,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimaryGold.withOpacity(0.3)),
          ),
          child: Text(
            amenity.data,
            style: const TextStyle(color: kPrimaryGold, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBrokerageList() {
    return Column(
      children: widget.project.brokerageSlabs.map((slab) {
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2C),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Bookings', style: TextStyle(color: Colors.grey, fontSize: 10)),
                  Text('${slab.fromBooking} - ${slab.toBooking}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: kPrimaryGold, borderRadius: BorderRadius.circular(8)),
                child: Text('${slab.percentage}% ${slab.incentive > 0 ? '+ ${slab.incentive}' : ''}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentsList() {
    return Column(
      children: widget.project.documents.map((doc) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: kSurfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final url = buildImageUrl(doc.file);
              // Use inAppBrowserView for a better preview experience
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      doc.documentName, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: kTextGrey),
                    onPressed: () {
                       final url = buildImageUrl(doc.file);
                       Share.share('Check out this document for ${widget.project.projectName}: ${doc.documentName}\n\n$url');
                    },
                  ),
                  const Icon(Icons.open_in_new, color: kPrimaryGold, size: 18),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBrochuresList() {
    return Column(
      children: widget.project.brochures.map((brochure) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: kSurfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () async {
              final url = buildImageUrl(brochure.file);
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.inAppBrowserView);
              }
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.menu_book, color: Colors.blue, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      brochure.brochureName, 
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: kTextGrey),
                    onPressed: () {
                       final url = buildImageUrl(brochure.file);
                       Share.share('Check out this brochure for ${widget.project.projectName}: ${brochure.brochureName}\n\n$url');
                    },
                  ),
                  const Icon(Icons.open_in_new, color: kPrimaryGold, size: 18),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => LeadCreationPage(
                  preselectedProjectId: widget.project.id,
                ),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kTextBlack,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          child: const Text('TAG CLIENTS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
        ),
      ),
    );
  }
}