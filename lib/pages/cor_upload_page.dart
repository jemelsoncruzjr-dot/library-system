import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/cor_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';

class CorUploadPage extends StatefulWidget {
  const CorUploadPage({super.key});

  @override
  State<CorUploadPage> createState() => _CorUploadPageState();
}

class _CorUploadPageState extends State<CorUploadPage> {
  final _service = CorService();
  final _picker = ImagePicker();

  Uint8List? _corBytes;
  String? _corName;
  Uint8List? _idBytes;
  String? _idName;
  bool _loading = false;
  String? _error;

  Future<void> _pick({required bool forId}) async {
    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      if (forId) {
        _idBytes = bytes;
        _idName = file.name;
      } else {
        _corBytes = bytes;
        _corName = file.name;
      }
      _error = null;
    });
  }

  Future<void> _submit() async {
    final corBytes = _corBytes;
    final idBytes = _idBytes;
    if (corBytes == null || idBytes == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _service.submit(
        uid: FirebaseAuth.instance.currentUser!.uid,
        corBytes: corBytes,
        corFileName: _corName ?? 'cor.jpg',
        idBytes: idBytes,
        idFileName: _idName ?? 'id.jpg',
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on CorInvalidImageException catch (e) {
      setState(() {
        _error =
            'Your ${e.which} file is not a readable image. Choose a JPG or PNG photo.';
      });
    } on CorTooLargeException catch (e) {
      setState(() {
        _error =
            'Your ${e.which} image is too large to submit. Take a smaller photo or screenshot and try again.';
      });
    } catch (e) {
      setState(() => _error = 'Could not submit your documents: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final ready = _corBytes != null && _idBytes != null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('Upload documents', style: textTheme.titleLarge),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Verify your library card',
                  style: textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload two photos: your Certificate of Registration (COR) and your school ID. The librarian will check that the name and LRN match before validating your card. JPG or PNG only.',
                  style: TextStyle(fontSize: 15, height: 1.5, color: AppColors.muted),
                ),
                const SizedBox(height: 24),
                _DocSlot(
                  title: '1. Certificate of Registration',
                  hint: 'Your name, LRN, grade, and section must be readable.',
                  bytes: _corBytes,
                  fileName: _corName,
                  disabled: _loading,
                  onPick: () => _pick(forId: false),
                ),
                const SizedBox(height: 16),
                _DocSlot(
                  title: '2. School ID',
                  hint: 'Take a clear photo of the front of your school ID. Your name and photo must be readable.',
                  bytes: _idBytes,
                  fileName: _idName,
                  disabled: _loading,
                  onPick: () => _pick(forId: true),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  ErrorBanner(_error!),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: (!ready || _loading) ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Submit for review'),
                ),
                if (!ready) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Choose both images to continue.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DocSlot extends StatelessWidget {
  const _DocSlot({
    required this.title,
    required this.hint,
    required this.bytes,
    required this.fileName,
    required this.disabled,
    required this.onPick,
  });

  final String title;
  final String hint;
  final Uint8List? bytes;
  final String? fileName;
  final bool disabled;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final b = bytes;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(
            hint,
            style: const TextStyle(fontSize: 14, height: 1.4, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          if (b == null)
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  foregroundColor: AppColors.green,
                  side: const BorderSide(color: AppColors.green),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: disabled ? null : onPick,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Choose image'),
              ),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: Image.memory(b, fit: BoxFit.contain),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    fileName ?? '',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, color: AppColors.muted),
                  ),
                ),
                TextButton(
                  onPressed: disabled ? null : onPick,
                  child: const Text('Choose a different image'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
