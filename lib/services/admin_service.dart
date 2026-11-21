import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

String roleLabel(String? role) => role == 'admin' ? 'Head admin' : 'Librarian';

/// Display name for an admin or librarian. Never returns "null".
String staffName(Map<String, dynamic> data) {
  final first = (data['firstName'] ?? '').toString().trim();
  final last = (data['lastName'] ?? '').toString().trim();
  final full = '$first $last'.trim();
  if (full.isNotEmpty) return full;

  final alt =
      (data['fullName'] ?? data['name'] ?? data['displayName'] ?? '')
          .toString()
          .trim();
  if (alt.isNotEmpty) return alt;

  final email = (data['email'] ?? '').toString().trim();
  if (email.isNotEmpty) return email;

  return data['role'] == 'admin' ? 'Admin' : 'Librarian';
}

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<QuerySnapshot<Map<String, dynamic>>> studentsStream() {
    return _db
        .collection('users')
        .where('role', isEqualTo: 'student')
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> auditStream() {
    return _db
        .collection('auditLogs')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  Future<Uint8List?> _loadDoc(String collection, String uid) async {
    final doc = await _db.collection(collection).doc(uid).get();
    final data = doc.data();
    if (data == null) return null;
    return base64Decode(data['data'] as String);
  }

  Future<Uint8List?> loadCor(String uid) => _loadDoc('cors', uid);

  Future<Uint8List?> loadId(String uid) => _loadDoc('ids', uid);

  Future<void> setStatus({
    required String studentUid,
    required Map<String, dynamic> student,
    required String adminUid,
    required Map<String, dynamic> admin,
    required bool approve,
    String? reason,
  }) async {
    final studentName = '${student['firstName']} ${student['lastName']}';
    final adminName = staffName(admin);
    final batch = _db.batch();

    batch.update(_db.collection('users').doc(studentUid), {
      'validationStatus': approve ? 'validated' : 'rejected',
      'validatedAt': approve ? FieldValue.serverTimestamp() : null,
      'rejectReason': approve ? null : reason,
      'idVerified': approve,
      'reviewedBy': adminUid,
    });

    batch.set(_db.collection('auditLogs').doc(), {
      'action': approve ? 'approved' : 'rejected',
      'studentUid': studentUid,
      'studentName': studentName,
      'lrn': student['lrn'],
      'adminUid': adminUid,
      'adminName': adminName,
      'adminRole': admin['role'],
      'reason': approve ? null : reason,
      'createdAt': FieldValue.serverTimestamp(),
    });

    batch.set(_db.collection('notifications').doc(), {
      'uid': studentUid,
      'type': 'validation',
      'title': approve ? 'Library card validated' : 'Your COR or school ID was not accepted',
      'message': approve
          ? 'Your library card has been validated.'
          : 'Reason: $reason',
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}