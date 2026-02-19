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
    required this.doctype,
  });

  factory SiteVisit.fromJson(Map<String, dynamic> json) {
    return SiteVisit(
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      creation: json['creation'] ?? '',
      modified: json['modified'] ?? '',
      modifiedBy: json['modified_by'] ?? '',
      docstatus: json['docstatus'] ?? 0,
      idx: json['idx'] ?? 0,
      lead: json['lead'] ?? '',
      project: json['project'] ?? '',
      remark: json['remark'] ?? '',
      visitDate: json['visit_date'] ?? '',
      status: json['status'] ?? '',
      visitScheduledDatetime: json['visit_scheduled_datetime'],
      doctype: json['doctype'] ?? '',
    );
  }
}

