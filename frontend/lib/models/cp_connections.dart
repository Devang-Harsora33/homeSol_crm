class CPConnections {
  final CPProfile? profile;
  final String? onboardedOn;
  final CPConnectionsData? connections;
  final CPMetrics? metrics;
  final List<String> activeProjects;
  final List<CPCampaignSummary> campaigns;
  final List<CPRecentLead> recentLeads;
  final List<CPRecentVisit> recentVisits;

  CPConnections({
    this.profile,
    this.onboardedOn,
    this.connections,
    this.metrics,
    this.activeProjects = const [],
    this.campaigns = const [],
    this.recentLeads = const [],
    this.recentVisits = const [],
  });

  factory CPConnections.fromJson(Map<String, dynamic> json) {
    return CPConnections(
      profile: json['profile'] != null ? CPProfile.fromJson(json['profile']) : null,
      onboardedOn: json['onboarded_on'],
      connections: json['connections'] != null ? CPConnectionsData.fromJson(json['connections']) : null,
      metrics: json['metrics'] != null ? CPMetrics.fromJson(json['metrics']) : null,
      activeProjects: List<String>.from(json['active_projects'] ?? []),
      campaigns: (json['campaigns'] as List?)?.map((e) => CPCampaignSummary.fromJson(e)).toList() ?? [],
      recentLeads: (json['recent_leads'] as List?)?.map((e) => CPRecentLead.fromJson(e)).toList() ?? [],
      recentVisits: (json['recent_visits'] as List?)?.map((e) => CPRecentVisit.fromJson(e)).toList() ?? [],
    );
  }
}

class CPProfile {
  final String? name;
  final String? firmName;
  final String? owner;
  final String? mobileNumber;
  final String? creation;

  CPProfile({this.name, this.firmName, this.owner, this.mobileNumber, this.creation});

  factory CPProfile.fromJson(Map<String, dynamic> json) {
    return CPProfile(
      name: json['name'],
      firmName: json['firm_name'],
      owner: json['owner'],
      mobileNumber: json['mobile_number'],
      creation: json['creation'],
    );
  }
}

class CPConnectionsData {
  final CPCreator? creator;
  final List<CPNetworkMember> network;

  CPConnectionsData({this.creator, this.network = const []});

  factory CPConnectionsData.fromJson(Map<String, dynamic> json) {
    return CPConnectionsData(
      creator: json['creator'] != null ? CPCreator.fromJson(json['creator']) : null,
      network: (json['network'] as List?)?.map((e) => CPNetworkMember.fromJson(e)).toList() ?? [],
    );
  }
}

class CPCreator {
  final String? email;
  final String? name;

  CPCreator({this.email, this.name});

  factory CPCreator.fromJson(Map<String, dynamic> json) {
    return CPCreator(email: json['email'], name: json['name']);
  }
}

class CPNetworkMember {
  final String? email;
  final String? name;

  CPNetworkMember({this.email, this.name});

  factory CPNetworkMember.fromJson(Map<String, dynamic> json) {
    return CPNetworkMember(email: json['email'], name: json['name']);
  }
}

class CPMetrics {
  final int totalLeads;
  final int totalVisits;
  final int totalCampaigns;
  final int activeProjectsCount;

  CPMetrics({
    this.totalLeads = 0,
    this.totalVisits = 0,
    this.totalCampaigns = 0,
    this.activeProjectsCount = 0,
  });

  factory CPMetrics.fromJson(Map<String, dynamic> json) {
    return CPMetrics(
      totalLeads: json['total_leads'] ?? 0,
      totalVisits: json['total_visits'] ?? 0,
      totalCampaigns: json['total_campaigns'] ?? 0,
      activeProjectsCount: json['active_projects_count'] ?? 0,
    );
  }
}

class CPCampaignSummary {
  final String? name;
  final String? project;
  final String? campaignType;
  final String? startDate;
  final String? endDate;
  final String? status;

  CPCampaignSummary({this.name, this.project, this.campaignType, this.startDate, this.endDate, this.status});

  factory CPCampaignSummary.fromJson(Map<String, dynamic> json) {
    return CPCampaignSummary(
      name: json['name'],
      project: json['project'],
      campaignType: json['campaign_type'],
      startDate: json['start_date'],
      endDate: json['end_date'],
      status: json['status'],
    );
  }
}

class CPRecentLead {
  final String? name;
  final String? leadName;
  final String? status;
  final String? project;
  final String? creation;
  final String? owner;
  final List<dynamic> siteVisits;

  CPRecentLead({this.name, this.leadName, this.status, this.project, this.creation, this.owner, this.siteVisits = const []});

  factory CPRecentLead.fromJson(Map<String, dynamic> json) {
    return CPRecentLead(
      name: json['name'],
      leadName: json['lead_name'],
      status: json['custom_lead_status'],
      project: json['custom_interested_project'],
      creation: json['creation'],
      owner: json['lead_owner'],
      siteVisits: json['site_visits'] ?? [],
    );
  }
}

class CPRecentVisit {
  final String? name;
  final String? owner;
  final String? visitDate;
  final String? visitStatus;
  final String? project;
  final String? cpInterest;
  final String? contactPersonMet;
  final String? campaignDiscussed;
  final Map<String, dynamic>? campaignDetails;

  CPRecentVisit({
    this.name,
    this.owner,
    this.visitDate,
    this.visitStatus,
    this.project,
    this.cpInterest,
    this.contactPersonMet,
    this.campaignDiscussed,
    this.campaignDetails,
  });

  factory CPRecentVisit.fromJson(Map<String, dynamic> json) {
    return CPRecentVisit(
      name: json['name'],
      owner: json['owner'],
      visitDate: json['visit_date'],
      visitStatus: json['visit_status'],
      project: json['interested_project'],
      cpInterest: json['cp_interest'],
      contactPersonMet: json['contact_person_met'],
      campaignDiscussed: json['campaign_discussed'],
      campaignDetails: json['campaign_details'],
    );
  }
}
