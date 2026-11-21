import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../models/borrow_record_model.dart';
import '../services/book_service.dart';
import '../services/reservation_service.dart';

class ReservationsPage extends StatefulWidget {
  final bool isAdmin;
  final String currentUserUid;
  final BookModel? initialBook;

  const ReservationsPage({
    super.key,
    required this.isAdmin,
    required this.currentUserUid,
    this.initialBook,
  });

  @override
  State<ReservationsPage> createState() => _ReservationsPageState();
}

class _ReservationsPageState extends State<ReservationsPage> {
  final ReservationService _reservationService = ReservationService();
  final BookService _bookService = BookService();

  bool _processing = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isAdmin &&
        widget.initialBook != null &&
        widget.initialBook!.isAvailable) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openReserveDialog(preselectedBook: widget.initialBook);
      });
    }
  }

  Future<void> _openReserveDialog({BookModel? preselectedBook}) async {
    BookModel? selectedBook = preselectedBook;
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Reserve Book'),
              content: Form(
                key: formKey,
                child: StreamBuilder<List<BookModel>>(
                  stream: _bookService.streamBooks(),
                  builder: (context, snap) {
                    final availableBooks =
                        (snap.data ?? []).where((b) => b.isAvailable).toList();

                    if (selectedBook != null) {
                      final match = availableBooks
                          .where((b) => b.id == selectedBook!.id)
                          .toList();
                      selectedBook = match.isNotEmpty ? match.first : null;
                    }

                    return DropdownButtonFormField<BookModel>(
                      initialValue: selectedBook,
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
                      await _reservationService.reserveBook(
                        book: selectedBook!,
                        studentUid: widget.currentUserUid,
                      );
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Na-save ang reservation mo.'),
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
                  child: const Text('Confirm Reserve'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _handleCancel(BorrowRecordModel record) async {
    setState(() => _processing = true);
    try {
      await _reservationService.cancelReservation(record: record);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Na-cancel ang reservation para sa "${record.bookTitle}".'),
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

  Future<void> _handleRelease(BorrowRecordModel record) async {
    setState(() => _processing = true);
    try {
      await _reservationService.releaseReservationToBorrow(
        record: record,
        processedByUid: widget.currentUserUid,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Na-release na bilang borrowed ang "${record.bookTitle}".'),
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
  Widget build(BuildContext context) {
    final stream = widget.isAdmin
        ? _reservationService.streamReservations()
        : _reservationService.streamReservations(
            studentUid: widget.currentUserUid,
          );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reservations'),
      ),
      floatingActionButton: !widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: _processing ? null : () => _openReserveDialog(),
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Reserve Book'),
            )
          : null,
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
                    child: Text('Walang pending reservations sa ngayon.'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 84),
                  itemCount: records.length,
                  itemBuilder: (context, index) {
                    final rec = records[index];

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
                            const Text('Status: Pending Reservation'),
                          ],
                        ),
                        trailing: widget.isAdmin
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  FilledButton.tonal(
                                    style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                                    onPressed: _processing
                                        ? null
                                        : () => _handleRelease(rec),
                                    child: const Text('Release'),
                                  ),
                                  const SizedBox(width: 6),
                                  TextButton(
                                    onPressed: _processing
                                        ? null
                                        : () => _handleCancel(rec),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              )
                            : TextButton(
                                onPressed:
                                    _processing ? null : () => _handleCancel(rec),
                                child: const Text('Cancel'),
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