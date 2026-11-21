import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'student_name.dart';

class StudentCardLookupResult {
  final String uid;
  final String fullName;
  final String lrn;
  final String role;
  final bool isValidated;
  final Map<String, dynamic> rawData;

  StudentCardLookupResult({
    required this.uid,
    required this.fullName,
    required this.lrn,
    required this.role,
    required this.isValidated,
    required this.rawData,
  });
}

class LibraryCardService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _usersRef => _db.collection('users');

  String extractLrnFromRawScan(String rawValue) {
    final trimmed = rawValue.trim();
    if (trimmed.isEmpty) return '';

    if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
      try {
        final decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          final lrnVal =
              (decoded['lrn'] ?? decoded['studentId'] ?? '').toString().trim();
          if (lrnVal.isNotEmpty) return lrnVal;
        }
      } catch (_) {}
    }

    final upper = trimmed.toUpperCase();
    if (upper.startsWith('LRN:')) {
      return trimmed.substring(4).trim();
    }
    if (upper.startsWith('LIBCARD|')) {
      final parts = trimmed.split('|');
      if (parts.length >= 2) return parts[1].trim();
    }

    return trimmed;
  }

  bool _checkValidated(Map<String, dynamic> userData) {
    return isValidatedStudent(userData);
  }

  Future<StudentCardLookupResult?> lookupStudentByLrn(String rawInput) async {
    final lrn = extractLrnFromRawScan(rawInput);
    if (lrn.isEmpty) return null;

    var snap = await _usersRef.where('lrn', isEqualTo: lrn).limit(1).get();
    if (snap.docs.isEmpty) {
      snap =
          await _usersRef.where('studentId', isEqualTo: lrn).limit(1).get();
    }
    if (snap.docs.isEmpty) return null;

    final doc = snap.docs.first;
    final data = (doc.data() as Map<String, dynamic>?) ?? <String, dynamic>{};

    final fullName = studentFullName(data);
    final resolvedLrn =
        (data['lrn'] ?? data['studentId'] ?? lrn).toString().trim();
    final role = (data['role'] ?? 'student').toString().trim();

    return StudentCardLookupResult(
      uid: doc.id,
      fullName: fullName,
      lrn: resolvedLrn,
      role: role,
      isValidated: _checkValidated(data),
      rawData: data,
    );
  }
}