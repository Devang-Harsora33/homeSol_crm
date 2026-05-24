class Sourcing {
  final String? name;
  final String? owner;
  final String? creation;
  final String? modified;
  final String? modifiedBy;
  final int? docstatus;
  final int? idx;
  final String? salesPartner;
  final String? customChannelPartner;
  final String? channelPartner;
  final String? contactPersonMet;
  final String? mobileNumber;
  final String? whatsappNumber;
  final String? visitStatus;
  final String? visitDate;
  final String? remark;
  final String? address;
  final String? location;

  String? visitDuration;
  final int? offeredCoffee;
  final int? metTheOwner;
  final int? askedAboutPriceTrends;
  final int? consideringRedevelopment;
  final int? concernedAboutInterestRates;
  final int? comparedMicroMarkets;
  final int? strictlyReraRegistered;

  final String? visitType;
  final String? cpInterest;
  final String? interestedProject;
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
    this.askedAboutPriceTrends,
    this.consideringRedevelopment,
    this.concernedAboutInterestRates,
    this.comparedMicroMarkets,
    this.strictlyReraRegistered,

    this.visitType,
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
      askedAboutPriceTrends: json['asked_about_price_trends'] is int ? json['asked_about_price_trends'] : int.tryParse(json['asked_about_price_trends']?.toString() ?? '0'),
      consideringRedevelopment: json['considering_redevelopment'] is int ? json['considering_redevelopment'] : int.tryParse(json['considering_redevelopment']?.toString() ?? '0'),
      concernedAboutInterestRates: json['concerned_about_interest_rates'] is int ? json['concerned_about_interest_rates'] : int.tryParse(json['concerned_about_interest_rates']?.toString() ?? '0'),
      comparedMicroMarkets: json['compared_micro_markets'] is int ? json['compared_micro_markets'] : int.tryParse(json['compared_micro_markets']?.toString() ?? '0'),
      strictlyReraRegistered: json['strictly_rera_registered'] is int ? json['strictly_rera_registered'] : int.tryParse(json['strictly_rera_registered']?.toString() ?? '0'),

      visitType: json['visit_type']?.toString(),
      cpInterest: json['cp_interest']?.toString(),
      interestedProject: json['interested_project']?.toString(),
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
      'asked_about_price_trends': askedAboutPriceTrends,
      'considering_redevelopment': consideringRedevelopment,
      'concerned_about_interest_rates': concernedAboutInterestRates,
      'compared_micro_markets': comparedMicroMarkets,
      'strictly_rera_registered': strictlyReraRegistered,

      'visit_type': visitType,
      'cp_interest': cpInterest,
      'interested_project': interestedProject,
      'next_follow_up': nextFollowUp,
      'enter_otp': enterOtp,
      'is_verified': isVerified,
      'doctype': doctype ?? 'Sales Fields Service',
    };
  }
}
