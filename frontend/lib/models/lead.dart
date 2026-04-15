class LeadNote {
  final String? note;
  final String? addedBy;
  final DateTime? addedOn;

  LeadNote({this.note, this.addedBy, this.addedOn});

  factory LeadNote.fromJson(Map<String, dynamic> json) {
    return LeadNote(
      note: json['note']?.toString(),
      addedBy: json['added_by']?.toString(),
      addedOn: json['added_on'] != null
          ? DateTime.parse(json['added_on'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'note': note,
      'added_by': addedBy,
      'added_on': addedOn?.toIso8601String(),
    };
  }

  String get plainText {
    if (note == null) return "";
    return note!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

class Lead {
  final String? id;
  final String? name;
  final String? owner;
  final DateTime? creation;
  final DateTime? modified;
  final String? modifiedBy;
  final int? docstatus;
  final int? idx;
  final String? namingSeries;
  final String? salutation;
  final String? firstName;
  final String? middleName;
  final String? lastName;
  final String? leadName;
  final String? jobTitle;
  final String? gender;
  final String? source;
  final String? leadOwner;
  final String? status;
  final String? customer;
  final String? type;
  final String? requestType;
  final String? emailId;
  final String? website;
  final String? mobileNo;
  final String? whatsappNo;
  final String? customChannelPartner;
  final String? phone;
  final String? phoneExt;
  final String? companyName;
  final String? noOfEmployees;
  final double? annualRevenue;
  final String? industry;
  final String? marketSegment;
  final String? territory;
  final String? fax;
  final String? city;
  final String? state;
  final String? country;
  final String? qualificationStatus;
  final String? qualifiedBy;
  final DateTime? qualifiedOn;
  final String? campaignName;
  final String? company;
  final String? language;
  final String? image;
  final String? title;
  final int? disabled;
  final int? unsubscribed;
  final int? blogSubscriber;
  final String? doctype;
  final String? locationCoordinates;

  final List<LeadNote> notes;

  // Custom fields from JSON
  final String? customOccupation;
  final String? customStages;
  final String? customRepeatCustomer;
  final double? customLeadQuality;
  final String? customTagging;
  final String? customLatestVisitStatus;
  final String? customLeadStatus;
  final String? customLeadDate;
  final int? customRented;
  final int? customOwned;
  final int? customParentalfriend;
  final String? customCurrentResidenceType;
  final String? customConfiguration;
  final String? customLookingForPropertyType;
  final String? customFinancingDetails;
  final String? customBudgetMin;
  final String? customBudgetMax;
  final String? customExpectedTimeOfPurchase;
  final String? customPurposeOfPurchase;
  final String? customRemark;
  final String? customInterestedProject;
  final String? customPreferredContactMethod;
  final String? customPostalCode;
  final String? customAttendedBy;
  final String? customSalesManager;
  final String? customSourceType;
  final int? isDigital;
  final int? isReference;
  final int? isDataCalling;
  final int? isRetail;
  final int? isUnderConstruction;
  final int? isRental;
  final int? isReadyToMove;
  final int? reqCallingSupport;
  final int? reqDigitalKit;
  final int? reqStandees;
  final int? reqSmsBlast;
  final int? reqWhatsappBlast;


  final String customerPhone;
  final String customerName;
  final String brokerId;
  final List<String> projectId;
  final int budget;
  final List<String> configuration;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? notesString; // Added to help backward compatibility if needed

  Lead({
    this.id,
    this.name,
    this.owner,
    this.creation,
    this.modified,
    this.modifiedBy,
    this.docstatus,
    this.idx,
    this.namingSeries,
    this.salutation,
    this.firstName,
    this.middleName,
    this.lastName,
    this.leadName,
    this.jobTitle,
    this.gender,
    this.source,
    this.leadOwner,
    this.customer,
    this.type,
    this.requestType,
    this.emailId,
    this.website,
    this.mobileNo,
    this.whatsappNo,
    this.customChannelPartner,
    this.phone,
    this.phoneExt,
    this.companyName,
    this.noOfEmployees,
    this.annualRevenue,
    this.industry,
    this.marketSegment,
    this.territory,
    this.fax,
    this.city,
    this.state,
    this.country,
    this.qualificationStatus,
    this.qualifiedBy,
    this.qualifiedOn,
    this.campaignName,
    this.company,
    this.language,
    this.image,
    this.title,
    this.disabled,
    this.unsubscribed,
    this.blogSubscriber,
    this.doctype,
    this.notes = const [],
    required this.customerPhone,
    required this.customerName,
    required this.brokerId,
    required this.projectId,
    required this.status,
    required this.budget,
    this.configuration = const [],
    this.createdAt,
    this.updatedAt,
    this.notesString,
    this.locationCoordinates,
    this.customOccupation,
    this.customStages,
    this.customRepeatCustomer,
    this.customLeadQuality,
    this.customTagging,
    this.customLatestVisitStatus,
    this.customLeadStatus,
    this.customLeadDate,
    this.customRented,
    this.customOwned,
    this.customParentalfriend,
    this.customCurrentResidenceType,
    this.customConfiguration,
    this.customLookingForPropertyType,
    this.customFinancingDetails,
    this.customBudgetMin,
    this.customBudgetMax,
    this.customExpectedTimeOfPurchase,
    this.customPurposeOfPurchase,
    this.customRemark,
    this.customInterestedProject,
    this.customPreferredContactMethod,
    this.customPostalCode,
    this.customAttendedBy,
    this.customSalesManager,
    this.customSourceType,
    this.isDigital,
    this.isReference,
    this.isDataCalling,
    this.isRetail,
    this.isUnderConstruction,
    this.isRental,
    this.isReadyToMove,
    this.reqCallingSupport,
    this.reqDigitalKit,
    this.reqStandees,
    this.reqSmsBlast,
    this.reqWhatsappBlast,
  });

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: (json['_id'] ?? json['id'] ?? json['name'])?.toString(),
      name: json['name']?.toString(),
      owner: json['owner']?.toString(),
      creation: json['creation'] != null
          ? DateTime.parse(json['creation'])
          : null,
      modified: json['modified'] != null
          ? DateTime.parse(json['modified'])
          : null,
      modifiedBy: json['modified_by']?.toString(),
      docstatus: json['docstatus']?.toInt(),
      idx: json['idx']?.toInt(),
      namingSeries: json['naming_series']?.toString(),
      salutation: json['salutation']?.toString(),
      firstName: json['first_name']?.toString(),
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString(),
      leadName: json['lead_name']?.toString(),
      jobTitle: json['job_title']?.toString(),
      gender: json['gender']?.toString(),
      source: json['source']?.toString(),
      leadOwner: json['lead_owner']?.toString(),
      status: json['status'] ?? 'pending',
      customer: json['customer']?.toString(),
      type: json['type']?.toString(),
      requestType: json['request_type']?.toString(),
      emailId: json['email_id']?.toString(),
      website: json['website']?.toString(),
      mobileNo: json['mobile_no']?.toString(),
      whatsappNo: json['whatsapp_no']?.toString(),
      customChannelPartner: json['custom_channel_partner']?.toString(),
      phone: json['phone']?.toString(),
      phoneExt: json['phone_ext']?.toString(),
      companyName: json['company_name']?.toString(),
      noOfEmployees: json['no_of_employees']?.toString(),
      annualRevenue: json['annual_revenue']?.toDouble(),
      industry: json['industry']?.toString(),
      marketSegment: json['market_segment']?.toString(),
      territory: json['territory']?.toString(),
      fax: json['fax']?.toString(),
      city: json['city']?.toString(),
      state: json['state']?.toString(),
      country: json['country']?.toString(),
      qualificationStatus: json['qualification_status']?.toString(),
      qualifiedBy: json['qualified_by']?.toString(),
      qualifiedOn: json['qualified_on'] != null
          ? DateTime.parse(json['qualified_on'])
          : null,
      campaignName: json['campaign_name']?.toString(),
      company: json['company']?.toString(),
      language: json['language']?.toString(),
      image: json['image']?.toString(),
      title: json['title']?.toString(),
      disabled: json['disabled']?.toInt(),
      unsubscribed: json['unsubscribed']?.toInt(),
      blogSubscriber: json['blog_subscriber']?.toInt(),
      doctype: json['doctype']?.toString(),

      notes: json['notes'] != null && json['notes'] is List
          ? (json['notes'] as List).map((e) => LeadNote.fromJson(e)).toList()
          : [],

      customerPhone:
          json['mobile_no'] ?? json['customer_phone'] ?? json['phone'] ?? '',
      customerName: json['lead_name'] ?? json['customer_name'] ?? '',
      brokerId: json['lead_owner'] ?? json['broker_id']?.toString() ?? '',

      projectId: json['custom_interested_project'] != null
          ? [json['custom_interested_project'].toString()]
          : (json['project_id'] is List
                ? (json['project_id'] as List).map((e) => e.toString()).toList()
                : []),

      budget: (json['budget'] ?? json['annual_revenue'] ?? 0).toInt(),
      configuration: json['custom_configuration'] != null
          ? [json['custom_configuration'].toString()]
          : (json['configuration'] is List
              ? (json['configuration'] as List).map((e) => e.toString()).toList()
              : []),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : (json['creation'] != null
                ? DateTime.parse(json['creation'])
                : null),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : (json['modified'] != null
                ? DateTime.parse(json['modified'])
                : null),
      locationCoordinates: json['location_coordinates']?.toString(),

      // Custom fields
      customOccupation: json['custom_occupation']?.toString(),
      customStages: json['custom_stages']?.toString(),
      customRepeatCustomer: json['custom_repeat_customer']?.toString(),
      customLeadQuality: (json['custom_lead_quality'] as num?)?.toDouble(),
      customTagging: json['custom_tagging']?.toString(),
      customLatestVisitStatus: json['custom_latest_visit_status']?.toString(),
      customLeadStatus: json['custom_lead_status']?.toString(),
      customLeadDate: json['custom_lead_date']?.toString(),
      customRented: json['custom_rented']?.toInt(),
      customOwned: json['custom_owned']?.toInt(),
      customParentalfriend: json['custom_parentalfriend']?.toInt(),
      customCurrentResidenceType: json['custom_current_residence_type']?.toString(),
      customConfiguration: json['custom_configuration']?.toString(),
      customLookingForPropertyType: json['custom_looking_for_property_type']?.toString(),
      customFinancingDetails: json['custom_financing_details']?.toString(),
      customBudgetMin: json['custom_budget_min']?.toString(),
      customBudgetMax: json['custom_budget_max']?.toString(),
      customExpectedTimeOfPurchase: json['custom_expected_time_of_purchase']?.toString(),
      customPurposeOfPurchase: json['custom_purpose_of_purchase']?.toString(),
      customRemark: json['custom_remark']?.toString(),
      customInterestedProject: json['custom_interested_project']?.toString(),
      customPreferredContactMethod: json['custom_preferred_contact_method']?.toString(),
      customPostalCode: json['custom_postal_code']?.toString(),
      customAttendedBy: json['custom_attended_by']?.toString(),
      customSalesManager: json['custom_sales_manager']?.toString(),
      customSourceType: json['custom_source_type']?.toString(),
      isDigital: json['is_digital']?.toInt(),
      isReference: json['is_reference']?.toInt(),
      isDataCalling: json['is_data_calling']?.toInt(),
      isRetail: json['is_retail']?.toInt(),
      isUnderConstruction: json['is_under_construction']?.toInt(),
      isRental: json['is_rental']?.toInt(),
      isReadyToMove: json['is_ready_to_move']?.toInt(),
      reqCallingSupport: json['req_calling_support']?.toInt(),
      reqDigitalKit: json['req_digital_kit']?.toInt(),
      reqStandees: json['req_standees']?.toInt(),
      reqSmsBlast: json['req_sms_blast']?.toInt(),
      reqWhatsappBlast: json['req_whatsapp_blast']?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'first_name': firstName,
      'last_name': lastName,
      'customer_name': customerName,
      'mobile_no': customerPhone,
      'email_id': emailId,
      'lead_owner': brokerId,
      'project_id': projectId,
      'status': status,
      'budget': budget,
      'configuration': configuration,
      'notes': notes.map((n) => n.toJson()).toList(),
      'source': source,
      'custom_source_type': customSourceType,
      'location_coordinates': locationCoordinates,
      'is_digital': isDigital,
      'is_reference': isReference,
      'is_data_calling': isDataCalling,
      'is_retail': isRetail,
      'is_under_construction': isUnderConstruction,
      'is_rental': isRental,
      'is_ready_to_move': isReadyToMove,
      'req_calling_support': reqCallingSupport,
      'req_digital_kit': reqDigitalKit,
      'req_standees': reqStandees,
      'req_sms_blast': reqSmsBlast,
      'req_whatsapp_blast': reqWhatsappBlast,
      // Add custom fields to toJson if needed for sending data back to server
    };
  }
}
