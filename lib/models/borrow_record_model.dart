import 'package:cloud_firestore/cloud_firestore.dart';

class BorrowRecordModel {
  final String id;
  final String bookId;
  final String bookTitle;
  final String studentUid;
  final String studentLrn;
  final String studentName;
  final String status; // 'borrowed' | 'returned' | 'pending_reservation' | 'cancelled'
  final Timestamp? borrowedAt;
  final Timestamp? dueDate;
  final Timestamp? returnedAt;
  final String? processedByUid;
  final Timestamp? createdAt;

  BorrowRecordModel({
    required this.id,
    required this.bookId,
    required this.bookTitle,
    required this.studentUid,
    required this.studentLrn,
    required this.studentName,
    required this.status,
    this.borrowedAt,
    this.dueDate,
    this.returnedAt,
    this.processedByUid,
    this.createdAt,
  });

  bool get isBorrowed => status == 'borrowed';
  bool get isReturned => status == 'returned';

  bool get isOverdue {
    if (!isBorrowed || dueDate == null) return false;
    return DateTime.now().isAfter(dueDate!.toDate());
  }

  factory BorrowRecordModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return BorrowRecordModel(
      id: doc.id,
      bookId: (data['bookId'] ?? '').toString(),
      bookTitle: (data['bookTitle'] ?? '').toString(),
      studentUid: (data['studentUid'] ?? '').toString(),
      studentLrn: (data['studentLrn'] ?? '').toString(),
      studentName: (data['studentName'] ?? '').toString(),
      status: (data['status'] ?? 'borrowed').toString(),
      borrowedAt: data['borrowedAt'] as Timestamp?,
      dueDate: data['dueDate'] as Timestamp?,
      returnedAt: data['returnedAt'] as Timestamp?,
      processedByUid: data['processedByUid'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
    );
  }
}