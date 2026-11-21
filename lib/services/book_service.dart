import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/book_model.dart';

class BookService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _booksRef => _db.collection('books');

  CollectionReference<Map<String, dynamic>> get _borrowRecordsRef => _db.collection('borrow_records');

  Stream<List<BookModel>> streamBooks() {
    return _booksRef
        .orderBy('title')
        .snapshots()
        .map((snap) => snap.docs.map(BookModel.fromFirestore).toList());
  }

  Future<void> addBook({
    required String title,
    required String author,
    required String category,
    required String isbn,
    required String callNumber,
    required int totalCopies,
    String? coverBase64,
  }) async {
    if (totalCopies < 1) {
      throw Exception('Dapat hindi bababa sa 1 ang total copies.');
    }

    await _booksRef.add({
      'title': title.trim(),
      'author': author.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'isbn': isbn.trim(),
      'callNumber': callNumber.trim(),
      'totalCopies': totalCopies,
      'availableCopies': totalCopies,
      if (coverBase64 != null && coverBase64.isNotEmpty)
        'coverBase64': coverBase64,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateBook({
    required BookModel existingBook,
    required String title,
    required String author,
    required String category,
    required String isbn,
    required String callNumber,
    required int newTotalCopies,
    String? coverBase64,
  }) async {
    if (newTotalCopies < 1) {
      throw Exception('Dapat hindi bababa sa 1 ang total copies.');
    }

    final currentlyBorrowed =
        (existingBook.totalCopies - existingBook.availableCopies)
            .clamp(0, existingBook.totalCopies);

    if (newTotalCopies < currentlyBorrowed) {
      throw Exception(
        'Hindi puwedeng bumaba sa $currentlyBorrowed ang total copies dahil may $currentlyBorrowed pang naka-hiram.',
      );
    }

    final newAvailableCopies =
        (newTotalCopies - currentlyBorrowed).clamp(0, newTotalCopies);

    await _db.runTransaction((tx) async {
      final docRef = _booksRef.doc(existingBook.id);
      tx.update(docRef, {
        'title': title.trim(),
        'author': author.trim(),
        'category': category.trim().isEmpty ? 'General' : category.trim(),
        'isbn': isbn.trim(),
        'callNumber': callNumber.trim(),
        'totalCopies': newTotalCopies,
        'availableCopies': newAvailableCopies,
        if (coverBase64 != null) 'coverBase64': coverBase64,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> deleteBook(BookModel book) async {
    final activeBorrowSnap = await _borrowRecordsRef
        .where('bookId', isEqualTo: book.id)
        .where('status', whereIn: ['borrowed', 'pending_reservation'])
        .limit(1)
        .get();

    if (activeBorrowSnap.docs.isNotEmpty) {
      throw Exception(
        'Hindi mabubura ang libro habang may active borrowed o reserved record.',
      );
    }

    await _booksRef.doc(book.id).delete();
  }
}