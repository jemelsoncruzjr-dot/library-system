import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';
import '../models/borrow_record_model.dart';
import 'student_name.dart';

class BorrowService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _booksRef => _db.collection('books');

  CollectionReference<Map<String, dynamic>> get _borrowRecordsRef => _db.collection('borrow_records');

  CollectionReference<Map<String, dynamic>> get _usersRef => _db.collection('users');

  bool isStudentValidated(Map<String, dynamic> userData) {
    return isValidatedStudent(userData);
  }

  Stream<List<BorrowRecordModel>> streamActiveBorrows() {
    return _borrowRecordsRef
        .where('status', isEqualTo: 'borrowed')
        .snapshots()
        .map((snap) {
      final list = <BorrowRecordModel>[];
      for (final doc in snap.docs) {
        final data = doc.data() as Map<String, dynamic>;
        list.add(BorrowRecordModel.fromFirestore(doc));
        if (data.isEmpty) {}
      }
      list.sort((a, b) {
        final aTime = a.dueDate?.millisecondsSinceEpoch ?? 0;
        final bTime = b.dueDate?.millisecondsSinceEpoch ?? 0;
        return aTime.compareTo(bTime);
      });
      return list;
    });
  }

  Stream<List<BorrowRecordModel>> streamStudentActiveBorrows(String studentUid) {
    return _borrowRecordsRef
        .where('studentUid', isEqualTo: studentUid)
        .where('status', isEqualTo: 'borrowed')
        .snapshots()
        .map((snap) {
      final list = <BorrowRecordModel>[];
      for (final doc in snap.docs) {
        list.add(BorrowRecordModel.fromFirestore(doc));
      }
      return list;
    });
  }

  Future<void> borrowBook({
    required BookModel book,
    required String studentUid,
    int loanDays = 7,
    int maxActiveBorrows = 3,
    String? processedByUid,
  }) async {
    if (loanDays < 1) {
      throw Exception('Dapat hindi bababa sa 1 araw ang loan period.');
    }

    final userSnap = await _usersRef.doc(studentUid).get();
    if (!userSnap.exists) {
      throw Exception('Hindi nahanap ang student record.');
    }

    final userData = (userSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    if (!isStudentValidated(userData)) {
      throw Exception(
        'Hindi pa validated ang student account. Kailangan munang ma-approve ng admin.',
      );
    }

    final existingStudentBorrows = await _borrowRecordsRef
        .where('studentUid', isEqualTo: studentUid)
        .where('status', isEqualTo: 'borrowed')
        .get();

    if (existingStudentBorrows.docs.length >= maxActiveBorrows) {
      throw Exception(
        'Naabot na ang limit na $maxActiveBorrows active borrowed books.',
      );
    }

    final alreadyBorrowedSameBook = existingStudentBorrows.docs.any((doc) {
      final d = doc.data() as Map<String, dynamic>;
      return (d['bookId'] ?? '').toString() == book.id;
    });
    if (alreadyBorrowedSameBook) {
      throw Exception(
        'Naka-hiram ka na ng kopya ng "${book.title}" at hindi pa naibabalik.',
      );
    }

    final studentName = studentFullName(userData);
    final studentLrn =
        (userData['lrn'] ?? userData['studentId'] ?? '').toString().trim();

    final now = DateTime.now();
    final dueDateTime = now.add(Duration(days: loanDays));

    await _db.runTransaction((tx) async {
      final bookRef = _booksRef.doc(book.id);
      final bookSnap = await tx.get(bookRef);
      if (!bookSnap.exists) {
        throw Exception('Wala na ang libro sa catalog.');
      }

      final bookData = (bookSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final currentAvailable =
          (bookData['availableCopies'] as num?)?.toInt() ?? 0;
      if (currentAvailable <= 0) {
        throw Exception('Wala nang available copy para sa "${book.title}".');
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
        'status': 'borrowed',
        'borrowedAt': Timestamp.fromDate(now),
        'dueDate': Timestamp.fromDate(dueDateTime),
        'returnedAt': null,
        'processedByUid': processedByUid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> returnBook({
    required BorrowRecordModel record,
    String? processedByUid,
  }) async {
    if (!record.isBorrowed) {
      throw Exception('Hindi na naka-status na borrowed ang record na ito.');
    }

    await _db.runTransaction((tx) async {
      final recordRef = _borrowRecordsRef.doc(record.id);
      final recordSnap = await tx.get(recordRef);
      if (!recordSnap.exists) {
        throw Exception('Hindi nahanap ang borrow record.');
      }

      final recData = (recordSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
      final currentStatus = (recData['status'] ?? '').toString();
      if (currentStatus != 'borrowed') {
        throw Exception('Naibalik na o hindi na active ang hiram na ito.');
      }

      final bookRef = _booksRef.doc(record.bookId);
      final bookSnap = await tx.get(bookRef);

      tx.update(recordRef, {
        'status': 'returned',
        'returnedAt': FieldValue.serverTimestamp(),
        'processedByUid': processedByUid,
      });

      if (bookSnap.exists) {
        final bookData = (bookSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
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
}