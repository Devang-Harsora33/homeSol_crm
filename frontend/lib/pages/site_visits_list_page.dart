import 'package:flutter/material.dart';
import '../models/site_visit.dart';
import '../services/api_service.dart';
import 'create_site_visit_page.dart';
import 'site_visit_detail_page.dart';

class SiteVisitsListPage extends StatefulWidget {
  const SiteVisitsListPage({super.key});

  @override
  State<SiteVisitsListPage> createState() => _SiteVisitsListPageState();
}



class _EmptyState extends StatelessWidget {
  final VoidCallback onPressed;
  const _EmptyState({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_off, size: 100, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No site visits found.', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onPressed,
            child: const Text('Create Site Visit'),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorState({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 100, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error: $error', style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _SiteVisitsListPageState extends State<SiteVisitsListPage> {
  late Future<List<SiteVisit>> _siteVisitsFuture;

  @override
  void initState() {
    super.initState();
    _siteVisitsFuture = ApiService.fetchSiteVisits();
  }

  void _refreshSiteVisits() {
    setState(() {
      _siteVisitsFuture = ApiService.fetchSiteVisits();
    });
  }

  void _goToCreatePage() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CreateSiteVisitScreen()),
    );
    if (result == true) {
      _refreshSiteVisits();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Site Visits'),
        backgroundColor: const Color(0xFF6f5d00),
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refreshSiteVisits(),
        child: FutureBuilder<List<SiteVisit>>(
        future: _siteVisitsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return _ErrorState(error: snapshot.error.toString(), onRetry: _refreshSiteVisits);
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return _EmptyState(onPressed: _goToCreatePage);
          } else {
            final siteVisits = snapshot.data!;
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: siteVisits.length,
              itemBuilder: (context, index) {
                final visit = siteVisits[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8.0),
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => SiteVisitDetailPage(siteVisit: visit),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border(
                          left: BorderSide(
                            color: visit.isVerified == 1 ? Colors.green : Colors.orange,
                            width: 5,
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'visit_title_${visit.name}',
                              child: Material(
                                color: Colors.transparent,
                                child: Text(
                                  visit.lead,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.business, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(child: Text(visit.project)),
                              ],
                            ),
                            const SizedBox(height: 4),
                             Row(
                              children: [
                                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Expanded(child: Text(visit.channelPartner)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                                const SizedBox(width: 8),
                                Text(visit.visitDate),
                              ],
                            ),
                            const SizedBox(height: 8),
                             Align(
                              alignment: Alignment.centerRight,
                              child: Chip(
                                label: Text(visit.status),
                                backgroundColor: visit.status == 'Scheduled'
                                    ? Colors.blue.shade100
                                    : visit.status == 'Completed'
                                        ? Colors.green.shade100
                                        : Colors.red.shade100,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          }
        },
      ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreatePage,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
