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
import '../models/campaign.dart';
import '../services/apis/leads/lead_service.dart';
// import 'add_enquiry_sheet.dart';
import '../utils.dart';
import '../pages/crm/lead_creation_page.dart';
import 'live_inventory_matrix.dart';
import 'live_parking_matrix.dart';
import 'project_share_bottom_sheet.dart';

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
  List<Campaign> _campaigns = [];
  bool _isFetchingCampaigns = false;

  @override
  void initState() {
    super.initState();
    _currentDesignation = widget.designation;
    if (_currentDesignation == null) {
      _fetchDesignation();
    }
    _fetchCampaigns();
  }

  Future<void> _fetchCampaigns() async {
    if (mounted) setState(() => _isFetchingCampaigns = true);
    try {
      final campaigns = await LeadService.fetchCampaignsByProject(widget.project.id);
      if (mounted) {
        setState(() {
          _campaigns = campaigns;
          _isFetchingCampaigns = false;
        });
      }
    } catch (e) {
      print('Error fetching campaigns in popup: $e');
      if (mounted) setState(() => _isFetchingCampaigns = false);
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
  static const Color kSystemInfoBg = Color(
    0xFFF0F0F0,
  ); // Matches your screenshot

  // --- Helpers ---
  String _formatPriceRange(int min, int max) {
    if (min == 0 && max == 0) return 'Price on Request';
    final formatter = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 1,
    );
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

  void _shareProperty({
    Set<int>? initialDocIndices,
    Set<int>? initialImageIndices,
    Set<int>? initialBrochureIndices,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProjectShareBottomSheet(
        project: widget.project,
        initialSelectedDocIndices: initialDocIndices,
        initialSelectedImageIndices: initialImageIndices,
        initialSelectedBrochureIndices: initialBrochureIndices,
      ),
    );
  }

  Future<void> _openImageViewer({required int initialIndex}) async {
    final images = widget.project.galleryImages;
    if (images.isEmpty) return;

    await showDialog(
      context: context,
      barrierColor: Colors.black,
      builder: (_) {
        final PageController dialogPageController = PageController(initialPage: initialIndex);
        int currentIndex = initialIndex;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return Scaffold(
              backgroundColor: Colors.black,
              body: Stack(
                children: [
                  // Main PageView
                  PageView.builder(
                    controller: dialogPageController,
                    itemCount: images.length,
                    onPageChanged: (index) {
                      setStateDialog(() {
                        currentIndex = index;
                      });
                    },
                    itemBuilder: (_, i) => InteractiveViewer(
                      child: Center(
                        child: CachedImage(
                          imageUrl: buildImageUrl(images[i].images),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),

                  // Close Button
                  Positioned(
                    top: 40,
                    right: 20,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),

                  // Share Button (Refined UI)
                  Positioned(
                    top: 40,
                    left: 20,
                    child: GestureDetector(
                      onTap: () => _shareProperty(initialImageIndices: {currentIndex}),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(52),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                            
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Thumbnails at the bottom
                  Positioned(
                    bottom: 40,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 70,
                      child: Center(
                        child: ListView.builder(
                          shrinkWrap: true,
                          scrollDirection: Axis.horizontal,
                          itemCount: images.length,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemBuilder: (context, index) {
                            final bool isActive = currentIndex == index;
                            return GestureDetector(
                              onTap: () {
                                dialogPageController.animateToPage(
                                  index,
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 60,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive ? kPrimaryGold : Colors.white24,
                                    width: isActive ? 2 : 1,
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: Opacity(
                                    opacity: isActive ? 1.0 : 0.5,
                                    child: CachedImage(
                                      imageUrl: buildImageUrl(images[index].images),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
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
                          child: Icon(
                            Icons.fullscreen,
                            color: Colors.white,
                            size: 20,
                          ),
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
      CustomSnackBar.show(
        context,
        message: 'Location data not available for this project.',
        isError: false,
        title: 'Notice',
      );
      return;
    }

    try {
      final projectLocationJson =
          jsonDecode(projectLocation) as Map<String, dynamic>;
      final coordinates =
          projectLocationJson['features'][0]['geometry']['coordinates']
              as List<dynamic>;
      // GeoJSON stores coordinates as [longitude, latitude]
      final longitude = coordinates[0];
      final latitude = coordinates[1];

      final googleMapsUrl = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
      );

      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        if (!mounted) return;
        CustomSnackBar.show(
          context,
          message: 'Could not launch Google Maps.',
          isError: false,
          title: 'Notice',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CustomSnackBar.show(
        context,
        message: 'Error parsing location data: $e',
        isError: true,
        title: 'Error',
      );
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
            bottomNavigationBar:
                (_currentDesignation?.toLowerCase().contains('sourcing') ??
                    false)
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
                        if (_isFetchingCampaigns) ...[
                          const SizedBox(height: 30),
                          const Center(child: CircularProgressIndicator()),
                        ] else if (_campaigns.isNotEmpty) ...[
                          const SizedBox(height: 30),
                          _buildSectionTitle('Campaigns'),
                          _buildCampaignsList(),
                        ],
                        const SizedBox(height: 30),
                        _buildSectionTitle('Inventory Matrix'),
                        LiveInventoryMatrix(
                          projectId: widget.project.id,
                          designation: _currentDesignation,
                        ),
                        const SizedBox(height: 30),
                        _buildSectionTitle('Parking Matrix'),
                        LiveParkingMatrix(
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
              onPressed: _shareProperty,
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
                    imageUrl: buildImageUrl(
                      widget.project.galleryImages[i].images,
                    ),
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                ),
              )
            else
              Container(
                color: Colors.grey[200],
                child: const Center(
                  child: Icon(Icons.apartment, size: 50, color: Colors.grey),
                ),
              ),

            // Image Counter
            if (widget.project.galleryImages.length > 1)
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentImageIndex + 1} / ${widget.project.galleryImages.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
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
          _formatPriceRange(
            widget.project.priceRangeMin,
            widget.project.priceRangeMax,
          ),
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
          _buildSystemInfoRow(
            'Created',
            _formatSystemDate(widget.project.creation),
          ),
          const SizedBox(height: 8),
          _buildSystemInfoRow(
            'Last Modified',
            _formatSystemDate(widget.project.modified),
          ),
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
              _buildGridItem(
                'Possession',
                _formatDateString(widget.project.possessionDate),
              ),
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
            style: const TextStyle(
              color: kTextGrey,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: kTextBlack,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalDivider() =>
      Container(height: 30, width: 1, color: const Color(0xFFEEEEEE));

  // 5. Configs, Amenities, etc.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: kTextBlack,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
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
                child: const Icon(
                  Icons.bed_outlined,
                  color: kPrimaryGold,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${config.carpetArea.toInt()} sq.ft',
                    style: const TextStyle(fontSize: 13, color: kTextGrey),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                _formatPrice(config.price),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: kPrimaryGold,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _formatPrice(double price) {
    if (price == 0) return 'Price on Request';
    if (price < 10) return '${price.toStringAsFixed(2)} Cr';
    if (price < 10000) return '${(price / 100).toStringAsFixed(2)} Cr';
    return '${(price / 10000000).toStringAsFixed(2)} Cr';
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
            style: const TextStyle(
              color: kPrimaryGold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
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
                  const Text(
                    'Bookings',
                    style: TextStyle(color: Colors.grey, fontSize: 10),
                  ),
                  Text(
                    '${slab.fromBooking} Cr - ${slab.toBooking} Cr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kPrimaryGold,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${slab.percentage}% ${slab.incentive > 0 ? '+ ${slab.incentive}' : ''}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDocumentsList() {
    return Column(
      children: widget.project.documents.asMap().entries.map((entry) {
        final index = entry.key;
        final doc = entry.value;
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
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.inAppBrowserView,
                );
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
                    child: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      doc.documentName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: kTextGrey),
                    onPressed: () => _shareProperty(initialDocIndices: {index}),
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
      children: widget.project.brochures.asMap().entries.map((entry) {
        final index = entry.key;
        final brochure = entry.value;
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
                await launchUrl(
                  Uri.parse(url),
                  mode: LaunchMode.inAppBrowserView,
                );
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
                    child: const Icon(
                      Icons.menu_book,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      brochure.brochureName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share_outlined, color: kTextGrey),
                    onPressed: () => _shareProperty(initialBrochureIndices: {index}),
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

  Widget _buildCampaignsList() {
    return Column(
      children: _campaigns.map((campaign) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kSurfaceWhite,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    campaign.campaignCodeName.isNotEmpty
                        ? campaign.campaignCodeName
                        : campaign.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: kTextBlack,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (campaign.onlineOffline?.toLowerCase() == 'online')
                          ? Colors.green.withOpacity(0.1)
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      campaign.onlineOffline ?? campaign.activeInactive,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: (campaign.onlineOffline?.toLowerCase() == 'online')
                            ? Colors.green
                            : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCampaignDetailItem(
                    Icons.date_range,
                    'Dates',
                    '${_formatCampaignDateString(campaign.startDate)} - ${_formatCampaignDateString(campaign.endDate)}',
                  ),
                  _buildCampaignDetailItem(
                    Icons.people_alt_outlined,
                    'Audience',
                    campaign.targetAudience.isNotEmpty
                        ? campaign.targetAudience
                        : 'N/A',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCampaignDetailItem(
                    Icons.location_on_outlined,
                    'Pincodes',
                    campaign.locationPincodes.isNotEmpty
                        ? (campaign.locationPincodes.split(',').length > 2
                              ? '${campaign.locationPincodes.split(',').take(2).join(',')}...'
                              : campaign.locationPincodes)
                        : 'N/A',
                    onTap: campaign.locationPincodes.isNotEmpty
                        ? () => _showPincodesPopup(
                            context,
                            campaign.locationPincodes,
                          )
                        : null,
                  ),
                  _buildCampaignDetailItem(
                    Icons.leaderboard_outlined,
                    'Leads',
                    '${campaign.leadsGenerated}',
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _showPincodesPopup(BuildContext context, String pincodes) {
    showDialog(
      context: context,
      builder: (context) {
        final pincodeList = pincodes
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        return AlertDialog(
          backgroundColor: kSurfaceWhite,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Target Pincodes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: kTextBlack,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: pincodeList
                  .map(
                    (pin) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: kPrimaryGold.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: kPrimaryGold.withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        pin,
                        style: const TextStyle(
                          color: kPrimaryGold,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Close',
                style: TextStyle(
                  color: kPrimaryGold,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  String _formatCampaignDateString(String raw) {
    if (raw.isEmpty) return 'N/A';
    try {
      final dt = DateTime.tryParse(raw);
      if (dt == null) return raw;
      return DateFormat('dd MMM yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  Widget _buildCampaignDetailItem(IconData icon, String label, String value, {VoidCallback? onTap}) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: kTextGrey),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(fontSize: 11, color: kTextGrey),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 13,
                        color: onTap != null ? kPrimaryGold : kTextBlack,
                        fontWeight: FontWeight.w500,
                        decoration: onTap != null ? TextDecoration.underline : null,
                      ),
                      maxLines: onTap != null ? 1 : null,
                      overflow: onTap != null ? TextOverflow.ellipsis : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomAction(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceWhite,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    LeadCreationPage(preselectedProjectId: widget.project.id),
              ),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: kTextBlack,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 0,
          ),
          child: const Text(
            'TAG CLIENTS',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ),
      ),
    );
  }
}

