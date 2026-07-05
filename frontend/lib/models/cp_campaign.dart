class CPCampaign {
  final String name;
  final String channelPartner;
  final String project;
  final String campaignType;
  final String startDate;
  final String status;

  CPCampaign({
    required this.name,
    required this.channelPartner,
    required this.project,
    required this.campaignType,
    required this.startDate,
    required this.status,
  });

  factory CPCampaign.fromJson(Map<String, dynamic> json) {
    return CPCampaign(
      name: json['name'] ?? '',
      channelPartner: json['channel_partner'] ?? '',
      project: json['project'] ?? '',
      campaignType: json['campaign_type'] ?? '',
      startDate: json['start_date'] ?? '',
      status: json['status'] ?? 'Active',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'channel_partner': channelPartner,
      'project': project,
      'campaign_type': campaignType,
      'start_date': startDate,
      'status': status,
    };
  }
}
