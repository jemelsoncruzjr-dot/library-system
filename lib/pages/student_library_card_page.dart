import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/student_name.dart';

class StudentLibraryCardPage extends StatelessWidget {
  final String studentUid;

  const StudentLibraryCardPage({
    super.key,
    required this.studentUid,
  });

  bool _isValidated(Map<String, dynamic> data) {
    return isValidatedStudent(data);
  }

  @override
  Widget build(BuildContext context) {
    final userDocStream = FirebaseFirestore.instance
        .collection('users')
        .doc(studentUid)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Library Card'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDocStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError ||
              !snapshot.hasData ||
              !snapshot.data!.exists) {
            return const Center(
              child: Text('Hindi mahanap ang library card record.'),
            );
          }

          final data = (snapshot.data!.data() as Map<String, dynamic>?) ??
              <String, dynamic>{};
          final fullName = studentFullName(data);
          final lrn =
              (data['lrn'] ?? data['studentId'] ?? '').toString().trim();
          final validated = _isValidated(data);
          final qrPayload = 'LIBCARD|$lrn|$studentUid';

          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'DIGITAL LIBRARY CARD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (lrn.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Walang naka-set na LRN sa profile mo.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: QrImageView(
                            data: qrPayload,
                            version: QrVersions.auto,
                            size: 200,
                          ),
                        ),
                      const SizedBox(height: 16),
                      Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lrn.isEmpty ? 'LRN: -' : 'LRN: $lrn',
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: validated
                              ? Colors.green.shade100
                              : Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          validated ? 'VALIDATED' : 'PENDING VALIDATION',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: validated
                                ? Colors.green.shade900
                                : Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}