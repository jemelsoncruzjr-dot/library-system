import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';
import '../models/borrow_record_model.dart';
import 'borrow_service.dart';
import 'student_name.dart';

class ReservationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BorrowService _borrowService = BorrowService();

  CollectionReference<Map<String, dynamic>> get _booksRef => _db.collection('books');

  CollectionReference<Map<String, dynamic>> get _borrowRecordsRef => _db.collection('borrow_records');

  CollectionReference<Map<String, dynamic>> get _usersRef => _db.collection('users');

  Stream<List<BorrowRecordModel>> streamReservations({String? studentUid}) {
    final query = studentUid == null
        ? _borrowRecordsRef.where('status', isEqualTo: 'pending_reservation')
        : _borrowRecordsRef
            .where('studentUid', isEqualTo: studentUid)
            .where('status', isEqualTo: 'pending_reservation');

    return query.snapshots().map((snap) {
      final list = <BorrowRecordModel>[];
      for (final doc in snap.docs) {
        list.add(BorrowRecordModel.fromFirestore(doc));
      }
      list.sort((a, b) {
        final aTime = a.createdAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.createdAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  Future<void> reserveBook({
    required BookModel book,
    required String studentUid,
    int maxActiveItems = 3,
  }) async {
    final userSnap = await _usersRef.doc(studentUid).get();
    if (!userSnap.exists) {
      throw Exception('Hindi nahanap ang student record.');
    }

    final userData =
        (userSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    if (!_borrowService.isStudentValidated(userData)) {
      throw Exception(
        'Hindi pa validated ang student account. Kailangan munang ma-approve ng admin.',
      );
    }

    final activeSnap = await _borrowRecordsRef
        .where('studentUid', isEqualTo: studentUid)
        .where('status', whereIn: ['borrowed', 'pending_reservation']).get();

    if (activeSnap.docs.length >= maxActiveItems) {
      throw Exception(
        'Naabot na ang limit na $maxActiveItems active borrowed/reserved books.',
      );
    }

    final hasSameBook = activeSnap.docs.any((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return (d['bookId'] ?? '').toString() == book.id;
    });
    if (hasSameBook) {
      throw Exception(
        'May active borrow o reservation ka na para sa "${book.title}".',
      );
    }

    final studentName = studentFullName(userData);
    final studentLrn =
        (userData['lrn'] ?? userData['studentId'] ?? '').toString().trim();

    await _db.runTransaction((tx) async {
      final bookRef = _booksRef.doc(book.id);
      final bookSnap = await tx.get(bookRef);
      if (!bookSnap.exists) {
        throw Exception('Wala na ang libro sa catalog.');
      }

      final bookData =
          (bookSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final currentAvailable =
          (bookData['availableCopies'] as num?)?.toInt() ?? 0;
      if (currentAvailable <= 0) {
        throw Exception(
          'Wala nang available copy na puwedeng i-reserve para sa "${book.title}".',
        );
      }

      final newRecordRef = _borrowRecordsRef.doc();
      tx.update(bookRef, {
        'availableCopies': currentAvailable - 1,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      tx.set(newRecordRef, {
        'bookId': book.id,
        'bookTitle': (bookData['title'] ?? book.title).toString(),
        'studentUid': studentUid,
        'studentLrn': studentLrn,
        'studentName': studentName,
        'status': 'pending_reservation',
        'borrowedAt': null,
        'dueDate': null,
        'returnedAt': null,
        'processedByUid': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> cancelReservation({
    required BorrowRecordModel record,
  }) async {
    await _db.runTransaction((tx) async {
      final recordRef = _borrowRecordsRef.doc(record.id);
      final recordSnap = await tx.get(recordRef);
      if (!recordSnap.exists) {
        throw Exception('Hindi nahanap ang reservation.');
      }

      final recData =
          (recordSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      if ((recData['status'] ?? '').toString() != 'pending_reservation') {
        throw Exception('Hindi na pending ang reservation na ito.');
      }

      final bookRef = _booksRef.doc(record.bookId);
      final bookSnap = await tx.get(bookRef);

      tx.update(recordRef, {
        'status': 'cancelled',
      });

      if (bookSnap.exists) {
        final bookData =
            (bookSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
        final totalCopies = (bookData['totalCopies'] as num?)?.toInt() ?? 0;
        final currentAvailable =
            (bookData['availableCopies'] as num?)?.toInt() ?? 0;
        final nextAvailable = (currentAvailable + 1).clamp(
          0,
          totalCopies > 0 ? totalCopies : currentAvailable + 1,
        );

        tx.update(bookRef, {
          'availableCopies': nextAvailable,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    });
  }

  Future<void> releaseReservationToBorrow({
    required BorrowRecordModel record,
    required String processedByUid,
    int loanDays = 7,
  }) async {
    if (loanDays < 1) {
      throw Exception('Dapat hindi bababa sa 1 araw ang loan period.');
    }

    final now = DateTime.now();
    final dueDateTime = now.add(Duration(days: loanDays));

    await _db.runTransaction((tx) async {
      final recordRef = _borrowRecordsRef.doc(record.id);
      final recordSnap = await tx.get(recordRef);
      if (!recordSnap.exists) {
        throw Exception('Hindi nahanap ang reservation.');
      }

      final recData =
          (recordSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      if ((recData['status'] ?? '').toString() != 'pending_reservation') {
        throw Exception('Hindi na pending ang reservation na ito.');
      }

      tx.update(recordRef, {
        'status': 'borrowed',
        'borrowedAt': Timestamp.fromDate(now),
        'dueDate': Timestamp.fromDate(dueDateTime),
        'returnedAt': null,
        'processedByUid': processedByUid,
      });
    });
  }
}