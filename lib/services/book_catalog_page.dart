import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../models/book_model.dart';
import '../services/book_service.dart';

class BookCatalogPage extends StatefulWidget {
  final bool isAdmin;
  final void Function(BookModel book)? onSelectBook;

  const BookCatalogPage({
    super.key,
    required this.isAdmin,
    this.onSelectBook,
  });

  @override
  State<BookCatalogPage> createState() => _BookCatalogPageState();
}

class _BookCatalogPageState extends State<BookCatalogPage> {
  final BookService _bookService = BookService();
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';
  String _availabilityFilter = 'all'; // 'all' | 'available' | 'unavailable'
  String _selectedCategory = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Uint8List? _decodeCover(String? base64Str) {
    if (base64Str == null || base64Str.isEmpty) return null;
    try {
      return base64Decode(base64Str);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openBookFormDialog({BookModel? book}) async {
    final isEdit = book != null;
    final titleCtrl = TextEditingController(text: book?.title ?? '');
    final authorCtrl = TextEditingController(text: book?.author ?? '');
    final categoryCtrl =
        TextEditingController(text: book?.category ?? 'General');
    final isbnCtrl = TextEditingController(text: book?.isbn ?? '');
    final callNoCtrl = TextEditingController(text: book?.callNumber ?? '');
    final copiesCtrl = TextEditingController(
      text: (book?.totalCopies ?? 1).toString(),
    );
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    await showDialog(
      context: context,
      barrierDismissible: !saving,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: Text(isEdit ? 'Edit Book' : 'Add Book'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Book Title *',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: authorCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Author *',
                        ),
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Required' : null,
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: categoryCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Category / Subject',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: callNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Call Number',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: isbnCtrl,
                        decoration: const InputDecoration(
                          labelText: 'ISBN',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: copiesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Total Copies *',
                        ),
                        validator: (v) {
                          final parsed = int.tryParse((v ?? '').trim());
                          if (parsed == null || parsed < 1) {
                            return 'Enter valid number (>= 1)';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setDialogState(() => saving = true);
                          try {
                            final total = int.parse(copiesCtrl.text.trim());
                            if (isEdit) {
                              await _bookService.updateBook(
                                existingBook: book,
                                title: titleCtrl.text,
                                author: authorCtrl.text,
                                category: categoryCtrl.text,
                                isbn: isbnCtrl.text,
                                callNumber: callNoCtrl.text,
                                newTotalCopies: total,
                              );
                            } else {
                              await _bookService.addBook(
                                title: titleCtrl.text,
                                author: authorCtrl.text,
                                category: categoryCtrl.text,
                                isbn: isbnCtrl.text,
                                callNumber: callNoCtrl.text,
                                totalCopies: total,
                              );
                            }
                            if (ctx.mounted) Navigator.pop(ctx);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    isEdit
                                        ? 'Na-update ang libro.'
                                        : 'Nadagdag ang libro sa catalog.',
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() => saving = false);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(e.toString())),
                              );
                            }
                          }
                        },
                  child: Text(saving ? 'Saving...' : 'Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteBook(BookModel book) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book?'),
        content: Text(
          'Sigurado ka bang buburahin ang "${book.title}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await _bookService.deleteBook(book);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nabura ang libro.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Catalog'),
      ),
      floatingActionButton: widget.isAdmin
          ? FloatingActionButton.extended(
              onPressed: () => _openBookFormDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Book'),
            )
          : null,
      body: StreamBuilder<List<BookModel>>(
        stream: _bookService.streamBooks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allBooks = snapshot.data ?? [];
          final categories = <String>{
            'All',
            ...allBooks.map((b) => b.category.trim()).where((c) => c.isNotEmpty),
          }.toList();

          final activeCategory =
              categories.contains(_selectedCategory) ? _selectedCategory : 'All';

          final filteredBooks = allBooks.where((book) {
            final q = _searchQuery.trim().toLowerCase();
            final matchesQuery = q.isEmpty ||
                book.title.toLowerCase().contains(q) ||
                book.author.toLowerCase().contains(q) ||
                book.category.toLowerCase().contains(q) ||
                book.isbn.toLowerCase().contains(q);

            final matchesAvailability = switch (_availabilityFilter) {
              'available' => book.isAvailable,
              'unavailable' => !book.isAvailable,
              _ => true,
            };

            final matchesCategory =
                activeCategory == 'All' || book.category == activeCategory;

            return matchesQuery && matchesAvailability && matchesCategory;
          }).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                child: TextField(
                  controller: _searchController,
                  onChanged: (val) => setState(() => _searchQuery = val),
                  decoration: InputDecoration(
                    hintText: 'Search title, author, category, or ISBN...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: const Text('All'),
                      selected: _availabilityFilter == 'all',
                      onSelected: (_) =>
                          setState(() => _availabilityFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Available'),
                      selected: _availabilityFilter == 'available',
                      onSelected: (_) =>
                          setState(() => _availabilityFilter = 'available'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Out of Stock'),
                      selected: _availabilityFilter == 'unavailable',
                      onSelected: (_) =>
                          setState(() => _availabilityFilter = 'unavailable'),
                    ),
                  ],
                ),
              ),
              if (categories.length > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: Row(
                    children: categories.map((cat) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(cat),
                          selected: activeCategory == cat,
                          onSelected: (_) =>
                              setState(() => _selectedCategory = cat),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              const Divider(height: 12),
              Expanded(
                child: filteredBooks.isEmpty
                    ? const Center(child: Text('Walang nahanap na libro.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 84),
                        itemCount: filteredBooks.length,
                        itemBuilder: (context, index) {
                          final book = filteredBooks[index];
                          final coverBytes = _decodeCover(book.coverBase64);

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            child: ListTile(
                              onTap: widget.onSelectBook != null
                                  ? () => widget.onSelectBook!(book)
                                  : null,
                              leading: coverBytes != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.memory(
                                        coverBytes,
                                        width: 44,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  : Container(
                                      width: 44,
                                      height: 60,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        color: Theme.of(context)
                                            .colorScheme
                                            .surfaceContainerHighest,
                                      ),
                                      child: const Icon(Icons.menu_book),
                                    ),
                              title: Text(
                                book.title,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${book.author} • ${book.category}'),
                                  if (book.callNumber.isNotEmpty)
                                    Text(
                                      'Call No.: ${book.callNumber}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  const SizedBox(height: 4),
                                  Text(
                                    book.isAvailable
                                        ? 'Available: ${book.availableCopies} / ${book.totalCopies}'
                                        : 'Not Available (0 / ${book.totalCopies})',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: book.isAvailable
                                          ? Colors.green.shade700
                                          : Colors.red.shade700,
                                    ),
                                  ),
                                ],
                              ),
                              trailing: widget.isAdmin
                                  ? PopupMenuButton<String>(
                                      onSelected: (val) {
                                        if (val == 'edit') {
                                          _openBookFormDialog(book: book);
                                        } else if (val == 'delete') {
                                          _confirmDeleteBook(book);
                                        }
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
                                        ),
                                      ],
                                    )
                                  : null,
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}