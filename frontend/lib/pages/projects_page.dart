import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/project.dart';
import '../components/projects/project_card.dart';
import '../components/projects/filters/status_filter.dart';
import '../components/projects/filters/amenities_filter.dart';
import '../components/projects/filters/bedrooms_filter.dart';
import '../components/projects/filters/location_range_filter.dart';
import '../components/projects/filters/developer_filter.dart';
import '../components/add_enquiry_sheet.dart';
import '../models/developer.dart';
import '../services/api_service.dart';
import '../services/location_service.dart';
import '../services/auth_service.dart';

class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});

  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  // API data
  List<Project> _projects = [];
  List<Developer> _developers = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _selectedLocation;

  // Location service
  final LocationService _locationService = LocationService.instance;

  // Filters state
  double? _priceMinCr; // in Crores
  double? _priceMaxCr; // in Crores
  double? _areaMinSqft;
  double? _areaMaxSqft;
  final Set<int> _selectedBedrooms = <int>{};
  final Set<String> _selectedAmenities = <String>{};
  final Set<String> _selectedDevelopers = <String>{};
  final Set<String> _selectedDeveloperIds = <String>{};
  final Set<String> _selectedRoads = <String>{};
  final Set<String> _selectedStatuses = <String>{};
  double? _selectedLocationRange; // in kilometers

  // Local queries for searchable filter sections
  String _amenitiesQuery = '';
  String _developerQuery = '';

  // Global bounds computed from data
  double _globalPriceMinCr = 0;
  double _globalPriceMaxCr = 0;
  double _globalAreaMinSqft = 0;
  double _globalAreaMaxSqft = 0;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (!mounted) return;
    setState(() {
    });

    try {
      await _locationService.getCurrentLocation();
      if (!mounted) return;
      if (_locationService.currentPosition == null) {
        
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
      });
    } finally {
      if (mounted) {
        setState(() {
        });
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchData({bool forceRefresh = false}) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      print('Fetching projects data...');
      final projectsFuture = ApiService.fetchProjects(forceRefresh: forceRefresh);
      final developersFuture = ApiService.fetchDevelopers(forceRefresh: forceRefresh);

      final results = await Future.wait([projectsFuture, developersFuture]);

      print('Projects fetched: ${results[0].length}');
      print('Developers fetched: ${results[1].length}');

      setState(() {
        _projects = results[0] as List<Project>;
        _developers = results[1] as List<Developer>;
        _isLoading = false;
      });

      _computeGlobalFilterBounds();
    } catch (e) {
      print('Error fetching projects data: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  void _openFiltersSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Ensure bounds are computed
    _computeGlobalFilterBounds();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      transitionAnimationController: AnimationController(
        duration: const Duration(milliseconds: 300),
        vsync: Navigator.of(context),
      ),
      builder: (context) {
        // Sidebar categories
        final categories = <String>[
          'Price/Size',
          'Location',
          'Bedrooms',
          // 'Roads',
          'Status',
          'Amenities',
          'Developer',
        ];
        final Map<String, IconData> categoryIcons = {
          'Price/Size': Icons.account_balance_wallet,
          'Location': Icons.location_on,
          'Bedrooms': Icons.bed,
          // 'Roads': Icons.route,
          'Status': Icons.home,
          'Amenities': Icons.apartment,
          'Developer': Icons.business,
        };
        String current = categories.first;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget body;
            if (current == 'Price/Size') {
              body = _priceSizeContent(theme, isDark, setSheetState);
            } else if (current == 'Location') {
              body = LocationRangeFilter(
                isDark: isDark,
                options: const [2.0, 5.0, 10.0, 15.0, 25.0, 50.0],
                selectedRange: _selectedLocationRange,
                onChange: (v) =>
                    setSheetState(() => _selectedLocationRange = v),
              );
            } else if (current == 'Bedrooms') {
              body = BedroomsFilter(
                isDark: isDark,
                options: const [1, 2, 3, 4, 5],
                selectedBedrooms: _selectedBedrooms,
                setSheetState: setSheetState,
              );
            } else if (current == 'Status') {
              body = StatusFilter(
                isDark: isDark,
                selectedStatuses: _selectedStatuses,
                options: const [
                  'Active',
                  'Under Construction',
                  'Completed',
                  'Planning',
                ],
                setSheetState: setSheetState,
              );
            } else if (current == 'Amenities') {
              body = AmenitiesFilter(
                isDark: isDark,
                amenities:
                    (_projects.expand((p) => p.amenities.map((a) => a.data)).toSet().toList()
                      ..sort()),
                selectedAmenities: _selectedAmenities,
                query: _amenitiesQuery,
                onQueryChanged: (v) => setSheetState(() => _amenitiesQuery = v),
                setSheetState: setSheetState,
              );
            } else {
              final devs =
                  _developers.where((d) => d.developerName.isNotEmpty).toList()
                    ..sort(
                      (a, b) => a.developerName.compareTo(b.developerName),
                    );
              body = DeveloperFilter(
                isDark: isDark,
                developers: devs,
                selectedDeveloperIds: _selectedDeveloperIds,
                selectedDeveloperNames: _selectedDevelopers,
                query: _developerQuery,
                onQueryChanged: (v) => setSheetState(() => _developerQuery = v),
                setSheetState: setSheetState,
              );
            }
            return Container(
              height: MediaQuery.of(context).size.height * 0.9,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 20, 24, 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 24),
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Icon(
                                  Icons.close,
                                  color: Colors.grey.shade700,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Filters',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedLocation = null;
                              _selectedLocationRange = null;
                              _priceMinCr = _globalPriceMinCr;
                              _priceMaxCr = _globalPriceMaxCr;
                              _areaMinSqft = _globalAreaMinSqft;
                              _areaMaxSqft = _globalAreaMaxSqft;
                              _selectedBedrooms.clear();
                              _selectedAmenities.clear();
                              _selectedDevelopers.clear();
                              _selectedDeveloperIds.clear();
                              _selectedRoads.clear();
                              _selectedStatuses.clear();
                            });
                            setSheetState(() {});
                          },
                          child: Text(
                            'Reset All',
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Container(
                    height: 1,
                    color: Colors.grey.shade200,
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                  ),
                  // Main content
                  Expanded(
                    child: Row(
                      children: [
                        // Sidebar
                        Container(
                          width: 180,
                          margin: const EdgeInsets.only(right: 3, left: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.grey.shade300,
                              width: 1,
                            ),
                          ),
                          child: ListView.builder(
                            itemCount: categories.length,
                            itemBuilder: (context, index) {
                              final category = categories[index];
                              final selected = category == current;
                              return Container(
                                margin: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(
                                          0xFFdbc163,
                                        ).withOpacity(0.15)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  leading: Icon(
                                    categoryIcons[category],
                                    size: 20,
                                    color: selected
                                        ? const Color(0xFFdbc163)
                                        : Colors.grey.shade600,
                                  ),
                                  title: Text(
                                    category,
                                    style: TextStyle(
                                      color: selected
                                          ? const Color(0xFFdbc163)
                                          : Colors.grey.shade700,
                                      fontWeight: selected
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  trailing: Icon(
                                    Icons.arrow_forward_ios,
                                    size: 14,
                                    color: selected
                                        ? const Color(0xFFdbc163)
                                        : Colors.grey.shade500,
                                  ),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    setSheetState(() => current = category);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                        // Content area
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: body,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Filter Summary
                  _buildFilterSummary(theme, isDark),
                  // Apply button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {});
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                        ),
                        child: Text(
                          'Apply',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
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

  List<Project> get _visibleProjects {
    Iterable<Project> list = _projects;
    if (_selectedLocation != null && _selectedLocation!.isNotEmpty) {
      final loc = _selectedLocation!.trim().toLowerCase();
      list = list.where(
        (p) => p.location?.trim().toLowerCase().contains(loc) ?? false,
      );
    }
    return list.where(_matchesFilters).toList();
  }

  void _openLocationSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Set<String> areas = _projects
        .map((p) => _extractAreaFromAddress(p.location ?? ''))
        .where((l) => l.isNotEmpty)
        .toSet();
    final List<String> options = ['All Locations'] + (areas.toList()..sort());
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Location',
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
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final opt = options[index];
                    final selected =
                        (_selectedLocation ?? 'All Locations') == opt;
                    return ListTile(
                      title: Text(
                        opt,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: selected
                          ? Icon(Icons.check, color: theme.colorScheme.primary)
                          : null,
                      onTap: () {
                        setState(() {
                          _selectedLocation = (opt == 'All Locations')
                              ? null
                              : opt;
                          _currentIndex = 0;
                        });
                        if (_visibleProjects.isNotEmpty) {
                          _pageController.jumpToPage(0);
                        }
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Extract a concise area/locality from a full address
  String _extractAreaFromAddress(String address) {
    if (address.isEmpty) return '';
    final firstPart = address.split(',').first.trim();
    // Normalize to title-case words without extra spaces
    if (firstPart.isEmpty) return '';
    return firstPart;
  }

  void _computeGlobalFilterBounds() {
    double minPrice = double.infinity;
    double maxPrice = 0;
    double minArea = double.infinity;
    double maxArea = 0;

    for (final project in _projects) {
      // Price range, example: "2.5Cr- 5Cr" or "2Cr-5Cr"
      final prices = _parsePriceRangeToCr(project.priceRange);
      if (prices != null) {
        final left = prices.$1;
        final right = prices.$2;
        minPrice = left < minPrice ? left : minPrice;
        maxPrice = right > maxPrice ? right : maxPrice;
      }

      for (final conf in project.configurations) {
        final a = _parseAreaSqft(conf.carpetArea.toString());
        if (a != null) {
          if (a < minArea) minArea = a;
          if (a > maxArea) maxArea = a;
        }
      }
    }

    if (minPrice == double.infinity) minPrice = 0;
    if (minArea == double.infinity) minArea = 0;

    _globalPriceMinCr = minPrice;
    _globalPriceMaxCr = maxPrice;
    _globalAreaMinSqft = minArea;
    _globalAreaMaxSqft = maxArea;

    _priceMinCr ??= _globalPriceMinCr;
    _priceMaxCr ??= _globalPriceMaxCr;
    _areaMinSqft ??= _globalAreaMinSqft;
    _areaMaxSqft ??= _globalAreaMaxSqft;
  }

  // Returns tuple (minCr, maxCr)
  (double, double)? _parsePriceRangeToCr(String input) {
    if (input.isEmpty) return null;
    final parts = input.split('-');
    if (parts.length != 2) return null;
    final left = _parseSinglePriceToCr(parts[0]);
    final right = _parseSinglePriceToCr(parts[1]);
    if (left == null || right == null) return null;
    return (left, right);
  }

  double? _parseSinglePriceToCr(String s) {
    var t = s.replaceAll(',', '').trim().toLowerCase();
    // Normalize spacing like '5cr' or '5 cr'
    if (t.endsWith('cr')) {
      t = t.replaceAll('cr', '').trim();
      final v = double.tryParse(t);
      return v;
    }
    if (t.endsWith('l')) {
      t = t.replaceAll('l', '').trim();
      final v = double.tryParse(t);
      return v == null ? null : v / 100; // 100L = 1Cr
    }
    final v = double.tryParse(t);
    return v; // Assume already in Cr
  }

  double? _parseAreaSqft(String s) {
    // "800 sq ft" -> 800
    final digits = RegExp(
      r'[0-9]+',
    ).allMatches(s).map((m) => m.group(0)).join();
    if (digits.isEmpty) return null;
    return double.tryParse(digits);
  }

  bool _matchesFilters(Project p) {
    // Price range check
    final range = _parsePriceRangeToCr(p.priceRange);
    if (range != null) {
      final projectMin = range.$1;
      final projectMax = range.$2;
      if (_priceMinCr != null && projectMax < _priceMinCr!) return false;
      if (_priceMaxCr != null && projectMin > _priceMaxCr!) return false;
    }

    // Area across configurations
    double? minArea;
    double? maxArea;
    for (final conf in p.configurations) {
      final a = _parseAreaSqft(conf.carpetArea.toString());
      if (a == null) continue;
      minArea = (minArea == null || a < minArea) ? a : minArea;
      maxArea = (maxArea == null || a > maxArea) ? a : maxArea;
    }
    if (minArea != null && _areaMaxSqft != null && minArea > _areaMaxSqft!) {
      return false;
    }
    if (maxArea != null && _areaMinSqft != null && maxArea < _areaMinSqft!) {
      return false;
    }

    // Bedrooms filter from configuration types like '2BHK'
    if (_selectedBedrooms.isNotEmpty) {
      final hasMatch = p.configurations.any((c) {
        final digits = RegExp(r'^[0-9]+').stringMatch(c.name);
        final beds = int.tryParse(digits ?? '');
        return beds != null && _selectedBedrooms.contains(beds);
      });
      if (!hasMatch) return false;
    }

    // Amenities (all must be present)
    if (_selectedAmenities.isNotEmpty) {
      for (final a in _selectedAmenities) {
        if (!p.amenities
            .map((e) => e.data.toLowerCase())
            .contains(a.toLowerCase())) {
          return false;
        }
      }
    }

    // Developers
    if (_selectedDeveloperIds.isNotEmpty) {
      if (!_selectedDeveloperIds.contains(p.developerId)) return false;
    }

    // Roads (basic implementation - you can enhance this based on your data structure)
    if (_selectedRoads.isNotEmpty) {
      // This is a placeholder - you might need to add road information to your Project model
      // For now, we'll skip this filter
    }

    // Status
    if (_selectedStatuses.isNotEmpty) {
      if (!_selectedStatuses.contains(p.constructionStatus)) return false;
    }

    // Location Range (if coordinates are available)
    if (_selectedLocationRange != null &&
        _locationService.currentPosition != null) {
      final projectCoords = _getProjectCoordinates(p);
      if (projectCoords != null) {
        final distance = _locationService.calculateDistanceFromCurrent(
          projectCoords.$1,
          projectCoords.$2,
        );
        if (distance == null || distance > _selectedLocationRange!) {
          return false;
        }
      }
    }

    return true;
  }

  Widget _priceSizeContent(
    ThemeData theme,
    bool isDark,
    void Function(void Function()) setSheetState,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'Price/Size',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Min - Price
          Text(
            'Min - Price',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatCr(_priceMinCr ?? _globalPriceMinCr)} Cr',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_priceMinCr ?? _globalPriceMinCr).clamp(
                _globalPriceMinCr,
                _globalPriceMaxCr,
              ),
              min: _globalPriceMinCr,
              max: _globalPriceMaxCr,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                setSheetState(() => _priceMinCr = v);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Max - Price
          Text(
            'Max - Price',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '₹${_formatCr(_priceMaxCr ?? _globalPriceMaxCr)} Cr',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_priceMaxCr ?? _globalPriceMaxCr).clamp(
                _globalPriceMinCr,
                _globalPriceMaxCr,
              ),
              min: _globalPriceMinCr,
              max: _globalPriceMaxCr,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                setSheetState(() => _priceMaxCr = v);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Min - Size
          Text(
            'Min - Size',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_areaMinSqft ?? _globalAreaMinSqft).toStringAsFixed(0)} (sq. ft.)',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_areaMinSqft ?? _globalAreaMinSqft).clamp(
                _globalAreaMinSqft,
                _globalAreaMaxSqft,
              ),
              min: _globalAreaMinSqft,
              max: _globalAreaMaxSqft,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                setSheetState(() => _areaMinSqft = v);
              },
            ),
          ),

          const SizedBox(height: 24),

          // Max - Size
          Text(
            'Max - Size',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${(_areaMaxSqft ?? _globalAreaMaxSqft).toStringAsFixed(0)} (sq. ft.)',
            style: TextStyle(
              color: Colors.grey.shade800,
              fontSize: 16,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: theme.colorScheme.primary.withOpacity(0.6),
              inactiveTrackColor: Colors.grey.shade200,
              thumbColor: theme.colorScheme.primary,
              overlayColor: Colors.grey.shade200.withOpacity(0.2),
              trackHeight: 4,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: (_areaMaxSqft ?? _globalAreaMaxSqft).clamp(
                _globalAreaMinSqft,
                _globalAreaMaxSqft,
              ),
              min: _globalAreaMinSqft,
              max: _globalAreaMaxSqft,
              onChanged: (v) {
                HapticFeedback.lightImpact();
                setSheetState(() => _areaMaxSqft = v);
              },
            ),
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // moved to component LocationRangeFilter

  // moved to component BedroomsFilter

  // moved to component StatusFilter

  // moved to component AmenitiesFilter

  // moved to component DeveloperFilter

  String _formatCr(double value) {
    if (value >= 1) {
      return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
    }
    // show as L if below 1Cr for clarity
    return (value * 100).toStringAsFixed(0);
  }

  // Get project coordinates from project's location_coordinates
  (double, double)? _getProjectCoordinates(Project project) {
    // Return project's coordinates if available
    if (project.locationCoordinates != null) {
      return (
        project.locationCoordinates!.latitude,
        project.locationCoordinates!.longitude,
      );
    }

    // Fallback: try developer's coordinates
    final developer = _developers.firstWhere(
      (dev) => dev.id == project.developerId,
      orElse: () => Developer(
        id: '',
        createdAt: '',
        updatedAt: '',
        username: 'Unknown',
        email: '',
        developerName: 'Unknown Developer',
        reraNumber: '',
        gstNumber: '',
        panNumber: '',
        officeAddress: '',
        contactPerson: '',
        contactEmail: '',
        contactPhone: '',
        companySize: '',
        specializations: [],
        certifications: [],
        bankDetails: BankDetails(accountNumber: '', ifscCode: '', bankName: ''),
        kycStatus: '',
        isVerified: false,
        isActive: false,
        websiteUrl: '',
        logoUrl: '',
        companyDescription: '',
        yearEstablished: 0,
        totalProjectsCompleted: 0,
        currentProjectsCount: 0,
        stories: [],
        projectsList: [],
      ),
    );

    // Return developer's coordinates if available
    if (developer.locationCoordinates != null) {
      return (
        developer.locationCoordinates!.latitude,
        developer.locationCoordinates!.longitude,
      );
    }

    // Final fallback: simulate coordinates
    final hash = (project.projectName + project.locationDisplay).hashCode.abs();
    final lat = 19.0760 + (hash % 1000) / 10000.0; // Mumbai area ±0.1 degrees
    final lon = 72.8777 + (hash % 1000) / 10000.0; // Mumbai area ±0.1 degrees
    return (lat, lon);
  }

  void _shareCurrentProject() {
    if (_visibleProjects.isEmpty) return;

    final project = _visibleProjects[_currentIndex];
    final developer = _developers.firstWhere(
      (dev) => dev.id == project.developerId,
      orElse: () => Developer(
        id: '',
        createdAt: '',
        updatedAt: '',
        username: 'Unknown',
        email: '',
        developerName: 'Unknown Developer',
        reraNumber: '',
        gstNumber: '',
        panNumber: '',
        officeAddress: '',
        contactPerson: '',
        contactEmail: '',
        contactPhone: '',
        companySize: '',
        specializations: [],
        certifications: [],
        bankDetails: BankDetails(accountNumber: '', ifscCode: '', bankName: ''),
        kycStatus: '',
        isVerified: false,
        isActive: false,
        websiteUrl: '',
        logoUrl: '',
        companyDescription: '',
        yearEstablished: 0,
        totalProjectsCompleted: 0,
        currentProjectsCount: 0,
        stories: [],
        projectsList: [],
      ),
    );

    final shareText =
        '''
  🏢 ${project.projectName}

  📍 Location: ${project.locationDisplay}
  💰 Price: ${project.priceRange}
  📊 Status: ${project.constructionStatus.toUpperCase()}
  🏗️ Developer: ${developer.developerName}

  ${project.amenities.isNotEmpty ? '🏠 Amenities: ${project.amenities.take(5).join(', ')}' : ''}

  ${project.configurations.isNotEmpty ? '🏘️ Available Configurations:' : ''}
  ${project.configurations.take(3).map((config) => '• ${config.name} - ${config.carpetArea} - ${config.price}').join('\n')}

  ${project.campaigns.isNotEmpty ? '🔥 Special Offers Available!' : ''}

  Download HomeSol App to explore more properties and connect with developers!

  #HomeSol #RealEstate #PropertyInvestment #${project.locationDisplay.replaceAll(' ', '')}
  ''';

    // Copy to clipboard and show message
    Clipboard.setData(ClipboardData(text: shareText));
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Project details copied to clipboard!'),
        backgroundColor: theme.colorScheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'Share',
          textColor: Colors.white,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: shareText));
          },
        ),
      ),
    );
  }

  bool _hasActiveFilters() {
    // Check if any filters are applied
    return _selectedLocation != null ||
        _selectedLocationRange != null ||
        _priceMinCr != null && _priceMinCr != _globalPriceMinCr ||
        _priceMaxCr != null && _priceMaxCr != _globalPriceMaxCr ||
        _areaMinSqft != null && _areaMinSqft != _globalAreaMinSqft ||
        _areaMaxSqft != null && _areaMaxSqft != _globalAreaMaxSqft ||
        _selectedBedrooms.isNotEmpty ||
        _selectedAmenities.isNotEmpty ||
        _selectedDeveloperIds.isNotEmpty ||
        _selectedRoads.isNotEmpty ||
        _selectedStatuses.isNotEmpty;
  }

  Widget _buildTagAllProjectsButton(ThemeData theme) {
    // Only show if there are filtered projects and filters are applied
    if (_visibleProjects.isEmpty ||
        _visibleProjects.length == _projects.length) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () async {
            try {
              final broker = await AuthService.getUserData();
              final brokerId = broker?['broker_id']?.toString();

              if (brokerId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please log in to add enquiry'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              await AddEnquirySheet.show(
                context,
                projects: _visibleProjects,
                brokerId: brokerId,
                lockProjectSelection: true,
                onCreated: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Enquiry added for ${_visibleProjects.length} projects!',
                      ),
                      backgroundColor: theme.colorScheme.primary,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                },
              );
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${e.toString()}'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_add_outlined, size: 18),
              const SizedBox(width: 8),
              Text(
                'Tag Clients to All Projects (${_visibleProjects.length})',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSummary(ThemeData theme, bool isDark) {
    final List<String> activeFilters = [];

    // Price/Size filters
    if (_priceMinCr != null && _priceMinCr != _globalPriceMinCr) {
      activeFilters.add('Min Price: ₹${_formatCr(_priceMinCr!)} Cr');
    }
    if (_priceMaxCr != null && _priceMaxCr != _globalPriceMaxCr) {
      activeFilters.add('Max Price: ₹${_formatCr(_priceMaxCr!)} Cr');
    }
    if (_areaMinSqft != null && _areaMinSqft != _globalAreaMinSqft) {
      activeFilters.add('Min Size: ${_areaMinSqft!.toStringAsFixed(0)} sq ft');
    }
    if (_areaMaxSqft != null && _areaMaxSqft != _globalAreaMaxSqft) {
      activeFilters.add('Max Size: ${_areaMaxSqft!.toStringAsFixed(0)} sq ft');
    }

    // Location range
    if (_selectedLocationRange != null) {
      activeFilters.add(
        'Within ${_selectedLocationRange!.toStringAsFixed(0)} km',
      );
    }

    // Bedrooms
    if (_selectedBedrooms.isNotEmpty) {
      final bedrooms = _selectedBedrooms.toList()..sort();
      activeFilters.add(
        'Bedrooms: ${bedrooms.map((b) => '${b}BHK').join(', ')}',
      );
    }

    // Roads
    // if (_selectedRoads.isNotEmpty) {
    //   activeFilters.add('Roads: ${_selectedRoads.join(', ')}');
    // }

    // Status
    if (_selectedStatuses.isNotEmpty) {
      activeFilters.add('Status: ${_selectedStatuses.join(', ')}');
    }

    // Amenities
    if (_selectedAmenities.isNotEmpty) {
      final amenities = _selectedAmenities.take(3).join(', ');
      final more = _selectedAmenities.length > 3
          ? ' +${_selectedAmenities.length - 3} more'
          : '';
      activeFilters.add('Amenities: $amenities$more');
    }

    // Developers
    if (_selectedDeveloperIds.isNotEmpty) {
      final devNames = _selectedDevelopers.take(2).join(', ');
      final more = _selectedDevelopers.length > 2
          ? ' +${_selectedDevelopers.length - 2} more'
          : '';
      activeFilters.add('Developers: $devNames$more');
    }

    if (activeFilters.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.filter_alt,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Active Filters (${activeFilters.length})',
                style: TextStyle(
                  color: theme.colorScheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: activeFilters.map((filter) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Text(
                  filter,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Main PageView for YouTube Shorts-like scrolling
          _isLoading
              ? Center(
                  child: CircularProgressIndicator(
                    color: isDark ? Colors.white : theme.colorScheme.primary,
                  ),
                )
              : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: $_errorMessage',
                        style: TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchData,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _projects.isEmpty
              ? Center(
                  child: Text(
                    'No projects available',
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                      fontSize: 18,
                    ),
                  ),
                )
              : _visibleProjects.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'No such projects found',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _selectedLocation = null;
                            _selectedLocationRange = null;
                            _priceMinCr = _globalPriceMinCr;
                            _priceMaxCr = _globalPriceMaxCr;
                            _areaMinSqft = _globalAreaMinSqft;
                            _areaMaxSqft = _globalAreaMaxSqft;
                            _selectedBedrooms.clear();
                            _selectedAmenities.clear();
                            _selectedDevelopers.clear();
                            _selectedDeveloperIds.clear();
                            _selectedRoads.clear();
                            _selectedStatuses.clear();
                          });
                        },
                        child: const Text('Clear Filters'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: () => _fetchData(forceRefresh: true),
                  child: PageView.builder(
                  controller: _pageController,
                  scrollDirection: Axis.vertical,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                  },
                  itemCount: _visibleProjects.length,
                  itemBuilder: (context, index) {
                    final project = _visibleProjects[index];
                    final developer = _developers.firstWhere(
                      (dev) => dev.id == project.developerId,
                      orElse: () => Developer(
                        id: '',
                        createdAt: '',
                        updatedAt: '',
                        username: 'Unknown',
                        email: '',
                        developerName: 'Unknown Developer',
                        reraNumber: '',
                        gstNumber: '',
                        panNumber: '',
                        officeAddress: '',
                        contactPerson: '',
                        contactEmail: '',
                        contactPhone: '',
                        companySize: '',
                        specializations: [],
                        certifications: [],
                        bankDetails: BankDetails(
                          accountNumber: '',
                          ifscCode: '',
                          bankName: '',
                        ),
                        kycStatus: '',
                        isVerified: false,
                        isActive: false,
                        websiteUrl: '',
                        logoUrl: '',
                        companyDescription: '',
                        yearEstablished: 0,
                        totalProjectsCompleted: 0,
                        currentProjectsCount: 0,
                        stories: [],
                        projectsList: [],
                      ),
                    );

                    return ProjectCard(project: project, developer: developer);
                  },
                ),
                ),

          // Top navigation bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(
                top: 60,
                left: 20,
                right: 20,
                bottom: 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    (isDark ? Colors.black : Colors.white).withOpacity(0.5),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => _fetchData(forceRefresh: true),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.refresh, color: Colors.white, size: 24),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _shareCurrentProject,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: (isDark ? Colors.white : Colors.black)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(Icons.share, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Right-side middle actions: Exclusive, All Locations, Filters
          Positioned(
            right: 12,
            top: MediaQuery.of(context).size.height * 0.35,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildSideButton(
                  context,
                  icon: Icons.star_rounded,
                  label: 'Exclusive',
                  onTap: () {},
                  showChevron: false,
                  imageAsset: 'assets/logo/logo_transparent1.png',
                ),
                const SizedBox(height: 10),
                _buildSideButton(
                  context,
                  icon: Icons.location_on_rounded,
                  label: _selectedLocation ?? 'All Locations',
                  onTap: () => _openLocationSheet(context),
                  showChevron: false,
                ),
                const SizedBox(height: 10),
                _buildSideButton(
                  context,
                  icon: Icons.filter_list_rounded,
                  label: 'Filters',
                  onTap: () => _openFiltersSheet(context),
                  showChevron: false,
                  isHighlighted: _hasActiveFilters(),
                ),
              ],
            ),
          ),

          // Removed pagination dots per request
        ],
      ),
    );
  }

  // removed unused _buildRightIcon

  Widget _buildBottomNavItem(IconData icon, String label) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: isDark ? Colors.white : theme.colorScheme.primary,
          size: 30,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

