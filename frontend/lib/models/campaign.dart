class CampaignProjectLink {
  final String name;
  final String projects;

  CampaignProjectLink({
    required this.name,
    required this.projects,
  });

  factory CampaignProjectLink.fromJson(Map<String, dynamic> json) {
    return CampaignProjectLink(
      name: json['name'] ?? '',
      projects: json['projects'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'projects': projects,
    };
  }
}

class Campaign {
  final String name;
  final String campaignCodeName;
  final String startDate;
  final String endDate;
  final String vendor;
  final String activeInactive;
  final String locationPincodes;
  final String targetAudience;
  final int leadsGenerated;
  final String? onlineOffline;
  final List<CampaignProjectLink> linkedProjects;

  Campaign({
    required this.name,
    required this.campaignCodeName,
    required this.startDate,
    required this.endDate,
    required this.vendor,
    required this.activeInactive,
    required this.locationPincodes,
    required this.targetAudience,
    required this.leadsGenerated,
    this.onlineOffline,
    this.linkedProjects = const [],
  });

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      name: json['name'] ?? '',
      campaignCodeName: json['campaign_code_name'] ?? '',
      startDate: json['start_date'] ?? '',
      endDate: json['end_date'] ?? '',
      vendor: json['vendor'] ?? '',
      activeInactive: json['activeinactive'] ?? '',
      locationPincodes: json['location_pincodes'] ?? '',
      targetAudience: json['target_audience'] ?? '',
      leadsGenerated: (json['leads_generated'] ?? 0).toInt(),
      onlineOffline: json['onlineoffline'],
      linkedProjects: (json['linked_projects'] as List<dynamic>?)
              ?.map((e) => CampaignProjectLink.fromJson(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'campaign_code_name': campaignCodeName,
      'start_date': startDate,
      'end_date': endDate,
      'vendor': vendor,
      'activeinactive': activeInactive,
      'location_pincodes': locationPincodes,
      'target_audience': targetAudience,
      'leads_generated': leadsGenerated,
      'onlineoffline': onlineOffline,
      'linked_projects': linkedProjects.map((e) => e.toJson()).toList(),
    };
  }
}
