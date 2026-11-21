import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/borrow_record_model.dart';
import '../services/borrow_history_service.dart';

class BorrowHistoryPage extends StatefulWidget {
  final bool isAdmin;
  final String currentUserUid;

  const BorrowHistoryPage({
    super.key,
    required this.isAdmin,
    required this.currentUserUid,
  });

  @override
  State<BorrowHistoryPage> createState() => _BorrowHistoryPageState();
}

class _BorrowHistoryPageState extends State<BorrowHistoryPage> {
  final BorrowHistoryService _historyService = BorrowHistoryService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _statusFilter = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.isAdmin
        ? _historyService.streamBorrowHistory()
        : _historyService.streamBorrowHistory(studentUid: widget.currentUserUid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrow History'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: widget.isAdmin
                    ? 'Search book title, student name, or LRN...'
                    : 'Search book title...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _statusFilter == 'all',
                  onSelected: (_) => setState(() => _statusFilter = 'all'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Borrowed'),
                  selected: _statusFilter == 'borrowed',
                  onSelected: (_) => setState(() => _statusFilter = 'borrowed'),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Returned'),
                  selected: _statusFilter == 'returned',
                  onSelected: (_) => setState(() => _statusFilter = 'returned'),
                ),
              ],
            ),
          ),
          const Divider(height: 12),
          Expanded(
            child: StreamBuilder<List<BorrowRecordModel>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allRecords = snapshot.data ?? [];
                final q = _searchQuery.trim().toLowerCase();

                final filtered = allRecords.where((rec) {
                  final matchesStatus =
                      _statusFilter == 'all' || rec.status == _statusFilter;
                  final matchesQuery = q.isEmpty ||
                      rec.bookTitle.toLowerCase().contains(q) ||
                      (widget.isAdmin &&
                          (rec.studentName.toLowerCase().contains(q) ||
                              rec.studentLrn.toLowerCase().contains(q)));
                  return matchesStatus && matchesQuery;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                    child: Text('Walang record sa history para sa filter na ito.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final rec = filtered[index];
                    final isReturned = rec.isReturned;
                    final overdue = rec.isOverdue;

                    final statusText = isReturned
                        ? 'RETURNED'
                        : (overdue ? 'OVERDUE' : 'BORROWED');

                    final badgeBg = isReturned
                        ? Colors.green.shade100
                        : (overdue ? Colors.red.shade100 : Colors.blue.shade100);

                    final badgeFg = isReturned
                        ? Colors.green.shade900
                        : (overdue ? Colors.red.shade900 : Colors.blue.shade900);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Text(
                          rec.bookTitle,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (widget.isAdmin)
                              Text(
                                'Student: ${rec.studentName}${rec.studentLrn.isNotEmpty ? ' (LRN: ${rec.studentLrn})' : ''}',
                              ),
                            Text('Borrowed: ${_formatDate(rec.borrowedAt)}'),
                            Text('Due Date: ${_formatDate(rec.dueDate)}'),
                            if (isReturned)
                              Text('Returned: ${_formatDate(rec.returnedAt)}'),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: badgeFg,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}