import 'package:flutter/material.dart';
import '../services/library_reports_service.dart';

class LibraryReportsPage extends StatefulWidget {
  const LibraryReportsPage({super.key});

  @override
  State<LibraryReportsPage> createState() => _LibraryReportsPageState();
}

class _LibraryReportsPageState extends State<LibraryReportsPage> {
  final LibraryReportsService _reportsService = LibraryReportsService();
  late Future<LibraryStatsSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = _reportsService.loadSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _summaryFuture = _reportsService.loadSummary();
    });
    await _summaryFuture;
  }

  Widget _statCard(String label, String value, {Color? accent}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Stats'),
        actions: [
          IconButton(
            tooltip: 'Refresh Stats',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<LibraryStatsSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final s = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Text(
                  'Library Overview',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 1.55,
                  children: [
                    _statCard('Book Titles', '${s.totalBookTitles}'),
                    _statCard(
                      'Available Copies',
                      '${s.availableCopies} / ${s.totalBookCopies}',
                    ),
                    _statCard('Active Borrowed', '${s.activeBorrowed}'),
                    _statCard(
                      'Overdue Books',
                      '${s.overdueCount}',
                      accent: s.overdueCount > 0 ? Colors.red.shade700 : null,
                    ),
                    _statCard('Pending Reservations', '${s.pendingReservations}'),
                    _statCard('Returned Records', '${s.returnedCount}'),
                    _statCard("Today's Visits", '${s.todayVisits}'),
                    _statCard('Validated Students', '${s.validatedStudents}'),
                  ],
                ),
                const SizedBox(height: 18),
                const Text(
                  'Most Borrowed Books',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (s.topBorrowedBooks.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Walang borrow records pa para sa tally.'),
                    ),
                  )
                else
                  ...s.topBorrowedBooks.asMap().entries.map((entry) {
                    final rank = entry.key + 1;
                    final item = entry.value;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('#$rank')),
                        title: Text(
                          item.bookTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        trailing: Text(
                          '${item.borrowCount} ${item.borrowCount == 1 ? 'borrow' : 'borrows'}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}