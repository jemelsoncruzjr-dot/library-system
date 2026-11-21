import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/library_card_service.dart';

class QrScannerPage extends StatefulWidget {
  final void Function(StudentCardLookupResult student)? onStudentFound;

  const QrScannerPage({
    super.key,
    this.onStudentFound,
  });

  @override
  State<QrScannerPage> createState() => _QrScannerPageState();
}

class _QrScannerPageState extends State<QrScannerPage> {
  final LibraryCardService _cardService = LibraryCardService();
  final TextEditingController _manualLrnController = TextEditingController();
  final MobileScannerController _scannerController = MobileScannerController();

  bool _cameraEnabled = true;
  bool _searching = false;
  String? _lastScannedRaw;
  String? _errorText;
  StudentCardLookupResult? _foundStudent;

  @override
  void dispose() {
    _manualLrnController.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _lookupInput(String rawInput) async {
    final cleaned = rawInput.trim();
    if (cleaned.isEmpty || _searching) return;

    setState(() {
      _searching = true;
      _errorText = null;
    });

    try {
      final result = await _cardService.lookupStudentByLrn(cleaned);
      if (!mounted) return;

      if (result == null) {
        setState(() {
          _foundStudent = null;
          _errorText = 'Walang student na nahanap para sa "$cleaned".';
        });
      } else {
        setState(() {
          _foundStudent = result;
          _errorText = null;
        });
        if (widget.onStudentFound != null) {
          widget.onStudentFound!(result);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorText = 'Error sa lookup: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _searching = false);
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_searching) return;
    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.trim().isNotEmpty && raw.trim() != _lastScannedRaw) {
        _lastScannedRaw = raw.trim();
        _manualLrnController.text = _cardService.extractLrnFromRawScan(raw);
        _lookupInput(raw);
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final student = _foundStudent;

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Scanner & LRN Lookup'),
        actions: [
          IconButton(
            tooltip: _cameraEnabled ? 'Disable Camera' : 'Enable Camera',
            icon: Icon(
              _cameraEnabled ? Icons.videocam : Icons.videocam_off,
            ),
            onPressed: () {
              setState(() {
                _cameraEnabled = !_cameraEnabled;
                if (_cameraEnabled) {
                  _lastScannedRaw = null;
                }
              });
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_cameraEnabled)
              SizedBox(
                height: 220,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: MobileScanner(
                    controller: _scannerController,
                    onDetect: _onDetect,
                    errorBuilder: (context, error, child) {
  return Container(
    color: Colors.black12,
    alignment: Alignment.center,
    padding: const EdgeInsets.all(16),
    child: Text(
      'Hindi ma-access ang camera (${error.errorCode.name}). Gamitin ang Manual LRN sa ibaba.',
      textAlign: TextAlign.center,
    ),
  );
},
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: const Text(
                  'Naka-off ang camera scanner. Gamitin ang Manual LRN lookup sa ibaba.',
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 14),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Manual LRN Fallback',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _manualLrnController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              hintText: 'Ilagay ang 12-digit LRN',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            onSubmitted: _lookupInput,
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: _searching
                              ? null
                              : () => _lookupInput(_manualLrnController.text),
                          child: Text(_searching ? '...' : 'Lookup'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            if (_searching) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 12),
              Card(
                color: Colors.red.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    _errorText!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
            ],
            if (student != null) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  title: Text(
                    student.fullName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('LRN: ${student.lrn}'),
                      Text('UID: ${student.uid}'),
                      const SizedBox(height: 4),
                      Text(
                        student.isValidated
                            ? 'Status: VALIDATED'
                            : 'Status: NOT VALIDATED',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: student.isValidated
                              ? Colors.green.shade800
                              : Colors.red.shade800,
                        ),
                      ),
                    ],
                  ),
                  trailing: widget.onStudentFound != null
                      ? FilledButton.tonal(
                        style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                          onPressed: () => widget.onStudentFound!(student),
                          child: const Text('Select'),
                        )
                      : null,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}