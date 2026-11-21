import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/borrow_record_model.dart';

class DueReminderService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _borrowRecordsRef => _db.collection('borrow_records');

  bool isDueSoon(BorrowRecordModel record, {int reminderDays = 2}) {
    if (!record.isBorrowed || record.dueDate == null) return false;
    if (record.isOverdue) return false;

    final now = DateTime.now();
    final due = record.dueDate!.toDate();
    final diffHours = due.difference(now).inHours;
    return diffHours <= reminderDays * 24;
  }

  int daysOverdue(BorrowRecordModel record) {
    if (!record.isOverdue || record.dueDate == null) return 0;
    final diffDays = DateTime.now().difference(record.dueDate!.toDate()).inDays;
    return diffDays < 1 ? 1 : diffDays;
  }

  String reminderLabel(BorrowRecordModel record, {int reminderDays = 2}) {
    if (record.isOverdue) {
      final d = daysOverdue(record);
      return 'Overdue ($d ${d == 1 ? 'day' : 'days'})';
    }
    if (isDueSoon(record, reminderDays: reminderDays)) {
      return 'Due soon';
    }
    return 'On track';
  }

  Stream<List<BorrowRecordModel>> streamBorrowedForAlerts({
    String? studentUid,
  }) {
    final query = studentUid == null
        ? _borrowRecordsRef.where('status', isEqualTo: 'borrowed')
        : _borrowRecordsRef
            .where('studentUid', isEqualTo: studentUid)
            .where('status', isEqualTo: 'borrowed');

    return query.snapshots().map((snap) {
      final list = <BorrowRecordModel>[];
      for (final doc in snap.docs) {
        list.add(BorrowRecordModel.fromFirestore(doc));
      }
      list.sort((a, b) {
        final aTime = a.dueDate?.millisecondsSinceEpoch ?? 0;
        final bTime = b.dueDate?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
      return list;
    });
  }
}