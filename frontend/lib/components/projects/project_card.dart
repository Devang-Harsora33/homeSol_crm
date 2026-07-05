import 'dart:async';
import 'package:Homesol/utils/custom_snackbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../components/add_enquiry_sheet.dart';
import '../property_detail_popup.dart';
import '../../models/project.dart';
import '../../models/developer.dart';
import '../../utils.dart';

class ProjectCard extends StatefulWidget {
  final Project project;
  final Developer developer;

  const ProjectCard({
    super.key,
    required this.project,
    required this.developer,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  late final PageController _imageController;
  int _currentImage = 0;
  Timer? _autoTimer;

  Project get project => widget.project;
  Developer get developer => widget.developer;

  @override
  void initState() {
    super.initState();
    _imageController = PageController();
    _startAutoSlide();
  }

  void _startAutoSlide() {
    _autoTimer?.cancel();
    if (widget.project.images.length <= 1) return;
    _autoTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted) return;
      final next = (_currentImage + 1) % widget.project.images.length;
      _imageController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _autoTimer?.cancel();
    _imageController.dispose();
    super.dispose();
  }

  void _shareProject(BuildContext context) {
    final shareText =
        '''
🏢 ${project.projectName}

📍 Location: ${project.location_name}
💰 Price: ${project.priceRange}
📊 Status: ${project.constructionStatus.toUpperCase()}
🏗️ Developer: ${developer.developerName}

${project.amenities.isNotEmpty ? '🏠 Amenities: ${project.amenities.take(5).join(', ')}' : ''}

${project.configurations.isNotEmpty ? '🏘️ Available Configurations:' : ''}
${project.configurations.take(3).map((config) {
        final formattedPrice = config.price == 0 
            ? 'Price on Request' 
            : (config.price < 10 
                ? '${config.price.toStringAsFixed(2)} Cr' 
                : (config.price < 10000 
                    ? '${(config.price / 100).toStringAsFixed(2)} Cr' 
                    : '${(config.price / 10000000).toStringAsFixed(2)} Cr'));
        return '• ${config.name} - ${config.carpetArea.toInt()} sq.ft - $formattedPrice';
      }).join('\n')}

Download HomeSol App to explore more properties and connect with developers!

#HomeSol #RealEstate #PropertyInvestment #${project.location_name.replaceAll(' ', '')}
''';

    Clipboard.setData(ClipboardData(text: shareText));
    final theme = Theme.of(context);
    CustomSnackBar.show(context, message: 'Project details copied to clipboard!', isError: false, title: 'Notice');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final project = widget.project;
    final developer = widget.developer;
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: project.images.isNotEmpty
                      ? PageView.builder(
                          controller: _imageController,
                          onPageChanged: (i) => setState(() {
                            _currentImage = i;
                          }),
                          itemCount: project.images.length,
                          itemBuilder: (context, index) {
                            return Image.network(
                              buildImageUrl(project.images[index].images),
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: isDark
                                      ? const Color(0xFF2A3038)
                                      : Colors.grey.shade300,
                                  child: const Center(
                                    child: Text(
                                      '🏢',
                                      style: TextStyle(fontSize: 120),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        )
                      : Container(
                          color: isDark
                              ? const Color(0xFF2A3038)
                              : Colors.grey.shade300,
                          child: const Center(
                            child: Text('🏢', style: TextStyle(fontSize: 120)),
                          ),
                        ),
                ),

                if (project.constructionStatus == 'active')
                  Positioned(
                    top: 60,
                    left: 20,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.black : Colors.white)
                            .withOpacity(0.6),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Active',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                if (project.images.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(project.images.length, (index) {
                        final active = index == _currentImage;
                        return AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: active ? 10 : 8,
                          height: 8,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: active
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.white : Colors.black)
                                      .withOpacity(0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        );
                      }),
                    ),
                  ),
              ],
            ),
          ),

          Expanded(
            flex: 5,
            child: Container(
              color: theme.scaffoldBackgroundColor,
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.asset(
                            'assets/logo/logo.png',
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container();
                            },
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            developer.developerName,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            developer.username.toUpperCase(),
                            style: TextStyle(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Flexible(
                        flex: 0,
                        child: Text(
                          project.projectName,
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Material(
                        color: null,
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              barrierColor: Colors.black.withOpacity(0.5),
                              builder: (_) => PropertyDetailPopup(
                                project: project,
                                developer: developer,
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(18),
                          child: Ink(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? [
                                        const Color(0xFF2B2F36),
                                        const Color(0xFF1E2127),
                                      ]
                                    : [
                                        Colors.white,
                                        const Color.fromARGB(0, 247, 247, 249),
                                      ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: Border.all(
                                color: (isDark ? Colors.white : Colors.black)
                                    .withOpacity(0.12),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 8),
                                Text(
                                  'View more',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : Colors.black,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 18,
                                  color: isDark
                                      ? Colors.white
                                      : Colors.black.withOpacity(0.7),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    project.location_name,
                    style: TextStyle(
                      color: (isDark ? Colors.white : Colors.black).withOpacity(
                        0.9,
                      ),
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Removed explicit price range display per requirement
                  const SizedBox.shrink(),
                  // const SizedBox(height: 16),
                  // Amenities chips
                  if (project.amenities.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: project.amenities
                          .take(6)
                          .map<Widget>(
                            (amenity) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFdbc163,
                                ).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(
                                    0xFFdbc163,
                                  ).withOpacity(0.4),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                amenity.data,
                                style: TextStyle(
                                  color: const Color(0xFF8a6d00),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Configuration chips (show 2BHK, 3BHK, 4BHK with area and price)
                  if (project.configurations.isNotEmpty) ...[
                    (() {
                      final allowed = {'2BHK', '3BHK', '4BHK'};
                      final presentTypes = project.configurations
                          .map((c) {
                            final digits = RegExp(
                              r'^[0-9]+',
                            ).stringMatch(c.name);
                            return digits != null ? '${digits}BHK' : null;
                          })
                          .where((t) => t != null && allowed.contains(t))
                          .cast<String>()
                          .toSet();
                      final ordered = [
                        '2BHK',
                        '3BHK',
                        '4BHK',
                      ].where((t) => presentTypes.contains(t)).toList();
                      if (ordered.isEmpty) return const SizedBox.shrink();
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: ordered.map<Widget>((t) {
                          // find first configuration matching this type's digits
                          final digits =
                              RegExp(r'^[0-9]+').stringMatch(t) ?? '';
                          final cfg = project.configurations.firstWhere(
                            (c) => RegExp(r'^' + digits).hasMatch(c.name),
                            orElse: () => project.configurations.first,
                          );
                          final formattedPrice = cfg.price == 0 
                              ? 'Request' 
                              : (cfg.price < 10 
                                  ? '${cfg.price.toStringAsFixed(2)} Cr' 
                                  : (cfg.price < 10000 
                                      ? '${(cfg.price / 100).toStringAsFixed(2)} Cr' 
                                      : '${(cfg.price / 10000000).toStringAsFixed(2)} Cr'));
                          final label = '${t} • ${cfg.carpetArea.toInt()} • $formattedPrice';
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black87,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    })(),
                    const SizedBox(height: 20),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white : Colors.black,
                              borderRadius: BorderRadius.circular(25),
                            ),
                            child: Center(
                              child: Text(
                                'Tag Interested Clients',
                                style: TextStyle(
                                  color: isDark ? Colors.black : Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          onTap: () async {
                            final userData = await AuthService.getUserData();
                            final brokerId =
                                userData != null &&
                                    userData['broker_id'] != null
                                ? userData['broker_id'].toString()
                                : null;
                            AddEnquirySheet.show(
                              context,
                              projects: [project],
                              brokerId: brokerId,
                              initialSelectedProjectId: project.id,
                              lockProjectSelection: true,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => _shareProject(context),
                        child: Container(
                          height: 50,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            color: theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isDark ? Colors.white : Colors.black,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.share,
                                color: isDark ? Colors.white : Colors.black,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Share',
                                style: TextStyle(
                                  color: isDark ? Colors.white : Colors.black,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
