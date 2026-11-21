import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/borrow_record_model.dart';

class BorrowHistoryService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _borrowRecordsRef => _db.collection('borrow_records');

  Stream<List<BorrowRecordModel>> streamBorrowHistory({String? studentUid}) {
    final query = studentUid == null
        ? _borrowRecordsRef
        : _borrowRecordsRef.where('studentUid', isEqualTo: studentUid);

    return query.snapshots().map((snap) {
      final list = <BorrowRecordModel>[];
      for (final doc in snap.docs) {
        final rec = BorrowRecordModel.fromFirestore(doc);
        if (rec.status == 'borrowed' || rec.status == 'returned') {
          list.add(rec);
        }
      }
      list.sort((a, b) {
        final aTime = (a.returnedAt ?? a.borrowedAt ?? a.createdAt)
                ?.millisecondsSinceEpoch ??
            0;
        final bTime = (b.returnedAt ?? b.borrowedAt ?? b.createdAt)
                ?.millisecondsSinceEpoch ??
            0;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }
}
