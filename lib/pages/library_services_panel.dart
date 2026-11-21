import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'book_catalog_page.dart';
import 'borrow_history_page.dart';
import 'borrow_return_page.dart';
import 'due_reminders_page.dart';
import 'library_reports_page.dart';
import 'library_visit_log_page.dart';
import 'reservations_page.dart';
import 'student_library_card_page.dart';

class _ServiceItem {
  const _ServiceItem(this.icon, this.title, this.subtitle, this.builder);

  final IconData icon;
  final String title;
  final String subtitle;
  final WidgetBuilder builder;
}

class _ServiceGrid extends StatelessWidget {
  const _ServiceGrid({required this.items});

  final List<_ServiceItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 640 ? 2 : 1;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final item in items)
              SizedBox(width: width, child: _ServiceTile(item: item)),
          ],
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.item});

  final _ServiceItem item;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: item.builder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0x140D58BB),
                  shape: BoxShape.circle,
                ),
                child: Icon(item.icon, color: AppColors.green, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class StudentServicesPanel extends StatelessWidget {
  const StudentServicesPanel({
    super.key,
    required this.uid,
    required this.validated,
  });

  final String uid;
  final bool validated;

  @override
  Widget build(BuildContext context) {
    final items = <_ServiceItem>[
      _ServiceItem(
        Icons.menu_book_outlined,
        'Browse books',
        'Search the catalog and see what is available',
        (_) => const BookCatalogPage(isAdmin: false),
      ),
      _ServiceItem(
        Icons.qr_code_2,
        'My library card',
        'Show your QR code at the library',
        (_) => StudentLibraryCardPage(studentUid: uid),
      ),
      _ServiceItem(
        Icons.bookmark_border,
        'Reservations',
        'Reserve a book that is currently borrowed',
        (_) => ReservationsPage(isAdmin: false, currentUserUid: uid),
      ),
      _ServiceItem(
        Icons.event_outlined,
        'Due dates',
        'See which books to return and when',
        (_) => DueRemindersPage(isAdmin: false, currentUserUid: uid),
      ),
      _ServiceItem(
        Icons.history,
        'Borrowing history',
        'Books you borrowed and returned',
        (_) => BorrowHistoryPage(isAdmin: false, currentUserUid: uid),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Library services',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        if (!validated) ...[
          const SizedBox(height: 4),
          const Text(
            'Borrowing and reservations open once your library card is validated.',
            style: TextStyle(fontSize: 14, color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 16),
        _ServiceGrid(items: items),
      ],
    );
  }
}

class AdminLibraryTab extends StatelessWidget {
  const AdminLibraryTab({super.key, required this.adminUid});

  final String adminUid;

  @override
  Widget build(BuildContext context) {
    final items = <_ServiceItem>[
      _ServiceItem(
        Icons.menu_book_outlined,
        'Books',
        'Add, edit, and remove books in the catalog',
        (_) => const BookCatalogPage(isAdmin: true),
      ),
      _ServiceItem(
        Icons.swap_horiz,
        'Borrow and return',
        'Lend books to validated students and record returns',
        (_) => BorrowReturnPage(isAdmin: true, currentUserUid: adminUid),
      ),
      _ServiceItem(
        Icons.bookmark_border,
        'Reservations',
        'Review reservations and release them for borrowing',
        (_) => ReservationsPage(isAdmin: true, currentUserUid: adminUid),
      ),
      _ServiceItem(
        Icons.event_outlined,
        'Due and overdue',
        'Books that are almost due or already late',
        (_) => DueRemindersPage(isAdmin: true, currentUserUid: adminUid),
      ),
      _ServiceItem(
        Icons.qr_code_scanner,
        'Visit log',
        'Scan a library card or type an LRN to record a visit',
        (_) => LibraryVisitLogPage(isAdmin: true, currentUserUid: adminUid),
      ),
      _ServiceItem(
        Icons.history,
        'Borrowing history',
        'All borrowed and returned books',
        (_) => BorrowHistoryPage(isAdmin: true, currentUserUid: adminUid),
      ),
      _ServiceItem(
        Icons.bar_chart,
        'Reports',
        'Most borrowed books, visits, and overdue counts',
        (_) => const LibraryReportsPage(),
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Library management',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              _ServiceGrid(items: items),
            ],
          ),
        ),
      ),
    );
  }
}
