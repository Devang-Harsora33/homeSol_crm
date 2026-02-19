class FollowUp {
  final String name;
  final String? followUpDate;
  final String? status;
  final String? type;
  final String? remarks;
  final String? nextFollowUp;
  final String? parent;
  final String? assignedTo;
  final String? leadId;
  final String? leadName;
  final String? mobileNo;
  final String? leadOwner;
  final String? creation; // New field
  final String? modified; // New field

  FollowUp({
    required this.name,
    this.followUpDate,
    this.status,
    this.type,
    this.remarks,
    this.nextFollowUp,
    this.parent,
    this.assignedTo,
    this.leadId,
    this.leadName,
    this.mobileNo,
    this.leadOwner,
    this.creation, // New field
    this.modified, // New field
  });

  factory FollowUp.fromJson(Map<String, dynamic> json) {
    return FollowUp(
      name: json['name'] as String,
      followUpDate: json['follow_up_date'] as String?,
      status: json['status'] as String?,
      type: json['type'] as String?,
      remarks: json['remarks'] as String?,
      nextFollowUp: json['next_follow_up'] as String?,
      parent: json['parent'] as String?,
      assignedTo: json['assigned_to'] as String?,
      leadId: json['lead_id'] as String?,
      leadName: json['lead_name'] as String?,
      mobileNo: json['mobile_no'] as String?,
      leadOwner: json['owner'] as String?,
      creation: json['creation'] as String?, // New field from JSON
      modified: json['modified'] as String?, // New field from JSON
    );
  }
}
