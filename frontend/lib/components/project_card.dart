import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'property_detail_popup.dart';
import '../models/project.dart';
import '../models/developer.dart';
import '../utils.dart'; // Assuming buildImageUrl is here

class HomeProjectCard extends StatelessWidget {
  final Project project;
  final Developer developer;

  // Theme Constants
  static const Color kPrimaryGold = Color(0xFF675D40);
  static const Color kTextBlack = Color(0xFF1A1A1A);
  static const Color kTextGrey = Color(0xFF757575);
  static const Color kSurfaceWhite = Colors.white;

  const HomeProjectCard({
    super.key,
    required this.project,
    required this.developer,
  });

  String _formatPriceRange(int min, int max) {
    if (min == 0 && max == 0) return 'Price on Request';
    final NumberFormat formatter = NumberFormat.compactCurrency(
      locale: 'en_IN',
      symbol: '₹ ',
      decimalDigits: 1,
    );
    // Assuming input is in Crores based on your previous code logic
    String minPrice = formatter.format(min * 10000000);
    String maxPrice = formatter.format(max * 10000000);
    return '$minPrice - $maxPrice';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (_) => PropertyDetailPopup(
            project: project,
            developer: developer,
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: kSurfaceWhite,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImageSection(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(),
                  const SizedBox(height: 12),
                  _buildLocationRow(),
                  const SizedBox(height: 16),
                  _buildSpecsRow(),
                  const SizedBox(height: 16),
                  const Divider(height: 1, color: Color(0xFFEEEEEE)),
                  const SizedBox(height: 12),
                  _buildFooterSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSection() {
    return Stack(
      children: [
        // 1. The Image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: AspectRatio(
            aspectRatio: 16 / 10,
            child: project.galleryImages.isNotEmpty
                ? Image.network(
                    buildImageUrl(project.galleryImages.first.images),
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceholderImage(),
                  )
                : _buildPlaceholderImage(),
          ),
        ),
        
        // 2. Gradient Overlay (for text readability if needed, kept subtle here)
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.0),
                  Colors.black.withOpacity(0.1),
                ],
              ),
            ),
          ),
        ),

        // 3. Status Badge (Floating top left)
        Positioned(
          top: 16,
          left: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: kPrimaryGold,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              project.constructionStatus.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        
        // 4. Property Type Badge (Floating top right)
        Positioned(
          top: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.business, size: 14, color: kTextBlack),
                const SizedBox(width: 4),
                Text(
                  project.propertyType,
                  style: const TextStyle(
                    color: kTextBlack,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholderImage() {
    return Container(
      color: const Color(0xFFF5F5F5),
      child: Center(
        child: Icon(
          Icons.apartment_rounded,
          size: 48,
          color: kPrimaryGold.withOpacity(0.3),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Project Name
        Text(
          project.projectName,
          style: const TextStyle(
            color: kTextBlack,
            fontSize: 20,
            fontWeight: FontWeight.w700,
            fontFamily: 'Serif', // Adds a premium touch
            height: 1.2,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        // Price
        Text(
          _formatPriceRange(project.priceRangeMin, project.priceRangeMax),
          style: const TextStyle(
            color: kPrimaryGold,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildLocationRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.location_on_outlined, color: kTextGrey, size: 16),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            project.locationDisplay,
            style: const TextStyle(
              color: kTextGrey,
              fontSize: 13,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildSpecsRow() {
    // Generate config string (e.g., "2, 3 BHK")
    String configText = "N/A";
    if (project.configurations.isNotEmpty) {
      final names = project.configurations
          .map((e) => e.name.replaceAll(RegExp(r'\D'), '')) // Extract numbers
          .toSet()
          .join(', ');
      configText = "$names BHK";
    }

    // Get Min Area
    String areaText = "N/A";
    if (project.configurations.isNotEmpty) {
       // Sort to find smallest area
       final areas = project.configurations.map((e) => e.carpetArea).toList();
       areas.sort();
       areaText = "${areas.first.toInt()} Sq.ft";
    }

    return Row(
      children: [
        _buildSpecItem(Icons.bed_outlined, configText),
        Container(
          height: 24,
          width: 1, 
          color: Colors.grey[300], 
          margin: const EdgeInsets.symmetric(horizontal: 16)
        ),
        _buildSpecItem(Icons.square_foot, areaText),
        Container(
          height: 24,
          width: 1, 
          color: Colors.grey[300], 
          margin: const EdgeInsets.symmetric(horizontal: 16)
        ),
        _buildSpecItem(Icons.calendar_today_outlined, _getShortPossessionDate()),
      ],
    );
  }

  String _getShortPossessionDate() {
    if (project.targetPossession.isEmpty) return "Soon";
    try {
      final date = DateTime.parse(project.targetPossession);
      return DateFormat('MMM yyyy').format(date);
    } catch (e) {
      return "N/A";
    }
  }

  Widget _buildSpecItem(IconData icon, String text) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kPrimaryGold),
          const SizedBox(height: 4),
          Text(
            text,
            style: const TextStyle(
              color: kTextBlack,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFooterSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: kTextBlack.withOpacity(0.05),
                child: Text(
                  developer.developerName.isNotEmpty 
                      ? developer.developerName[0].toUpperCase() 
                      : "D",
                  style: const TextStyle(
                    fontSize: 10, 
                    color: kTextBlack, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  developer.developerName,
                  style: const TextStyle(
                    color: kTextBlack,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (project.reraId.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: const Text(
              "RERA Registered",
              style: TextStyle(
                fontSize: 10,
                color: kTextGrey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }
}

class HomeProjectCardSkeleton extends StatelessWidget {
  const HomeProjectCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color? skeletonColor = isDark ? Colors.grey[800] : Colors.grey[300];
    Color? highlightColor = isDark ? Colors.grey[700] : Colors.grey[200];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Section Skeleton
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Container(color: skeletonColor),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Section Skeleton (Project Name & Price)
                Container(
                  width: double.infinity,
                  height: 20,
                  color: skeletonColor,
                ),
                const SizedBox(height: 6),
                Container(
                  width: 120,
                  height: 18,
                  color: skeletonColor,
                ),
                const SizedBox(height: 12),
                // Location Row Skeleton
                Row(
                  children: [
                    Container(width: 16, height: 16, color: skeletonColor),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Container(
                        height: 13,
                        color: skeletonColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Specs Row Skeleton
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 18, height: 18, color: skeletonColor),
                          const SizedBox(height: 4),
                          Container(width: 60, height: 12, color: skeletonColor),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 18, height: 18, color: skeletonColor),
                          const SizedBox(height: 4),
                          Container(width: 80, height: 12, color: skeletonColor),
                        ],
                      ),
                    ),
                    Container(
                      height: 24,
                      width: 1,
                      color: Colors.grey[300],
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(width: 18, height: 18, color: skeletonColor),
                          const SizedBox(height: 4),
                          Container(width: 70, height: 12, color: skeletonColor),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFEEEEEE)),
                const SizedBox(height: 12),
                // Footer Section Skeleton
                Row(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: skeletonColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 12,
                        color: skeletonColor,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Container(
                      width: 100,
                      height: 20,
                      color: skeletonColor,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}