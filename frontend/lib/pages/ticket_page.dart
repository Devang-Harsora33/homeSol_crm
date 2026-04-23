import 'package:Homesol/models/ticket.dart';
import 'package:Homesol/services/apis/tickets/ticker_service.dart';
import 'package:flutter/material.dart';
import 'ticket_creation_page.dart'; 
import 'ticket_detail_page.dart';

class TicketsListPage extends StatefulWidget {
  const TicketsListPage({super.key});

  @override
  State<TicketsListPage> createState() => _TicketsListPageState();
}

class _TicketsListPageState extends State<TicketsListPage> {
  Future<List<Ticket>>? _future;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _future = TicketService.syncMyTickets(forceRefresh: true);
    });
  }

  List<Ticket> _filteredTickets(List<Ticket> tickets) {
    if (_searchQuery.isEmpty) {
      return tickets;
    }
    final query = _searchQuery.toLowerCase();
    return tickets.where((ticket) {
      return ticket.description.toLowerCase().contains(query) ||
          ticket.category.toLowerCase().contains(query) ||
          ticket.priority.toLowerCase().contains(query) ||
          ticket.status.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Tickets', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: isDark ? Colors.grey[850] : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _load();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSearchAndFilterCard(),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<List<Ticket>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListView.separated(
                        itemCount: 5, // Display 5 skeleton cards
                        itemBuilder: (context, index) => const _TicketCardSkeleton(),
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red.withOpacity(0.7),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Error loading tickets',
                              style: TextStyle(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              snapshot.error.toString(),
                              style: TextStyle(
                                color: (isDark ? Colors.white : Colors.black).withOpacity(0.7),
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(onPressed: _load, child: const Text('Retry')),
                          ],
                        ),
                      );
                    }
                    final myTickets = snapshot.data ?? [];

                    if (myTickets.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: _load,
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          children: [
                            const SizedBox(height: 60),
                            Icon(
                              Icons.confirmation_number_outlined,
                              size: 56,
                              color: theme.colorScheme.primary.withOpacity(0.6),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No tickets yet',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Tap + to raise a ticket or pull to refresh.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final filteredTickets = _filteredTickets(myTickets);

                    return RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 8),
                        itemBuilder: (context, index) {
                          final t = filteredTickets[index];
                          return _TicketCard(ticket: t);
                        },
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemCount: filteredTickets.length,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 70.0),
        child: FloatingActionButton(
          heroTag: null,
          backgroundColor: const Color(0xFF1A1A1A),
          onPressed: () async {
            // Navigate to the new ticket creation page
            final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TicketCreationPage()));
            // Reload list after returning from creation page if result is true (success)
            if (result == true) {
              await _load();
              if (mounted) setState(() {});
            }
          },
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterCard() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: TextStyle(fontSize: 14, color: isDark ? Colors.white : Colors.black87),
        decoration: InputDecoration(
          hintText: 'Search tickets...',
          hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400, fontWeight: FontWeight.w400),
          prefixIcon: Icon(Icons.search_rounded, color: Colors.grey.shade400, size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  child: Icon(Icons.close_rounded, color: Colors.grey.shade400, size: 18),
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _TicketCard extends StatelessWidget {
  final Ticket ticket;

  const _TicketCard({required this.ticket});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const kAccent = Color(0xFF675D40);

    return Container(
      margin: const EdgeInsets.only(bottom: 2), // small margin since parent uses separated
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TicketDetailPage(ticket: ticket),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kAccent.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: kAccent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              ticket.description,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                          _StatusPill(
                            status: ticket.status.isEmpty ? 'open' : ticket.status,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _detailBadge(Icons.category_rounded, ticket.category),
                          const SizedBox(width: 8),
                          _detailBadge(Icons.flag_rounded, ticket.priority),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailBadge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _TicketCardSkeleton extends StatelessWidget {
  const _TicketCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color? skeletonColor = isDark ? Colors.grey[800] : Colors.grey[300];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: skeletonColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 120, height: 16, color: skeletonColor),
                    const Spacer(),
                    Container(width: 50, height: 20, decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(20))),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(width: 70, height: 20, decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(8))),
                    const SizedBox(width: 8),
                    Container(width: 70, height: 20, decoration: BoxDecoration(color: skeletonColor, borderRadius: BorderRadius.circular(8))),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;
  const _StatusPill({required this.status});
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color bg;
    Color fg;
    switch (status) {
      case 'resolved':
        bg = Colors.green.withOpacity(0.15);
        fg = Colors.green.shade700;
        break;
      case 'in_progress':
        bg = Colors.blue.withOpacity(0.15);
        fg = Colors.blue.shade700;
        break;
      case 'cancelled':
        bg = Colors.red.withOpacity(0.15);
        fg = Colors.red.shade700;
        break;
      default:
        bg = theme.colorScheme.primary.withOpacity(0.12);
        fg = theme.colorScheme.primary;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: theme.textTheme.bodySmall?.copyWith(color: fg),
      ),
    );
  }
}

