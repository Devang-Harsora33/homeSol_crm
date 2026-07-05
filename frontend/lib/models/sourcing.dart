import 'dart:convert';

class SourcingProject {
  final String? project;

  SourcingProject({this.project});

  factory SourcingProject.fromJson(Map<String, dynamic> json) {
    return SourcingProject(
      project: json['project']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'project': project,
    };
  }
}

class Sourcing {
  final String? name;
  final String? owner;
  final String? creation;
  final String? modified;
  final String? modifiedBy;
  int? docstatus;
  final int? idx;
  final String? salesPartner;
  final String? customChannelPartner;
  final String? channelPartner;
  final String? contactPersonMet;
  final String? mobileNumber;
  final String? whatsappNumber;
  String? visitStatus;
  final String? visitDate;
  final String? remark;
  final String? address;
  final String? location;

  String? visitDuration;
  final int? offeredCoffee;
  final int? metTheOwner;
  final int? marketOutlook;
  final String? currentDemand;

  String? visitType;
  final String? campaignDiscussed;
  final String? cpInterest;
  final List<SourcingProject>? interestedProject;
  final String? nextFollowUp;
  final String? enterOtp;
  final int? isVerified;
  final String? doctype;

  Sourcing({
    this.name,
    this.owner,
    this.creation,
    this.modified,
    this.modifiedBy,
    this.docstatus,
    this.idx,
    this.salesPartner,
    this.customChannelPartner,
    this.channelPartner,
    this.contactPersonMet,
    this.mobileNumber,
    this.whatsappNumber,
    this.visitStatus,
    this.visitDate,
    this.remark,
    this.address,
    this.location,

    this.visitDuration,
    this.offeredCoffee,
    this.metTheOwner,
    this.marketOutlook,
    this.currentDemand,

    this.visitType,
    this.campaignDiscussed,
    this.cpInterest,
    this.interestedProject,
    this.nextFollowUp,
    this.enterOtp,
    this.isVerified,
    this.doctype,
  });

  String? get channelPartnerId {
    return salesPartner ?? customChannelPartner ?? channelPartner;
  }

  static List<SourcingProject>? _parseInterestedProject(dynamic value) {
    if (value == null) return null;
    try {
      if (value is List) {
        return value.map((i) {
          if (i is Map) return SourcingProject.fromJson(Map<String, dynamic>.from(i));
          if (i is String) return SourcingProject(project: i);
          return SourcingProject(project: i?.toString());
        }).where((p) => p.project != null).toList();
      }
      if (value is String) {
        if (value.trim().startsWith('[')) {
          final decoded = jsonDecode(value);
          if (decoded is List) {
            return decoded.map((i) {
              if (i is Map) return SourcingProject.fromJson(Map<String, dynamic>.from(i));
              if (i is String) return SourcingProject(project: i);
              return SourcingProject(project: i?.toString());
            }).where((p) => p.project != null).toList();
          }
        } else if (value.isNotEmpty) {
          return [SourcingProject(project: value)];
        }
      }
    } catch (e) {
      print('Error parsing interestedProject: $e | Value: $value');
    }
    return null;
  }

  factory Sourcing.fromJson(Map<String, dynamic> json) {
    return Sourcing(
      name: json['name']?.toString(),
      owner: json['owner']?.toString(),
      creation: json['creation']?.toString(),
      modified: json['modified']?.toString(),
      modifiedBy: json['modified_by']?.toString(),
      docstatus: json['docstatus'] is int ? json['docstatus'] : int.tryParse(json['docstatus']?.toString() ?? '0'),
      idx: json['idx'] is int ? json['idx'] : int.tryParse(json['idx']?.toString() ?? '0'),
      salesPartner: json['sales_partner']?.toString(),
      customChannelPartner: json['custom_channel_partner']?.toString(),
      channelPartner: json['channel_partner']?.toString(),
      contactPersonMet: json['contact_person_met']?.toString(),
      mobileNumber: json['mobile_number']?.toString(),
      whatsappNumber: json['whatsapp_number']?.toString(),
      visitStatus: json['visit_status']?.toString(),
      visitDate: json['visit_date']?.toString(),
      remark: json['remark']?.toString(),
      address: json['address']?.toString(),
      location: json['location']?.toString(),

      visitDuration: json['visit_duration']?.toString(),
      offeredCoffee: json['offered_coffee'] is int ? json['offered_coffee'] : int.tryParse(json['offered_coffee']?.toString() ?? '0'),
      metTheOwner: json['met_the_owner'] is int ? json['met_the_owner'] : int.tryParse(json['met_the_owner']?.toString() ?? '0'),
      marketOutlook: json['market_outlook'] is int ? json['market_outlook'] : int.tryParse(json['market_outlook']?.toString() ?? '0'),
      currentDemand: json['current_demand']?.toString(),

      visitType: json['visit_type']?.toString(),
      campaignDiscussed: json['campaign_discussed']?.toString(),
      cpInterest: json['cp_interest']?.toString(),
      interestedProject: _parseInterestedProject(json['interested_project']),
      nextFollowUp: json['next_follow_up']?.toString(),
      enterOtp: json['enter_otp']?.toString(),
      isVerified: json['is_verified'] is int ? json['is_verified'] : int.tryParse(json['is_verified']?.toString() ?? '0'),
      doctype: json['doctype']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sales_partner': salesPartner,
      'custom_channel_partner': customChannelPartner,
      'channel_partner': channelPartner,
      'contact_person_met': contactPersonMet,
      'mobile_number': mobileNumber,
      'whatsapp_number': whatsappNumber,
      'visit_status': visitStatus,
      'visit_date': visitDate,
      'remark': remark,
      'address': address,
      'location': location,

      'visit_duration': visitDuration,
      'offered_coffee': offeredCoffee,
      'met_the_owner': metTheOwner,
      'market_outlook': marketOutlook,
      'current_demand': currentDemand,

      'visit_type': visitType,
      'campaign_discussed': campaignDiscussed,
      'cp_interest': cpInterest,
      'interested_project': interestedProject?.map((i) => i.toJson()).toList(),
      'next_follow_up': nextFollowUp,
      'enter_otp': enterOtp,
      'is_verified': isVerified,
      'doctype': doctype ?? 'Sales Fields Service',
    };
  }
}
