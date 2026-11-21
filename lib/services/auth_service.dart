import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LrnTakenException implements Exception {
  const LrnTakenException();
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authChanges => _auth.authStateChanges();

  Future<void> login({required String email, required String password}) async {
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> register({
    required String lrn,
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String middleName,
    required String grade,
    required String section,
    required String gender,
    required DateTime birthday,
    required String address,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final user = cred.user!;

    try {
      await _db.runTransaction((tx) async {
        final lrnRef = _db.collection('lrns').doc(lrn);
        final lrnSnap = await tx.get(lrnRef);
        if (lrnSnap.exists) {
          throw const LrnTakenException();
        }
        tx.set(lrnRef, {'uid': user.uid});
        tx.set(_db.collection('users').doc(user.uid), {
          'lrn': lrn,
          'email': email,
          'firstName': firstName,
          'lastName': lastName,
          'middleName': middleName,
          'grade': grade,
          'section': section,
          'gender': gender,
          'birthday': Timestamp.fromDate(birthday),
          'address': address,
          'role': 'student',
          'validationStatus': 'not_submitted',
          'corUrl': null,
          'rejectReason': null,
          'validatedAt': null,
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      await user.delete();
      rethrow;
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> userStream(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }
}