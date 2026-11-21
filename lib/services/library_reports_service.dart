import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';
import '../models/borrow_record_model.dart';
import '../models/library_visit_model.dart';
import 'student_name.dart';

class BookBorrowStat {
  final String bookId;
  final String bookTitle;
  final int borrowCount;

  BookBorrowStat({
    required this.bookId,
    required this.bookTitle,
    required this.borrowCount,
  });
}

class LibraryStatsSummary {
  final int totalBookTitles;
  final int totalBookCopies;
  final int availableCopies;
  final int activeBorrowed;
  final int returnedCount;
  final int overdueCount;
  final int pendingReservations;
  final int todayVisits;
  final int totalVisits;
  final int validatedStudents;
  final List<BookBorrowStat> topBorrowedBooks;

  LibraryStatsSummary({
    required this.totalBookTitles,
    required this.totalBookCopies,
    required this.availableCopies,
    required this.activeBorrowed,
    required this.returnedCount,
    required this.overdueCount,
    required this.pendingReservations,
    required this.todayVisits,
    required this.totalVisits,
    required this.validatedStudents,
    required this.topBorrowedBooks,
  });
}

class LibraryReportsService {
  final _booksRef = FirebaseFirestore.instance.collection('books');
  final _borrowRecordsRef =
      FirebaseFirestore.instance.collection('borrow_records');
  final _visitsRef = FirebaseFirestore.instance.collection('library_visits');
  final _usersRef = FirebaseFirestore.instance.collection('users');

  bool _isStudentValidated(Map<String, dynamic> data) {
    return isValidatedStudent(data);
  }

  bool _isToday(Timestamp? ts) {
    if (ts == null) return false;
    final d = ts.toDate();
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<LibraryStatsSummary> loadSummary() async {
    final booksSnap = await _booksRef.get();
    final borrowsSnap = await _borrowRecordsRef.get();
    final visitsSnap = await _visitsRef.get();
    final usersSnap = await _usersRef.get();

    int totalCopies = 0;
    int availableCopies = 0;
    for (final doc in booksSnap.docs) {
      final book = BookModel.fromFirestore(doc);
      totalCopies += book.totalCopies;
      availableCopies += book.availableCopies;
    }

    int activeBorrowed = 0;
    int returnedCount = 0;
    int overdueCount = 0;
    int pendingReservations = 0;
    final Map<String, BookBorrowStat> tallyMap = {};

    for (final doc in borrowsSnap.docs) {
      final rec = BorrowRecordModel.fromFirestore(doc);
      if (rec.status == 'borrowed') {
        activeBorrowed++;
        if (rec.isOverdue) overdueCount++;
      } else if (rec.status == 'returned') {
        returnedCount++;
      } else if (rec.status == 'pending_reservation') {
        pendingReservations++;
      }

      if (rec.status == 'borrowed' || rec.status == 'returned') {
        final existing = tallyMap[rec.bookId];
        if (existing == null) {
          tallyMap[rec.bookId] = BookBorrowStat(
            bookId: rec.bookId,
            bookTitle: rec.bookTitle,
            borrowCount: 1,
          );
        } else {
          tallyMap[rec.bookId] = BookBorrowStat(
            bookId: existing.bookId,
            bookTitle: existing.bookTitle,
            borrowCount: existing.borrowCount + 1,
          );
        }
      }
    }

    final topBooks = tallyMap.values.toList()
      ..sort((a, b) => b.borrowCount.compareTo(a.borrowCount));

    int todayVisits = 0;
    for (final doc in visitsSnap.docs) {
      final visit = LibraryVisitModel.fromFirestore(doc);
      if (_isToday(visit.visitedAt)) {
        todayVisits++;
      }
    }

    int validatedStudents = 0;
    for (final doc in usersSnap.docs) {
      final data = doc.data();
      final role = (data['role'] ?? 'student').toString().toLowerCase();
      if (role != 'admin' && _isStudentValidated(data)) {
        validatedStudents++;
      }
    }

    return LibraryStatsSummary(
      totalBookTitles: booksSnap.docs.length,
      totalBookCopies: totalCopies,
      availableCopies: availableCopies,
      activeBorrowed: activeBorrowed,
      returnedCount: returnedCount,
      overdueCount: overdueCount,
      pendingReservations: pendingReservations,
      todayVisits: todayVisits,
      totalVisits: visitsSnap.docs.length,
      validatedStudents: validatedStudents,
      topBorrowedBooks: topBooks.take(5).toList(),
    );
  }
}