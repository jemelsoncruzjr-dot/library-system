import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';
import '../widgets/status_chip.dart';
import 'admin_review_page.dart';
import 'library_services_panel.dart';

BoxDecoration _panel() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.line),
  );
}

class AdminDashboardPage extends StatelessWidget {
  const AdminDashboardPage({
    super.key,
    required this.adminUid,
    required this.adminData,
  });

  final String adminUid;
  final Map<String, dynamic> adminData;

  @override
  Widget build(BuildContext context) {
    final isHead = adminData['role'] == 'admin';
    final tabs = <Tab>[
      const Tab(text: 'Students'),
      const Tab(text: 'Library'),
      if (isHead) const Tab(text: 'Audit log'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        body: Column(
          children: [
            _AdminTopBar(
              name: staffName(adminData),
              role: roleLabel(adminData['role'] as String?),
            ),
            Container(
              color: Colors.white,
              alignment: Alignment.centerLeft,
              child: TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                labelColor: AppColors.green,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.green,
                dividerColor: AppColors.line,
                tabs: tabs,
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _StudentsTab(adminUid: adminUid, adminData: adminData),
                  AdminLibraryTab(adminUid: adminUid),
                  if (isHead) const _AuditTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  const _AdminTopBar({required this.name, required this.role});

  final String name;
  final String role;

  @override
  Widget build(BuildContext context) {
    final showName = MediaQuery.of(context).size.width > 700;

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
          if (showName)
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  role,
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => AuthService().logout(),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _StudentsTab extends StatefulWidget {
  const _StudentsTab({required this.adminUid, required this.adminData});

  final String adminUid;
  final Map<String, dynamic> adminData;

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final _service = AdminService();
  final _search = TextEditingController();
  String _status = 'all';
  String _grade = 'all';

  static const _grades = [
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  int _rank(String status) {
    return switch (status) {
      'pending' => 0,
      'rejected' => 1,
      'not_submitted' => 2,
      _ => 3,
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _service.studentsStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Text('Could not load students: ${snapshot.error}'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs;
        final counts = <String, int>{
          'pending': 0,
          'validated': 0,
          'rejected': 0,
          'not_submitted': 0,
        };
        for (final d in docs) {
          final s = d.data()['validationStatus'] as String? ?? 'not_submitted';
          counts[s] = (counts[s] ?? 0) + 1;
        }

        final query = _search.text.trim().toLowerCase();
        final filtered = docs.where((d) {
          final data = d.data();
          final status = data['validationStatus'] as String? ?? 'not_submitted';
          if (_status != 'all' && status != _status) return false;
          if (_grade != 'all' && data['grade'] != _grade) return false;
          if (query.isEmpty) return true;
          final haystack =
              '${data['firstName']} ${data['middleName']} ${data['lastName']} ${data['lrn']}'
                  .toLowerCase();
          return haystack.contains(query);
        }).toList();

        filtered.sort((a, b) {
          final ra = _rank(a.data()['validationStatus'] as String? ?? 'not_submitted');
          final rb = _rank(b.data()['validationStatus'] as String? ?? 'not_submitted');
          if (ra != rb) return ra.compareTo(rb);
          return '${a.data()['lastName']}'
              .toLowerCase()
              .compareTo('${b.data()['lastName']}'.toLowerCase());
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatTile(
                        label: 'All students',
                        count: docs.length,
                        color: AppColors.ink,
                        selected: _status == 'all',
                        onTap: () => setState(() => _status = 'all'),
                      ),
                      for (final s in const [
                        'pending',
                        'validated',
                        'rejected',
                        'not_submitted',
                      ])
                        _StatTile(
                          label: StatusChip.label(s),
                          count: counts[s] ?? 0,
                          color: StatusChip.color(s),
                          selected: _status == s,
                          onTap: () => setState(() => _status = s),
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  FieldRow(
                    children: [
                      TextField(
                        controller: _search,
                        onChanged: (_) => setState(() {}),
                        decoration: const InputDecoration(
                          labelText: 'Search by name or LRN',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _grade,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Grade level'),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('All grades'),
                          ),
                          for (final g in _grades)
                            DropdownMenuItem(value: g, child: Text(g)),
                        ],
                        onChanged: (v) => setState(() => _grade = v ?? 'all'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: _panel(),
                    child: filtered.isEmpty
                        ? const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(
                              child: Text(
                                'No students match your filters.',
                                style: TextStyle(color: AppColors.muted),
                              ),
                            ),
                          )
                        : Column(
                            children: [
                              for (var i = 0; i < filtered.length; i++) ...[
                                if (i > 0) const Divider(),
                                _StudentRow(
                                  data: filtered[i].data(),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AdminReviewPage(
                                        studentUid: filtered[i].id,
                                        adminUid: widget.adminUid,
                                        adminData: widget.adminData,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.count,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 176,
      child: Material(
        color: Colors.white,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? AppColors.green : AppColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({required this.data, required this.onTap});

  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = data['validationStatus'] as String? ?? 'not_submitted';

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data['lastName']}, ${data['firstName']}',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LRN ${data['lrn']}  -  ${data['grade']}, ${data['section']}',
                    style: const TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            StatusChip(status),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}

class _AuditTab extends StatelessWidget {
  const _AuditTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: AdminService().auditStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Could not load the audit log: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data!.docs;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1040),
              child: Container(
                decoration: _panel(),
                child: logs.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(32),
                        child: Center(
                          child: Text(
                            'No actions yet. Approvals and rejections will appear here.',
                            style: TextStyle(color: AppColors.muted),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < logs.length; i++) ...[
                            if (i > 0) const Divider(),
                            _AuditRow(log: logs[i].data()),
                          ],
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log});

  final Map<String, dynamic> log;

  @override
  Widget build(BuildContext context) {
    final createdAt = log['createdAt'];
    final when = createdAt is Timestamp
        ? DateFormat('MMM d, yyyy h:mm a').format(createdAt.toDate())
        : '';
    final approved = log['action'] == 'approved';
    final reason = (log['reason'] as String?)?.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            approved ? Icons.check_circle_outline : Icons.cancel_outlined,
            size: 22,
            color: approved ? AppColors.success : AppColors.danger,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${log['studentName']} was ${log['action']}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'LRN ${log['lrn']}',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                Text(
                  'By ${log['adminName']} (${roleLabel(log['adminRole'] as String?)}) on $when',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
                if (reason != null && reason.isNotEmpty)
                  Text(
                    'Reason: $reason',
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
