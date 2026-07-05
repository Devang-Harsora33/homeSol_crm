class SiteVisit {
  final String name;
  final String owner;
  final String creation;
  final String modified;
  final String modifiedBy;
  final int docstatus;
  final int idx;
  final String lead;
  final String project;
  final String remark;
  final String visitDate;
  final String status;
  final String? visitScheduledDatetime;
  final int? presenceOfCp;
  final String? visitDuration;

  final String doctype;

  SiteVisit({
    required this.name,
    required this.owner,
    required this.creation,
    required this.modified,
    required this.modifiedBy,
    required this.docstatus,
    required this.idx,
    required this.lead,
    required this.project,
    required this.remark,
    required this.visitDate,
    required this.status,
    this.visitScheduledDatetime,
    this.presenceOfCp,
    this.visitDuration,
    required this.doctype,
  });

  factory SiteVisit.fromJson(Map<String, dynamic> json) {
    // Handle potential "data" wrapper from some Frappe API responses
    final data = json.containsKey('data') && json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    return SiteVisit(
      name: data['name'] ?? '',
      owner: data['owner'] ?? '',
      creation: data['creation'] ?? '',
      modified: data['modified'] ?? '',
      modifiedBy: data['modified_by'] ?? '',
      docstatus: data['docstatus'] ?? 0,
      idx: data['idx'] ?? 0,
      lead: data['lead'] ?? '',
      project: data['project'] ?? '',
      remark: data['remark'] ?? '',
      visitDate: data['visit_date'] ?? '',
      status: data['status'] ?? '',
      visitScheduledDatetime: data['visit_scheduled_datetime'],
      presenceOfCp: data['presence_of_cp']?.toInt(),
      visitDuration: data['visit_duration']?.toString(),
      doctype: data['doctype'] ?? '',
    );
  }

  bool get isVerified => status == 'Verified';
  String get channelPartner => owner;
}

