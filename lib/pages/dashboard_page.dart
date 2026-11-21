import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';
import '../widgets/library_card.dart';
import '../widgets/loading_view.dart';
import 'cor_upload_page.dart';
import 'library_services_panel.dart';

BoxDecoration _panelDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.line),
  );
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: auth.userStream(uid),
        builder: (context, snapshot) {
          final data = snapshot.data?.data();
          final name =
              data == null ? null : '${data['firstName']} ${data['lastName']}';

          Widget content;
          if (snapshot.hasError) {
            content = ErrorView(message: '${snapshot.error}');
          } else if (!snapshot.hasData) {
            content = const LoadingView();
          } else if (data == null) {
            content = const Center(
              child: Text('We could not find your student record.'),
            );
          } else {
            content = _DashboardBody(data: data);
          }

          return Column(
            children: [
              _TopBar(name: name, onSignOut: () => auth.logout()),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.name, required this.onSignOut});

  final String? name;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          const Flexible(child: BrandMark(light: false, logoSize: 40)),
          const Spacer(),
          if (name != null && MediaQuery.of(context).size.width > 700)
            Flexible(
              child: Text(
                name!,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.muted,
                ),
              ),
            ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: onSignOut,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final status = data['validationStatus'] as String? ?? 'not_submitted';

    final card = LibraryCard(
      name: '${data['firstName']} ${data['lastName']}',
      lrn: '${data['lrn']}',
      gradeSection: '${data['grade']} - ${data['section']}',
      validated: status == 'validated',
    );

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hello, ${data['firstName']}', style: textTheme.headlineMedium),
        const SizedBox(height: 6),
        const Text(
          'Here is the current status of your library card.',
          style: TextStyle(fontSize: 16, color: AppColors.muted),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1040),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 860;

              if (!wide) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    heading,
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 400),
                        child: card,
                      ),
                    ),
                    const SizedBox(height: 24),
                    _StatusPanel(data: data),
                    const SizedBox(height: 24),
                    StudentServicesPanel(
                      uid: FirebaseAuth.instance.currentUser!.uid,
                      validated: status == 'validated',
                    ),
                    const SizedBox(height: 24),
                    _DetailsPanel(data: data),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: 28),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _StatusPanel(data: data),
                            const SizedBox(height: 24),
                            StudentServicesPanel(
                              uid: FirebaseAuth.instance.currentUser!.uid,
                              validated: status == 'validated',
                            ),
                            const SizedBox(height: 24),
                            _DetailsPanel(data: data),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      SizedBox(width: 380, child: card),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StatusInfo {
  const _StatusInfo(
    this.color,
    this.tint,
    this.icon,
    this.title,
    this.message,
    this.action,
  );

  final Color color;
  final Color tint;
  final IconData icon;
  final String title;
  final String message;
  final String? action;

  factory _StatusInfo.from(String status, Map<String, dynamic> data) {
    switch (status) {
      case 'pending':
        return const _StatusInfo(
          AppColors.warning,
          Color(0x1F9A5B00),
          Icons.hourglass_top,
          'Waiting for review',
          'Your COR and school ID have been submitted. The librarian will review them and you will be notified here.',
          null,
        );
      case 'rejected':
        {
          final reason = (data['rejectReason'] as String?)?.trim();
          return _StatusInfo(
            AppColors.danger,
            const Color(0x1FB3261E),
            Icons.cancel_outlined,
            'Your documents were not accepted',
            reason == null || reason.isEmpty
                ? 'Upload clearer copies of your COR and school ID.'
                : 'Reason: $reason',
            'Upload again',
          );
        }
      case 'validated':
        {
          final ts = data['validatedAt'];
          final when = ts is Timestamp
              ? ' on ${DateFormat('MMMM d, yyyy').format(ts.toDate())}'
              : '';
          return _StatusInfo(
            AppColors.success,
            const Color(0x1F1E7B4F),
            Icons.verified_outlined,
            'Library card validated',
            'Your library card was validated$when. You can use it at the library.',
            null,
          );
        }
      default:
        return const _StatusInfo(
          AppColors.warning,
          Color(0x1F9A5B00),
          Icons.upload_file_outlined,
          'Validation needed',
          'Upload your Certificate of Registration (COR) and school ID so the librarian can validate your library card.',
          'Upload COR and ID',
        );
    }
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['validationStatus'] as String? ?? 'not_submitted';
    final info = _StatusInfo.from(status, data);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: info.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(info.icon, color: info.color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  info.title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            info.message,
            style: const TextStyle(
              fontSize: 15,
              height: 1.5,
              color: AppColors.muted,
            ),
          ),
          if (info.action != null) ...[
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                ),
                onPressed: () async {
                  final submitted = await Navigator.of(context).push<bool>(
                    MaterialPageRoute(builder: (_) => const CorUploadPage()),
                  );
                  if (submitted == true && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('COR and school ID submitted. The librarian will review them.'),
                      ),
                    );
                  }
                },
                child: Text(info.action!),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailsPanel extends StatelessWidget {
  const _DetailsPanel({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final birthday = data['birthday'];
    final rows = <(String, String)>[
      ('LRN', '${data['lrn']}'),
      ('Gmail', '${data['email']}'),
      ('Grade and section', '${data['grade']} - ${data['section']}'),
      ('Gender', '${data['gender']}'),
      (
        'Birthday',
        birthday is Timestamp
            ? DateFormat('MMMM d, yyyy').format(birthday.toDate())
            : '-',
      ),
      ('Address', '${data['address']}'),
    ];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Student details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 140,
                    child: Text(
                      rows[i].$1,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      rows[i].$2,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
