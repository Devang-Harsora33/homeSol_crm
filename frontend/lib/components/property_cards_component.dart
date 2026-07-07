import 'package:flutter/material.dart';
import 'project_card.dart';
import '../models/project.dart';
import '../models/developer.dart';

class PropertyCardsComponent extends StatelessWidget {
  final List<Project>? projects;
  final List<Developer>? developers;
  final bool isLoading; // New property for loading state

  const PropertyCardsComponent({
    super.key,
    this.projects,
    this.developers,
    this.isLoading = false, // Default to false
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    // Determine what to display based on isLoading
    Widget content;
    if (isLoading) {
      content = ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 3, // Display a few skeleton cards
        itemBuilder: (context, index) => const HomeProjectCardSkeleton(),
      );
    } else {
      // Use actual projects if available, otherwise create fallback projects
      final List<Project> displayProjects =
          projects != null && projects!.isNotEmpty
          ? projects!
          : _getFallbackProjects();

      content = LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth > 600;

          if (!isTablet) {
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: displayProjects.length,
              itemBuilder: (context, index) {
                final project = displayProjects[index];
                final developer = developers?.firstWhere(
                      (dev) => dev.id == project.developer,
                      orElse: () => _getFallbackDeveloper(),
                    ) ??
                    _getFallbackDeveloper();
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: HomeProjectCard(project: project, developer: developer),
                );
              },
            );
          } else {
            // Tablet responsive grid using Wrap
            final crossAxisCount = constraints.maxWidth > 900 ? 3 : 2;
            final spacing = 16.0;
            final itemWidth = (constraints.maxWidth - (spacing * (crossAxisCount - 1))) / crossAxisCount;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: displayProjects.map((project) {
                final developer = developers?.firstWhere(
                      (dev) => dev.id == project.developer,
                      orElse: () => _getFallbackDeveloper(),
                    ) ??
                    _getFallbackDeveloper();
                return SizedBox(
                  width: itemWidth,
                  child: HomeProjectCard(project: project, developer: developer),
                );
              }).toList(),
            );
          }
        },
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Featured Properties',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // Navigate to all properties
                  },
                  child: Text(
                    'View All',
                    style: TextStyle(
                      color: cs.secondary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Property Cards List or Skeletons
          content,
        ],
      ),
    );
  }


  List<Project> _getFallbackProjects() {
    return [
      Project(
        id: 'fallback-1',
        projectName: 'Godrej Evergreen Square',
        developer: 'fallback-dev-1',
        mandate: 'HomeSol',
        reraId: 'RERA123456',
        constructionStatus: 'New Launch',
        propertyType: 'Residential',
        description: 'Premium residential project with modern amenities',
        projectRm: 'test@example.com',
        locationName: 'Hinjawadi',
        city: 'Pune',
        state: 'Maharashtra',
        nearbyLandmarks: 'Near Blue Ridge',
        projectApproval: 'PMC Approved',
        developmentScheme: 'Standard',
        priceRangeMin: 60,
        priceRangeMax: 120,
        parkingType: 'Covered',
        launchDate: '2023-01-15',
        possessionDate: '2025-12-31',
        targetPossession: '2025-12-01',
        architect: 'Ar. Rahul Sharma',
        contractor: 'BuildWell Inc.',
        electricalContractor: 'Electro Solutions',
        reraLiasoning: 'RERA Consultants',
        documents: [],
        galleryImages: [ProjectImage(images: 'assets/images/properties/1.webp')],
        brokerageSlabs: [],
        amenities: ['Swimming Pool', 'Gym', 'Garden', 'Security'].map((e) => ProjectAmenity(data: e)).toList(),
        configurations: [
          Configuration(name: '1 BHK', carpetArea: 600, price: 60),
          Configuration(name: '2 BHK', carpetArea: 900, price: 85),
          Configuration(name: '3 BHK', carpetArea: 1200, price: 120),
        ],
        projectTimeline: [],
        creation: '2023-01-01T10:00:00Z',
        modified: '2023-06-01T12:00:00Z',
      ),
      Project(
        id: 'fallback-2',
        projectName: 'Lodha Belmondo',
        developer: 'fallback-dev-2',
        mandate: 'HomeSol',
        reraId: 'RERA123457',
        constructionStatus: 'Ready to Move',
        propertyType: 'Residential',
        description: 'Luxury residential project with premium amenities',
        projectRm: 'test@example.com',
        locationName: 'Hinjawadi',
        city: 'Pune',
        state: 'Maharashtra',
        nearbyLandmarks: 'Next to Golf Course',
        projectApproval: 'PCMC Approved',
        developmentScheme: 'Luxury',
        priceRangeMin: 85,
        priceRangeMax: 180,
        parkingType: 'Covered',
        launchDate: '2022-03-10',
        possessionDate: '2024-06-30',
        targetPossession: '2024-06-01',
        architect: 'Ar. Priya Singh',
        contractor: 'Premium Builders',
        electricalContractor: 'Power Grid',
        reraLiasoning: 'Apex RERA Services',
        documents: [],
        galleryImages: [ProjectImage(images: 'assets/images/properties/2.webp')],
        brokerageSlabs: [],
        amenities: ['Swimming Pool', 'Gym'].map((e) => ProjectAmenity(data: e)).toList(),
        configurations: [
          Configuration(name: '2 BHK', carpetArea: 1000, price: 85),
          Configuration(name: '3 BHK', carpetArea: 1400, price: 120),
          Configuration(name: '4 BHK', carpetArea: 1800, price: 180),
        ],
        projectTimeline: [],
        creation: '2022-03-01T10:00:00Z',
        modified: '2023-05-15T12:00:00Z',
      ),
      Project(
        id: 'fallback-3',
        projectName: 'Prestige Park Ridge',
        developer: 'fallback-dev-3',
        mandate: 'HomeSol',
        reraId: 'RERA123458',
        constructionStatus: 'Under Construction',
        propertyType: 'Residential',
        description: 'Affordable residential project with essential amenities',
        projectRm: 'test@example.com',
        locationName: 'Wakad',
        city: 'Pune',
        state: 'Maharashtra',
        nearbyLandmarks: 'Near Xion Mall',
        projectApproval: 'PMC Approved',
        developmentScheme: 'Affordable',
        priceRangeMin: 45,
        priceRangeMax: 65,
        parkingType: 'Open',
        launchDate: '2024-07-01',
        possessionDate: '2026-12-31',
        targetPossession: '2026-12-01',
        architect: 'Ar. Rohan Mehta',
        contractor: 'Urban Developers',
        electricalContractor: 'Volt Electricals',
        reraLiasoning: 'City RERA Solutions',
        documents: [],
        galleryImages: [ProjectImage(images: 'assets/images/properties/3.webp')],
        brokerageSlabs: [],
        amenities: ['Gym', 'Garden', 'Security'].map((e) => ProjectAmenity(data: e)).toList(),
        configurations: [
          Configuration(name: '1 BHK', carpetArea: 550, price: 45),
          Configuration(name: '2 BHK', carpetArea: 800, price: 65),
        ],
        projectTimeline: [],
        creation: '2024-07-01T10:00:00Z',
        modified: '2024-08-01T12:00:00Z',
      ),
    ];
  }

  Developer _getFallbackDeveloper() {
    return Developer(
      id: 'fallback-dev',
      createdAt: DateTime.now().toIso8601String(),
      updatedAt: DateTime.now().toIso8601String(),
      username: 'fallback',
      email: 'fallback@example.com',
      developerName: 'HomeSol Developer',
      reraNumber: 'RERA123456',
      gstNumber: 'GST123456',
      panNumber: 'PAN123456',
      officeAddress: 'Pune, Maharashtra',
      contactPerson: 'John Doe',
      contactEmail: 'contact@example.com',
      contactPhone: '+91 9876543210',
      companySize: 'Medium',
      specializations: ['Residential', 'Commercial'],
      certifications: ['RERA Certified'],
      bankDetails: BankDetails(
        accountNumber: '1234567890',
        ifscCode: 'SBIN0001234',
        bankName: 'State Bank of India',
      ),
      kycStatus: 'verified',
      isVerified: true,
      isActive: true,
      websiteUrl: 'https://example.com',
      logoUrl: '',
      companyDescription: 'Leading real estate developer',
      yearEstablished: 2010,
      totalProjectsCompleted: 50,
      currentProjectsCount: 10,
      stories: [],
      projectsList: [],
    );
  }
}
