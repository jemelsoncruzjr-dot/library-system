import 'package:cloud_firestore/cloud_firestore.dart';

class BookModel {
  final String id;
  final String title;
  final String author;
  final String category;
  final String isbn;
  final String callNumber;
  final int totalCopies;
  final int availableCopies;
  final String? coverBase64;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.category,
    required this.isbn,
    required this.callNumber,
    required this.totalCopies,
    required this.availableCopies,
    this.coverBase64,
    this.createdAt,
    this.updatedAt,
  });

  bool get isAvailable => availableCopies > 0;

  factory BookModel.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    final total = (data['totalCopies'] as num?)?.toInt() ?? 0;
    final rawAvailable = (data['availableCopies'] as num?)?.toInt();
    final clampedAvailable =
        (rawAvailable ?? total).clamp(0, total < 0 ? 0 : total);

    return BookModel(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      author: (data['author'] ?? '').toString(),
      category: (data['category'] ?? 'General').toString(),
      isbn: (data['isbn'] ?? '').toString(),
      callNumber: (data['callNumber'] ?? '').toString(),
      totalCopies: total,
      availableCopies: clampedAvailable,
      coverBase64: data['coverBase64'] as String?,
      createdAt: data['createdAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'title': title.trim(),
      'author': author.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'isbn': isbn.trim(),
      'callNumber': callNumber.trim(),
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
      if (coverBase64 != null && coverBase64!.isNotEmpty)
        'coverBase64': coverBase64,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}