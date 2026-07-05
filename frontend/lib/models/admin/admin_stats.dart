class AdminUserActivity {
  final String employee;
  final String employeeName;
  final String userId;
  final List<AdminLead> leads;
  final List<AdminSourcing> sourcing;
  final List<AdminChannelPartner> channelPartners;
  final List<AdminCheckin> checkins;
  final List<AdminCheckout> checkouts;
  final List<AdminAttendance> attendance;

  AdminUserActivity({
    required this.employee,
    required this.employeeName,
    required this.userId,
    required this.leads,
    required this.sourcing,
    required this.channelPartners,
    required this.checkins,
    required this.checkouts,
    required this.attendance,
  });

  factory AdminUserActivity.fromJson(Map<String, dynamic> json) {
    return AdminUserActivity(
      employee: json['employee'] ?? '',
      employeeName: json['employee_name'] ?? '',
      userId: json['user_id'] ?? '',
      leads: (json['leads'] as List?)?.map((e) => AdminLead.fromJson(e)).toList() ?? [],
      sourcing: (json['sourcing'] as List?)?.map((e) => AdminSourcing.fromJson(e)).toList() ?? [],
      channelPartners: (json['channel_partners'] as List?)?.map((e) => AdminChannelPartner.fromJson(e)).toList() ?? [],
      checkins: (json['checkins'] as List?)?.map((e) => AdminCheckin.fromJson(e)).toList() ?? [],
      checkouts: (json['checkouts'] as List?)?.map((e) => AdminCheckout.fromJson(e)).toList() ?? [],
      attendance: (json['attendance'] as List?)?.map((e) => AdminAttendance.fromJson(e)).toList() ?? [],
    );
  }
}

class AdminLead {
  final String name;
  final String leadName;
  final String mobileNo;
  final String emailId;
  final String status;
  final String leadOwner;
  final String creation;
  final String customInterestedProject;
  final String source;
  final String? customConfiguration;
  final String? customStages;
  final String? customLeadStatus;
  final List<AdminSiteVisit> siteVisits;
  final List<AdminFollowup> followups;

  AdminLead({
    required this.name,
    required this.leadName,
    required this.mobileNo,
    required this.emailId,
    required this.status,
    required this.leadOwner,
    required this.creation,
    required this.customInterestedProject,
    required this.source,
    this.customConfiguration,
    this.customStages,
    this.customLeadStatus,
    required this.siteVisits,
    required this.followups,
  });

  factory AdminLead.fromJson(Map<String, dynamic> json) {
    return AdminLead(
      name: json['name'] ?? '',
      leadName: json['lead_name'] ?? '',
      mobileNo: json['mobile_no'] ?? '',
      emailId: json['email_id'] ?? '',
      status: json['status'] ?? '',
      leadOwner: json['lead_owner'] ?? '',
      creation: json['creation'] ?? '',
      customInterestedProject: json['custom_interested_project'] ?? '',
      source: json['source'] ?? '',
      customConfiguration: json['custom_configuration'],
      customStages: json['custom_stages'],
      customLeadStatus: json['custom_lead_status'],
      siteVisits: (json['site_visits'] as List?)?.map((e) => AdminSiteVisit.fromJson(e)).toList() ?? [],
      followups: (json['followups'] as List?)?.map((e) => AdminFollowup.fromJson(e)).toList() ?? [],
    );
  }
}

class AdminSiteVisit {
  final String name;
  final String lead;
  final String project;
  final String visitDate;
  final String visitScheduledDatetime;
  final String status;
  final String remark;
  final String owner;
  final String creation;
  final String? visitDuration;

  AdminSiteVisit({
    required this.name,
    required this.lead,
    required this.project,
    required this.visitDate,
    required this.visitScheduledDatetime,
    required this.status,
    required this.remark,
    required this.owner,
    required this.creation,
    this.visitDuration,
  });

  factory AdminSiteVisit.fromJson(Map<String, dynamic> json) {
    return AdminSiteVisit(
      name: json['name'] ?? '',
      lead: json['lead'] ?? '',
      project: json['project'] ?? '',
      visitDate: json['visit_date'] ?? '',
      visitScheduledDatetime: json['visit_scheduled_datetime'] ?? '',
      status: json['status'] ?? '',
      remark: json['remark'] ?? '',
      owner: json['owner'] ?? '',
      creation: json['creation'] ?? '',
      visitDuration: json['visit_duration'],
    );
  }
}

class AdminFollowup {
  final String name;
  final String parent;
  final String followUpDate;
  final String type;
  final String status;
  final String remarks;
  final String assignedTo;
  final String? nextFollowUp;

