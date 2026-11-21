import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/library_visit_model.dart';
import 'borrow_service.dart';
import 'library_card_service.dart';
import 'student_name.dart';

class LibraryVisitService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final BorrowService _borrowService = BorrowService();
  final LibraryCardService _cardService = LibraryCardService();

  CollectionReference<Map<String, dynamic>> get _visitsRef => _db.collection('library_visits');

  CollectionReference<Map<String, dynamic>> get _usersRef => _db.collection('users');

  Stream<List<LibraryVisitModel>> streamVisits({String? studentUid}) {
    final query = studentUid == null
        ? _visitsRef
        : _visitsRef.where('studentUid', isEqualTo: studentUid);

    return query.snapshots().map((snap) {
      final list = <LibraryVisitModel>[];
      for (final doc in snap.docs) {
        list.add(LibraryVisitModel.fromFirestore(doc));
      }
      list.sort((a, b) {
        final aTime = a.visitedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.visitedAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
      return list;
    });
  }

  Future<LibraryVisitModel> logVisitByStudentUid({
    required String studentUid,
    required String purpose,
    String? loggedByUid,
    bool requireValidated = true,
  }) async {
    final userSnap = await _usersRef.doc(studentUid).get();
    if (!userSnap.exists) {
      throw Exception('Hindi nahanap ang student record.');
    }

    final userData =
        (userSnap.data() as Map<String, dynamic>?) ?? <String, dynamic>{};
    final validated = _borrowService.isStudentValidated(userData);

    if (requireValidated && !validated) {
      throw Exception(
        'Hindi pa validated ang student account. Kailangan munang ma-approve ng admin.',
      );
    }

    final studentName = studentFullName(userData);
    final studentLrn =
        (userData['lrn'] ?? userData['studentId'] ?? '').toString().trim();
    final cleanPurpose = purpose.trim().isEmpty ? 'General Visit' : purpose.trim();

    final docRef = await _visitsRef.add({
      'studentUid': studentUid,
      'studentLrn': studentLrn,
      'studentName': studentName,
      'isValidated': validated,
      'purpose': cleanPurpose,
      'visitedAt': FieldValue.serverTimestamp(),
      'loggedByUid': loggedByUid,
    });

    return LibraryVisitModel(
      id: docRef.id,
      studentUid: studentUid,
      studentLrn: studentLrn,
      studentName: studentName,
      isValidated: validated,
      purpose: cleanPurpose,
      visitedAt: Timestamp.now(),
      loggedByUid: loggedByUid,
    );
  }

  Future<LibraryVisitModel> logVisitByLrn({
    required String rawLrnOrQr,
    required String purpose,
    String? loggedByUid,
    bool requireValidated = true,
  }) async {
    final lookup = await _cardService.lookupStudentByLrn(rawLrnOrQr);
    if (lookup == null) {
      throw Exception('Walang student na nahanap para sa LRN/QR na "$rawLrnOrQr".');
    }

    return logVisitByStudentUid(
      studentUid: lookup.uid,
      purpose: purpose,
      loggedByUid: loggedByUid,
      requireValidated: requireValidated,
    );
  }
}