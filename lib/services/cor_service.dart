import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image/image.dart' as img;

class CorInvalidImageException implements Exception {
  const CorInvalidImageException([this.which = 'COR']);

  /// Which document failed: "COR" or "school ID".
  final String which;
}

class CorTooLargeException implements Exception {
  const CorTooLargeException([this.which = 'COR']);

  final String which;
}

/// Handles the student's verification documents: the COR and the school ID.
/// Both are compressed to JPG and stored as base64 in Firestore
/// (`cors/{uid}` and `ids/{uid}`).
class CorService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int _maxBytes = 600 * 1024;

  Uint8List _compress(Uint8List bytes, String which) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw CorInvalidImageException(which);
    }

    var image = decoded;
    if (image.width > 1400) {
      image = img.copyResize(image, width: 1400);
    }

    var quality = 80;
    var output = Uint8List.fromList(img.encodeJpg(image, quality: quality));

    while (output.length > _maxBytes && quality > 30) {
      quality -= 10;
      output = Uint8List.fromList(img.encodeJpg(image, quality: quality));
    }

    if (output.length > _maxBytes) {
      image = img.copyResize(image, width: (image.width * 0.7).round());
      output = Uint8List.fromList(img.encodeJpg(image, quality: 60));
    }

    if (output.length > _maxBytes) {
      throw CorTooLargeException(which);
    }
    return output;
  }

  Map<String, dynamic> _docData(Uint8List compressed, String fileName) {
    return {
      'data': base64Encode(compressed),
      'fileName': fileName,
      'size': compressed.length,
      'uploadedAt': FieldValue.serverTimestamp(),
    };
  }

  Future<void> submit({
    required String uid,
    required Uint8List corBytes,
    required String corFileName,
    required Uint8List idBytes,
    required String idFileName,
  }) async {
    final cor = _compress(corBytes, 'COR');
    final id = _compress(idBytes, 'school ID');
    final batch = _db.batch();

    batch.set(_db.collection('cors').doc(uid), _docData(cor, corFileName));
    batch.set(_db.collection('ids').doc(uid), _docData(id, idFileName));

    batch.update(_db.collection('users').doc(uid), {
      'validationStatus': 'pending',
      'rejectReason': null,
      'idVerified': false,
      'corSubmittedAt': FieldValue.serverTimestamp(),
      'idSubmittedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }
}
