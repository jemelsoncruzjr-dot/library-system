import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../models/borrow_record_model.dart';
import '../services/book_service.dart';
import '../services/borrow_service.dart';

class BorrowReturnPage extends StatefulWidget {
  final bool isAdmin;
  final String currentUserUid;
  final BookModel? initialBook;

  const BorrowReturnPage({
    super.key,
    required this.isAdmin,
    required this.currentUserUid,
    this.initialBook,
  });

  @override
  State<BorrowReturnPage> createState() => _BorrowReturnPageState();
}

class _BorrowReturnPageState extends State<BorrowReturnPage> {
  final BorrowService _borrowService = BorrowService();
  final BookService _bookService = BookService();

  bool _processing = false;

  String _formatDate(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final month = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$month-$day';
  }

  Future<void> _openBorrowDialog({BookModel? preselectedBook}) async {
    final studentUidCtrl = TextEditingController(
      text: widget.isAdmin ? '' : widget.currentUserUid,
    );
    final loanDaysCtrl = TextEditingController(text: '7');
    BookModel? selectedBook = preselectedBook;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Borrow Book'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      StreamBuilder<List<BookModel>>(
                        stream: _bookService.streamBooks(),
                        builder: (context, snap) {
                          final availableBooks = (snap.data ?? [])
                              .where((b) => b.isAvailable)
                              .toList();

                          if (selectedBook != null) {
                            final match = availableBooks
                                .where((b) => b.id == selectedBook!.id)
                                .toList();
                            selectedBook = match.isNotEmpty ? match.first : null;
                          }

                          return DropdownButtonFormField<BookModel>(
                            value: selectedBook,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Select Available Book *',
                            ),
                            items: availableBooks
                                .map(
                                  (b) => DropdownMenuItem<BookModel>(
                                    value: b,
                                    child: Text(
                                      '${b.title} (${b.availableCopies} avail.)',
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setDialogState(() => selectedBook = val),
                            validator: (val) =>
                                val == null ? 'Pumili ng libro' : null,
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      if (widget.isAdmin)
                        TextFormField(
                          controller: studentUidCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Student UID *',
                            hintText: 'Firebase Auth / users doc ID',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      if (widget.isAdmin) const SizedBox(height: 12),
                      TextFormField(
                        controller: loanDaysCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Loan Days (Due Date) *',
                        ),
                        validator: (v) {
                          final days = int.tryParse((v ?? '').trim());
                          if (days == null || days < 1) {
                            return 'Enter >= 1 day';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                  onPressed: () async {
                    if (!formKey.currentState!.validate() ||
                        selectedBook == null) {
                      return;
                    }
                    Navigator.pop(ctx);
                    setState(() => _processing = true);
                    try {
                      await _borrowService.borrowBook(
                        book: selectedBook!,
                        studentUid: widget.isAdmin
                            ? studentUidCtrl.text.trim()
                            : widget.currentUserUid,
                        loanDays: int.parse(loanDaysCtrl.text.trim()),
                        processedByUid:
                            widget.isAdmin ? widget.currentUserUid : null,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Na-record ang paghiram ng libro.'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _processing = false);
                    }
                  },
                  child: const Text('Confirm Borrow'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleReturn(BorrowRecordModel record) async {
    setState(() => _processing = true);
    try {
      await _borrowService.returnBook(
        record: record,
        processedByUid: widget.isAdmin ? widget.currentUserUid : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Naibalik na ang "${record.bookTitle}".'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialBook != null && widget.initialBook!.isAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openBorrowDialog(preselectedBook: widget.initialBook);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.isAdmin
        ? _borrowService.streamActiveBorrows()
        : _borrowService.streamStudentActiveBorrows(widget.currentUserUid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Borrowing & Return'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _processing ? null : () => _openBorrowDialog(),
        icon: const Icon(Icons.library_add),
        label: const Text('Borrow Book'),
      ),
      body: Column(
        children: [
          if (_processing) const LinearProgressIndicator(),
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

                final records = snapshot.data ?? [];
                if (records.isEmpty) {
                  return const Center(
                    child: Text('Walang active borrowed books sa ngayon.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 84),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final rec = records[index];
                    final overdue = rec.isOverdue;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      child: ListTile(
                        title: Row(
                          children: [
                            Expanded(
                              child: Text(
                                rec.bookTitle,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            if (overdue)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'OVERDUE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.red.shade800,
                                  ),
                                ),
                              ),
                          ],
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
                                color: overdue
                                    ? Colors.red.shade700
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        trailing: FilledButton.tonal(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed:
                              _processing ? null : () => _handleReturn(rec),
                          child: const Text('Return'),
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