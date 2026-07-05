import 'dart:convert';

class SalesTeam {
  final String name;
  final String owner;
  final DateTime creation;
  final DateTime modified;
  final String modifiedBy;
  final int docstatus;
  final int idx;
  final String teamName;
  final String? description;
  final String doctype;
  final List<SalesTeamProject> projects;
  final List<Member> members;

  SalesTeam({
    required this.name,
    required this.owner,
    required this.creation,
    required this.modified,
    required this.modifiedBy,
    required this.docstatus,
    required this.idx,
    required this.teamName,
    this.description,
    required this.doctype,
    required this.projects,
    required this.members,
  });

  factory SalesTeam.fromRawJson(String str) =>
      SalesTeam.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SalesTeam.fromJson(Map<String, dynamic> json) => SalesTeam(
        name: json["name"],
        owner: json["owner"],
        creation: DateTime.tryParse(json["creation"] ?? "") ?? DateTime.now(),
        modified: DateTime.tryParse(json["modified"] ?? "") ?? DateTime.now(),
        modifiedBy: json["modified_by"],
        docstatus: json["docstatus"],
        idx: json["idx"],
        teamName: json["team_name"],
        description: json["description"],
        doctype: json["doctype"],
        projects: List<SalesTeamProject>.from(
          (json["projects"] as List? ?? []).map((x) => SalesTeamProject.fromJson(x)),
        ),
        members:
            List<Member>.from((json["members"] as List? ?? []).map((x) => Member.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "owner": owner,
        "creation": creation.toIso8601String(),
        "modified": modified.toIso8601String(),
        "modified_by": modifiedBy,
        "docstatus": docstatus,
        "idx": idx,
        "team_name": teamName,
        "description": description,
        "doctype": doctype,
        "projects": List<dynamic>.from(projects.map((x) => x.toJson())),
        "members": List<dynamic>.from(members.map((x) => x.toJson())),
      };
}

class Member {
  final String name;
  final String owner;
  final DateTime creation;
  final DateTime modified;
  final String modifiedBy;
  final int docstatus;
  final int idx;
  final String employee;
  final String employeeName;
  final String? userId;
  final String? designation; // Added designation field
  final String role;
  final String parent;
  final String parentfield;
  final String parenttype;
  final String doctype;

  Member({
    required this.name,
    required this.owner,
    required this.creation,
    required this.modified,
    required this.modifiedBy,
    required this.docstatus,
    required this.idx,
    required this.employee,
    required this.employeeName,
    this.userId,
    this.designation, // Added designation to constructor
    required this.role,
    required this.parent,
    required this.parentfield,
    required this.parenttype,
    required this.doctype,
  });

  factory Member.fromRawJson(String str) => Member.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Member.fromJson(Map<String, dynamic> json) => Member(
    name: json["name"],
    owner: json["owner"],
    creation: DateTime.tryParse(json["creation"] ?? "") ?? DateTime.now(),
    modified: DateTime.tryParse(json["modified"] ?? "") ?? DateTime.now(),
    modifiedBy: json["modified_by"],
    docstatus: json["docstatus"],
    idx: json["idx"],
    employee: json["employee"],
    employeeName: json["employee_name"],
    userId: json["user_id"],
    designation: json["designation"], // Added designation fromJson logic
    role: json["role"],
    parent: json["parent"],
    parentfield: json["parentfield"],
    parenttype: json["parenttype"],
    doctype: json["doctype"],
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "owner": owner,
    "creation": creation.toIso8601String(),
    "modified": modified.toIso8601String(),
    "modified_by": modifiedBy,
    "docstatus": docstatus,
    "idx": idx,
    "employee": employee,
    "employee_name": employeeName,
    "user_id": userId,
    "designation": designation, // Added designation toJson logic
    "role": role,
    "parent": parent,
    "parentfield": parentfield,
    "parenttype": parenttype,
    "doctype": doctype,
  };
}

class SalesTeamProject {
  final String name;
  final String owner;
  final DateTime creation;
  final DateTime modified;
  final String modifiedBy;
  final int docstatus;
  final int idx;
  final String projects;
  final String parent;
  final String parentfield;
  final String parenttype;
  final String doctype;

  SalesTeamProject({
    required this.name,
    required this.owner,
    required this.creation,
    required this.modified,
    required this.modifiedBy,
    required this.docstatus,
    required this.idx,
    required this.projects,
    required this.parent,
    required this.parentfield,
    required this.parenttype,
    required this.doctype,
  });

  factory SalesTeamProject.fromRawJson(String str) => SalesTeamProject.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SalesTeamProject.fromJson(Map<String, dynamic> json) => SalesTeamProject(
    name: json["name"],
    owner: json["owner"],
    creation: DateTime.tryParse(json["creation"] ?? "") ?? DateTime.now(),
    modified: DateTime.tryParse(json["modified"] ?? "") ?? DateTime.now(),
    modifiedBy: json["modified_by"],
    docstatus: json["docstatus"],
    idx: json["idx"],
    projects: json["projects"],
    parent: json["parent"],
    parentfield: json["parentfield"],
    parenttype: json["parenttype"],
    doctype: json["doctype"],
  );

  Map<String, dynamic> toJson() => {
    "name": name,
    "owner": owner,
    "creation": creation.toIso8601String(),
    "modified": modified.toIso8601String(),
    "modified_by": modifiedBy,
    "docstatus": docstatus,
    "idx": idx,
    "projects": projects,
    "parent": parent,
    "parentfield": parentfield,
    "parenttype": parenttype,
    "doctype": doctype,
  };
}
