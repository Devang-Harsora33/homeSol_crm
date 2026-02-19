import 'package:flutter/material.dart';
import '../models/developer.dart';
import '../models/project.dart';
import '../components/developer_detail_popup.dart';

class DeveloperDetailPage extends StatelessWidget {
  final Developer developer;
  final List<Project> projects;

  const DeveloperDetailPage({
    super.key,
    required this.developer,
    required this.projects,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: DeveloperDetailPopup(developer: developer, projects: projects),
      ),
    );
  }
}