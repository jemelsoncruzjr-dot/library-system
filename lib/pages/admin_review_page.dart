import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/admin_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_chip.dart';

BoxDecoration _panel() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.line),
  );
}

class AdminReviewPage extends StatefulWidget {
  const AdminReviewPage({
    super.key,
    required this.studentUid,
    required this.adminUid,
    required this.adminData,
  });

  final String studentUid;
  final String adminUid;
  final Map<String, dynamic> adminData;

  @override
  State<AdminReviewPage> createState() => _AdminReviewPageState();
}

class _AdminReviewPageState extends State<AdminReviewPage> {
  final _service = AdminService();
  late final Future<Uint8List?> _cor = _service.loadCor(widget.studentUid);
  late final Future<Uint8List?> _id = _service.loadId(widget.studentUid);
  bool _busy = false;

  Future<void> _approve(Map<String, dynamic> student) async {
    final messenger = ScaffoldMessenger.of(context);
    Uint8List? corBytes;
    Uint8List? idBytes;
    try {
      corBytes = await _cor;
      idBytes = await _id;
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not load the documents: $e')),
      );
      return;
    }
    if (!mounted) return;

    if (corBytes == null || idBytes == null) {
      final missing = corBytes == null ? 'COR' : 'school ID';
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'This student has not uploaded a $missing. Reject the submission and ask them to upload it.',
          ),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _ApproveDialog(
        name: '${student['firstName']} ${student['lastName']}',
      ),
    );
    if (confirmed != true) return;
    await _save(student, approve: true);
  }

  Future<void> _reject(Map<String, dynamic> student) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null) return;
    await _save(student, approve: false, reason: reason);
  }

  Future<void> _save(
    Map<String, dynamic> student, {
    required bool approve,
    String? reason,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await _service.setStatus(
        studentUid: widget.studentUid,
        student: student,
        adminUid: widget.adminUid,
        admin: widget.adminData,
        approve: approve,
        reason: reason,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(approve ? 'Library card approved.' : 'Submission rejected.'),
        ),
      );
      navigator.pop();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Review student',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: AuthService().userStream(widget.studentUid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data();
          if (data == null) {
            return const Center(child: Text('This student record no longer exists.'));
          }

          final info = _InfoColumn(
            data: data,
            busy: _busy,
            onApprove: () => _approve(data),
            onReject: () => _reject(data),
          );
          final corPanel = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _DocPanel(
                title: 'Certificate of Registration',
                label: 'COR',
                emptyText: 'No COR uploaded yet.',
                future: _cor,
              ),
              const SizedBox(height: 24),
              _DocPanel(
                title: 'School ID',
                label: 'school ID',
                emptyText:
                    'No school ID uploaded yet. Students who submitted before ID verification was added must upload again.',
                future: _id,
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
                    if (constraints.maxWidth < 860) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [info, const SizedBox(height: 24), corPanel],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 4, child: info),
                        const SizedBox(width: 24),
                        Expanded(flex: 5, child: corPanel),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({
    required this.data,
    required this.busy,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> data;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final status = data['validationStatus'] as String? ?? 'not_submitted';
    final birthday = data['birthday'];
    final validatedAt = data['validatedAt'];
    final reason = (data['rejectReason'] as String?)?.trim();

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

    Widget actions;
    if (status == 'pending') {
      actions = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: busy ? null : onApprove,
            icon: const Icon(Icons.check),
            label: const Text('Approve library card'),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: busy ? null : onReject,
            icon: const Icon(Icons.close),
            label: const Text('Reject submission'),
          ),
        ],
      );
    } else if (status == 'validated') {
      final when = validatedAt is Timestamp
          ? ' on ${DateFormat('MMMM d, yyyy').format(validatedAt.toDate())}'
          : '';
      actions = Text(
        'This library card was validated$when.',
        style: const TextStyle(color: AppColors.muted, height: 1.5),
      );
    } else if (status == 'rejected') {
      actions = Text(
        reason == null || reason.isEmpty
            ? 'This submission was rejected. Waiting for the student to upload again.'
            : 'This submission was rejected. Reason: $reason',
        style: const TextStyle(color: AppColors.muted, height: 1.5),
      );
    } else {
      actions = const Text(
        'This student has not uploaded a COR and school ID yet.',
        style: TextStyle(color: AppColors.muted),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _panel(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${data['firstName']} ${data['lastName']}',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(status),
              ),
              const SizedBox(height: 12),
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const Divider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 130,
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
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _panel(),
          child: actions,
        ),
      ],
    );
  }
}

class _DocPanel extends StatelessWidget {
  const _DocPanel({
    required this.title,
    required this.label,
    required this.emptyText,
    required this.future,
  });

  final String title;
  final String label;
  final String emptyText;
  final Future<Uint8List?> future;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          FutureBuilder<Uint8List?>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const SizedBox(
                  height: 200,
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Text('Could not load the $label: ${snapshot.error}');
              }
              final bytes = snapshot.data;
              if (bytes == null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: Text(
                      emptyText,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      height: 420,
                      color: AppColors.paper,
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 5,
                        child: Image.memory(bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Scroll or pinch to zoom in on the details.',
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ApproveDialog extends StatefulWidget {
  const _ApproveDialog({required this.name});

  final String name;

  @override
  State<_ApproveDialog> createState() => _ApproveDialogState();
}

class _ApproveDialogState extends State<_ApproveDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Approve library card?'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${widget.name} will be marked as validated and notified.'),
            const SizedBox(height: 12),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
              title: const Text(
                'I checked that the name and LRN on the school ID match the COR and the student record.',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
          onPressed: _checked ? () => Navigator.pop(context, true) : null,
          child: const Text('Approve'),
        ),
      ],
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  String? _error;

  static const _quickReasons = [
    'The image is blurry or unreadable',
    'The name or LRN does not match',
    'The COR is for a different school year',
    'This is not a COR',
    'The school ID photo is blurry or unreadable',
    'The school ID does not match the student',
    'Please upload your school ID again',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Enter a reason so the student knows what to fix.');
      return;
    }
    Navigator.pop(context, text);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject submission'),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _quickReasons)
                  ActionChip(
                    label: Text(r),
                    onPressed: () => setState(() {
                      _controller.text = r;
                      _error = null;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Reason',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 44),
            backgroundColor: AppColors.danger,
          ),
          onPressed: _submit,
          child: const Text('Reject'),
        ),
      ],
    );
  }
}