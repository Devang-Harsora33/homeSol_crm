class ConstructionFinanceApplication {
  final String name;
  final String owner;
  final String creation;
  final String modified;
  final String modifiedBy;
  final int docstatus;
  final int idx;
  final String developer;
  final String project;
  final String meetingType;
  final String meetingSchedule;
  final double fundRequirement;
  final String? submissionLinked;
  final String doctype;
  final String status;
  final String? developerName;

  ConstructionFinanceApplication({
    required this.name,
    required this.owner,
    required this.creation,
    required this.modified,
    required this.modifiedBy,
    required this.docstatus,
    required this.idx,
    required this.developer,
    required this.project,
    required this.meetingType,
    required this.meetingSchedule,
    required this.fundRequirement,
    this.submissionLinked,
    required this.doctype,
    required this.status,
    this.developerName,
  });

  factory ConstructionFinanceApplication.fromJson(Map<String, dynamic> json) {
    return ConstructionFinanceApplication(
      name: json['name'] ?? '',
      owner: json['owner'] ?? '',
      creation: json['creation'] ?? '',
      modified: json['modified'] ?? '',
      modifiedBy: json['modified_by'] ?? '',
      docstatus: json['docstatus'] ?? 0,
      idx: json['idx'] ?? 0,
      developer: json['developer'] ?? '',
      project: json['project'] ?? '',
      meetingType: json['meeting_type'] ?? '',
      meetingSchedule: json['meeting_schedule'] ?? '',
      fundRequirement: (json['fund_requirement'] ?? 0.0).toDouble(),
      submissionLinked: json['submission_linked'],
      doctype: json['doctype'] ?? '',
      status: json['status'] ?? 'Draft',
      developerName: json['developer_name'],
    );
  }
}
