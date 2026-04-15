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
  final int? digital;
  final int? reference;
  final int? dataCalling;
  final int? retail;
  final int? underConstruction;
  final int? rental;
  final int? readyToMove;
  final int? callingSupport;
  final int? digitalKit;
  final int? standees;
  final int? smsBlast;
  final int? whatsappBlast;
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
    this.digital,
    this.reference,
    this.dataCalling,
    this.retail,
    this.underConstruction,
    this.rental,
    this.readyToMove,
    this.callingSupport,
    this.digitalKit,
    this.standees,
    this.smsBlast,
    this.whatsappBlast,
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
      digital: json['digital'] is int ? json['digital'] : int.tryParse(json['digital']?.toString() ?? '0'),
      reference: json['reference'] is int ? json['reference'] : int.tryParse(json['reference']?.toString() ?? '0'),
      dataCalling: json['data_calling'] is int ? json['data_calling'] : int.tryParse(json['data_calling']?.toString() ?? '0'),
      retail: json['retail'] is int ? json['retail'] : int.tryParse(json['retail']?.toString() ?? '0'),
      underConstruction: json['under_construction'] is int ? json['under_construction'] : int.tryParse(json['under_construction']?.toString() ?? '0'),
      rental: json['rental'] is int ? json['rental'] : int.tryParse(json['rental']?.toString() ?? '0'),
      readyToMove: json['ready_to_move'] is int ? json['ready_to_move'] : int.tryParse(json['ready_to_move']?.toString() ?? '0'),
      callingSupport: json['calling_support'] is int ? json['calling_support'] : int.tryParse(json['calling_support']?.toString() ?? '0'),
      digitalKit: json['digital_kit'] is int ? json['digital_kit'] : int.tryParse(json['digital_kit']?.toString() ?? '0'),
      standees: json['standees'] is int ? json['standees'] : int.tryParse(json['standees']?.toString() ?? '0'),
      smsBlast: json['sms_blast'] is int ? json['sms_blast'] : int.tryParse(json['sms_blast']?.toString() ?? '0'),
      whatsappBlast: json['whatsapp_blast'] is int ? json['whatsapp_blast'] : int.tryParse(json['whatsapp_blast']?.toString() ?? '0'),
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
      'digital': digital,
      'reference': reference,
      'data_calling': dataCalling,
      'retail': retail,
      'under_construction': underConstruction,
      'rental': rental,
      'ready_to_move': readyToMove,
      'calling_support': callingSupport,
      'digital_kit': digitalKit,
      'standees': standees,
      'sms_blast': smsBlast,
      'whatsapp_blast': whatsappBlast,
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