Widget _buildSideButton(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  bool showChevron = false,
  String? imageAsset,
  bool isHighlighted = false,
}) {
  final theme = Theme.of(context);
  final isDark = theme.brightness == Brightness.dark;
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF202124).withOpacity(0.95),
                    const Color(0xFF18191B).withOpacity(0.95),
                  ]
                : [
                    const Color.fromARGB(34, 255, 255, 255),
                    const Color(0xFFF9FAFB),
                  ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isHighlighted
                  ? theme.colorScheme.primary.withOpacity(0.4)
                  : Colors.black.withOpacity(0.08),
              blurRadius: isHighlighted ? 16 : 12,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(
            color: isHighlighted
                ? const Color.fromARGB(255, 206, 161, 0) // Golden border
                : (isDark ? Colors.white : Colors.black).withOpacity(0.08),
            width: isHighlighted ? 3 : 1,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // plain image/icon without any circular background
            imageAsset != null
                ? Image.asset(
                    imageAsset,
                    width: 25,
                    height: 25,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => Icon(
                      icon,
                      size: 18,
                      color: isDark ? Colors.white : theme.colorScheme.primary,
                    ),
                  )
                : Icon(
                    icon,
                    size: 18,
                    color: isDark ? Colors.white : theme.colorScheme.primary,
                  ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (showChevron) ...[
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: isDark ? Colors.white.withOpacity(0.9) : Colors.black54,
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

// moved _ProjectCard into components/projects/project_card.dart as ProjectCard

class LocationRadiusPainter extends CustomPainter {
  final double selectedRange;
  final bool isDark;

  LocationRadiusPainter({required this.selectedRange, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width * 0.3).clamp(20.0, 50.0);

    // Draw radius circle
    final radiusPaint = Paint()
      ..color = const Color(0xFFdbc163).withOpacity(0.3)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, radiusPaint);

    // Draw radius border
    final borderPaint = Paint()
      ..color = const Color(0xFFdbc163)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(center, radius, borderPaint);

    // Draw center point
    final centerPaint = Paint()
      ..color = const Color(0xFFdbc163)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 4, centerPaint);

    // Draw grid lines
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    // Vertical lines
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }

    // Horizontal lines
    for (int i = 1; i < 4; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is LocationRadiusPainter &&
        (oldDelegate.selectedRange != selectedRange ||
            oldDelegate.isDark != isDark);
  }
}
