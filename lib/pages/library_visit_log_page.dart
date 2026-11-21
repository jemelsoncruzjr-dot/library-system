import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/library_visit_model.dart';
import '../services/library_visit_service.dart';
import 'qr_scanner_page.dart';

class LibraryVisitLogPage extends StatefulWidget {
  final bool isAdmin;
  final String currentUserUid;

  const LibraryVisitLogPage({
    super.key,
    required this.isAdmin,
    required this.currentUserUid,
  });

  @override
  State<LibraryVisitLogPage> createState() => _LibraryVisitLogPageState();
}

class _LibraryVisitLogPageState extends State<LibraryVisitLogPage> {
  final LibraryVisitService _visitService = LibraryVisitService();
  final TextEditingController _lrnController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _purposes = [
    'Study / Reading',
    'Borrow / Return',
    'Research / Computer',
    'Group Work',
    'General Visit',
  ];

  String _selectedPurpose = 'Study / Reading';
  String _searchQuery = '';
  bool _submitting = false;

  @override
  void dispose() {
    _lrnController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatDateTime(Timestamp? ts) {
    if (ts == null) return '-';
    final d = ts.toDate();
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    final hour = d.hour.toString().padLeft(2, '0');
    final min = d.minute.toString().padLeft(2, '0');
    return '${d.year}-$m-$day $hour:$min';
  }

  bool _isToday(Timestamp? ts) {
    if (ts == null) return false;
    final d = ts.toDate();
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  Future<void> _submitVisit() async {
    if (_submitting) return;
    setState(() => _submitting = true);

    try {
      final record = widget.isAdmin
          ? await _visitService.logVisitByLrn(
              rawLrnOrQr: _lrnController.text,
              purpose: _selectedPurpose,
              loggedByUid: widget.currentUserUid,
            )
          : await _visitService.logVisitByStudentUid(
              studentUid: widget.currentUserUid,
              purpose: _selectedPurpose,
            );

      if (!mounted) return;
      if (widget.isAdmin) {
        _lrnController.clear();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Na-log ang visit ni ${record.studentName} (${record.purpose}).',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _openScannerForLrn() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QrScannerPage(
          onStudentFound: (student) {
            _lrnController.text = student.lrn;
            Navigator.of(context).pop();
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final stream = widget.isAdmin
        ? _visitService.streamVisits()
        : _visitService.streamVisits(studentUid: widget.currentUserUid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library Visit Log'),
      ),
      body: Column(
        children: [
          if (_submitting) const LinearProgressIndicator(),
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    widget.isAdmin ? 'Log Student Visit' : 'Log My Library Visit',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (widget.isAdmin) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _lrnController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Student LRN',
                              hintText: 'Ilagay ang LRN o i-scan ang QR',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Scan QR Card',
                          onPressed: _submitting ? null : _openScannerForLrn,
                          icon: const Icon(Icons.qr_code_scanner),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: _selectedPurpose,
                    decoration: const InputDecoration(
                      labelText: 'Purpose of Visit',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _purposes
                        .map(
                          (p) => DropdownMenuItem<String>(
                            value: p,
                            child: Text(p),
                          ),
                        )
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedPurpose = val);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _submitting ? null : _submitVisit,
                    icon: const Icon(Icons.login),
                    label: Text(_submitting ? 'Logging...' : 'Log Visit'),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: widget.isAdmin
                    ? 'Search name, LRN, or purpose...'
                    : 'Search purpose...',
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
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: StreamBuilder<List<LibraryVisitModel>>(
              stream: stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final allVisits = snapshot.data ?? [];
                final todayCount =
                    allVisits.where((v) => _isToday(v.visitedAt)).length;
                final q = _searchQuery.trim().toLowerCase();

                final filtered = allVisits.where((v) {
                  if (q.isEmpty) return true;
                  return v.purpose.toLowerCase().contains(q) ||
                      (widget.isAdmin &&
                          (v.studentName.toLowerCase().contains(q) ||
                              v.studentLrn.toLowerCase().contains(q)));
                }).toList();

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Visits: $todayCount',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          Text('Total Logs: ${filtered.length}'),
                        ],
                      ),
                    ),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(
                              child: Text('Walang visit logs na nakita.'),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 24),
                              itemCount: filtered.length,
                              itemBuilder: (context, index) {
                                final v = filtered[index];
                                return Card(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 5,
                                  ),
                                  child: ListTile(
                                    leading: const Icon(Icons.how_to_reg),
                                    title: Text(
                                      widget.isAdmin ? v.studentName : v.purpose,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (widget.isAdmin)
                                          Text(
                                            'LRN: ${v.studentLrn.isEmpty ? '-' : v.studentLrn} • ${v.purpose}',
                                          ),
                                        Text(
                                          'Time: ${_formatDateTime(v.visitedAt)}',
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}