  AdminFollowup({
    required this.name,
    required this.parent,
    required this.followUpDate,
    required this.type,
    required this.status,
    required this.remarks,
    required this.assignedTo,
    this.nextFollowUp,
  });

  factory AdminFollowup.fromJson(Map<String, dynamic> json) {
    return AdminFollowup(
      name: json['name'] ?? '',
      parent: json['parent'] ?? '',
      followUpDate: json['follow_up_date'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      remarks: json['remarks'] ?? '',
      assignedTo: json['assigned_to'] ?? '',
      nextFollowUp: json['next_follow_up'],
    );
  }
}

class AdminSourcing {
  final String name;
  final String owner;
  final String salesPartner;
  final String contactPersonMet;
  final String mobileNumber;
  final String visitStatus;
  final String visitDate;
  final String remark;
  final String location;
  final String creation;
  final String? meetingType;

  AdminSourcing({
    required this.name,
    required this.owner,
    required this.salesPartner,
    required this.contactPersonMet,
    required this.mobileNumber,
    required this.visitStatus,
    required this.visitDate,
    required this.remark,
    required this.location,
    required this.creation,
    this.meetingType,
  });

  factory AdminSourcing.fromJson(Map<String, dynamic> json) {
    return AdminSourcing(
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      salesPartner: json['sales_partner'] ?? '',
      contactPersonMet: json['contact_person_met'] ?? '',
      mobileNumber: json['mobile_number'] ?? '',
      visitStatus: json['visit_status'] ?? '',
      visitDate: json['visit_date'] ?? '',
      remark: json['remark'] ?? '',
      location: json['location'] ?? '',
      creation: json['creation'] ?? '',
      meetingType: json['meeting_type'],
    );
  }
}

class AdminChannelPartner {
  final String name;
  final String partnerName;
  final String partnerType;
  final String contactNo;
  final String territory;
  final String owner;
  final String creation;
  final String status;

  AdminChannelPartner({
    required this.name,
    required this.partnerName,
    required this.partnerType,
    required this.contactNo,
    required this.territory,
    required this.owner,
    required this.creation,
    required this.status,
  });

  factory AdminChannelPartner.fromJson(Map<String, dynamic> json) {
    return AdminChannelPartner(
      name: json['name'] ?? '',
      partnerName: json['partner_name'] ?? '',
      partnerType: json['partner_type'] ?? '',
      contactNo: json['contact_no'] ?? '',
      territory: json['territory'] ?? '',
      owner: json['owner'] ?? '',
      creation: json['creation'] ?? '',
      status: json['status'] ?? '',
    );
  }
}

class AdminCheckin {
  final String name;
  final String employee;
  final String logType;
  final String time;
  final double latitude;
  final double longitude;
  final String deviceId;
  final String customRemark;

  AdminCheckin({
    required this.name,
    required this.employee,
    required this.logType,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.deviceId,
    required this.customRemark,
  });

  factory AdminCheckin.fromJson(Map<String, dynamic> json) {
    return AdminCheckin(
      name: json['name'] ?? '',
      employee: json['employee'] ?? '',
      logType: json['log_type'] ?? '',
      time: json['time'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      deviceId: json['device_id'] ?? '',
      customRemark: json['custom_remark'] ?? '',
    );
  }
}

class AdminCheckout {
  final String name;
  final String employee;
  final String logType;
  final String time;
  final double latitude;
  final double longitude;
  final String deviceId;

  AdminCheckout({
    required this.name,
    required this.employee,
    required this.logType,
    required this.time,
    required this.latitude,
    required this.longitude,
    required this.deviceId,
  });

  factory AdminCheckout.fromJson(Map<String, dynamic> json) {
    return AdminCheckout(
      name: json['name'] ?? '',
      employee: json['employee'] ?? '',
      logType: json['log_type'] ?? '',
      time: json['time'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
      deviceId: json['device_id'] ?? '',
    );
  }
}

class AdminAttendance {
  final String name;
  final String employee;
  final String attendanceDate;
  final String status;
  final String shift;
  final double workingHours;
  final int docstatus;

  AdminAttendance({
    required this.name,
    required this.employee,
    required this.attendanceDate,
    required this.status,
    required this.shift,
    required this.workingHours,
    required this.docstatus,
  });

  factory AdminAttendance.fromJson(Map<String, dynamic> json) {
    return AdminAttendance(
      name: json['name'] ?? '',
      employee: json['employee'] ?? '',
      attendanceDate: json['attendance_date'] ?? '',
      status: json['status'] ?? '',
      shift: json['shift'] ?? '',
      workingHours: (json['working_hours'] ?? 0.0).toDouble(),
      docstatus: json['docstatus'] ?? 0,
    );
  }
}
