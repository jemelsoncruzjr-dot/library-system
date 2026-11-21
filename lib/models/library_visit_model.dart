import 'package:cloud_firestore/cloud_firestore.dart';

class LibraryVisitModel {
  final String id;
  final String studentUid;
  final String studentLrn;
  final String studentName;
  final bool isValidated;
  final String purpose;
  final Timestamp? visitedAt;
  final String? loggedByUid;

  LibraryVisitModel({
    required this.id,
    required this.studentUid,
    required this.studentLrn,
    required this.studentName,
    required this.isValidated,
    required this.purpose,
    this.visitedAt,
    this.loggedByUid,
  });

  factory LibraryVisitModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    return LibraryVisitModel(
      id: doc.id,
      studentUid: (data['studentUid'] ?? '').toString(),
      studentLrn: (data['studentLrn'] ?? '').toString(),
      studentName: (data['studentName'] ?? 'Student').toString(),
      isValidated: data['isValidated'] == true,
      purpose: (data['purpose'] ?? 'General Visit').toString(),
      visitedAt: data['visitedAt'] as Timestamp?,
      loggedByUid: data['loggedByUid'] as String?,
    );
  }
}