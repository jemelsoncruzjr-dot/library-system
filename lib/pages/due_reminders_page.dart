import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/borrow_record_model.dart';
import '../services/due_reminder_service.dart';

class DueRemindersPage extends StatefulWidget {
  final bool isAdmin;
  final String currentUserUid;
  final int reminderDays;

  const DueRemindersPage({
    super.key,
    required this.isAdmin,
    required this.currentUserUid,
    this.reminderDays = 2,
  });

  @override
  State<DueRemindersPage> createState() => _DueRemindersPageState();
}

class _DueRemindersPageState extends State<DueRemindersPage> {
  final DueReminderService _reminderService = DueReminderService();
  String _filter = 'all';

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
        ? _reminderService.streamBorrowedForAlerts()
        : _reminderService.streamBorrowedForAlerts(
            studentUid: widget.currentUserUid,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Due Reminders & Overdue'),
      ),
      body: StreamBuilder<List<BorrowRecordModel>>(
        stream: stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allBorrowed = snapshot.data ?? [];
          final overdueList =
              allBorrowed.where((r) => r.isOverdue).toList();
          final dueSoonList = allBorrowed
              .where(
                (r) => _reminderService.isDueSoon(
                  r,
                  reminderDays: widget.reminderDays,
                ),
              )
              .toList();

          final visibleList = switch (_filter) {
            'overdue' => overdueList,
            'due_soon' => dueSoonList,
            _ => allBorrowed
                .where(
                  (r) =>
                      r.isOverdue ||
                      _reminderService.isDueSoon(
                        r,
                        reminderDays: widget.reminderDays,
                      ),
                )
                .toList(),
          };

          return Column(
            children: [
              if (overdueList.isNotEmpty || dueSoonList.isNotEmpty)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: overdueList.isNotEmpty
                        ? Colors.red.shade50
                        : Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: overdueList.isNotEmpty
                          ? Colors.red.shade200
                          : Colors.amber.shade200,
                    ),
                  ),
                  child: Text(
                    overdueList.isNotEmpty
                        ? 'May ${overdueList.length} overdue at ${dueSoonList.length} due soon na libro.'
                        : 'May ${dueSoonList.length} libro na malapit na ang due date.',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: overdueList.isNotEmpty
                          ? Colors.red.shade900
                          : Colors.amber.shade900,
                    ),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('Alerts (${overdueList.length + dueSoonList.length})'),
                      selected: _filter == 'all',
                      onSelected: (_) => setState(() => _filter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Overdue (${overdueList.length})'),
                      selected: _filter == 'overdue',
                      onSelected: (_) => setState(() => _filter = 'overdue'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Due Soon (${dueSoonList.length})'),
                      selected: _filter == 'due_soon',
                      onSelected: (_) => setState(() => _filter = 'due_soon'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visibleList.isEmpty
                    ? const Center(
                        child: Text('Walang due reminder o overdue sa ngayon.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: visibleList.length,
                        itemBuilder: (context, index) {
                          final rec = visibleList[index];
                          final isOverdue = rec.isOverdue;
                          final badgeText = _reminderService.reminderLabel(
                            rec,
                            reminderDays: widget.reminderDays,
                          );

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              title: Text(
                                rec.bookTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (widget.isAdmin)
                                    Text(
                                      'Student: ${rec.studentName}${rec.studentLrn.isNotEmpty ? ' (LRN: ${rec.studentLrn})' : ''}',
                                    ),
                                  Text('Borrowed: ${_formatDate(rec.borrowedAt)}'),
                                  Text(
                                    'Due Date: ${_formatDate(rec.dueDate)}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isOverdue
                                          ? Colors.red.shade700
                                          : Colors.amber.shade900,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isOverdue
                                      ? Colors.red.shade100
                                      : Colors.amber.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isOverdue
                                        ? Colors.red.shade900
                                        : Colors.amber.shade900,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}