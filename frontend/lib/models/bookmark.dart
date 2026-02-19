class Bookmark {
  final List<String> projects;
  final List<String> developers;

  Bookmark({required this.projects, required this.developers});

  factory Bookmark.fromJson(Map<String, dynamic> json) {
    return Bookmark(
      projects: json['projects'] != null
          ? List<String>.from(json['projects'])
          : [],
      developers: json['developers'] != null
          ? List<String>.from(json['developers'])
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {'projects': projects, 'developers': developers};
  }

  bool get isEmpty => projects.isEmpty && developers.isEmpty;
  bool get hasProjects => projects.isNotEmpty;
  bool get hasDevelopers => developers.isNotEmpty;
}
