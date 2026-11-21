import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/auth_shell.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _lrn = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  final _firstName = TextEditingController();
  final _middleName = TextEditingController();
  final _lastName = TextEditingController();
  final _section = TextEditingController();
  final _birthday = TextEditingController();
  final _address = TextEditingController();
  final _auth = AuthService();

  static const _grades = [
    'Grade 7',
    'Grade 8',
    'Grade 9',
    'Grade 10',
    'Grade 11',
    'Grade 12',
  ];
  static const _genders = ['Male', 'Female'];

  String? _grade;
  String? _gender;
  DateTime? _birthdayValue;
  bool _consent = false;
  bool _loading = false;
  bool _hidePassword = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _lrn,
      _email,
      _password,
      _confirm,
      _firstName,
      _middleName,
      _lastName,
      _section,
      _birthday,
      _address,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? 'Enter your $label' : null;

  Future<void> _pickBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthdayValue ?? DateTime(now.year - 15),
      firstDate: DateTime(now.year - 40),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _birthdayValue = picked;
        _birthday.text = DateFormat('MMMM d, yyyy').format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_consent) {
      setState(() => _error = 'Agree to the data privacy notice to continue.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.register(
        lrn: _lrn.text.trim(),
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        middleName: _middleName.text.trim(),
        grade: _grade!,
        section: _section.text.trim(),
        gender: _gender!,
        birthday: _birthdayValue!,
        address: _address.text.trim(),
      );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on LrnTakenException {
      setState(() => _error = 'This LRN is already registered. Check the number or contact the library.');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'email-already-in-use' => 'This Gmail is already registered. Try signing in instead.',
          'weak-password' => 'The password is too weak. Use at least 8 characters.',
          'invalid-email' => 'This email address is not valid.',
          _ => 'Could not create the account: ${e.message}',
        };
      });
    } catch (e) {
      setState(() => _error = 'Could not create the account: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _divider() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 28),
        child: Divider(),
      );

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthShell(
      maxWidth: 620,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back, size: 18),
                label: const Text('Back to sign in'),
              ),
            ),
            const SizedBox(height: 8),
            Text('Create your account', style: textTheme.headlineMedium),
            const SizedBox(height: 8),
            const Text(
              'Use your LRN and Gmail. You will upload your COR after signing in.',
              style: TextStyle(fontSize: 16, color: AppColors.muted),
            ),
            const SizedBox(height: 32),
            FormSection(
              title: 'Account',
              children: [
                TextFormField(
                  controller: _lrn,
                  keyboardType: TextInputType.number,
                  maxLength: 12,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'LRN',
                    helperText: '12 digits, numbers only',
                    counterText: '',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your LRN';
                    if (v.trim().length != 12) return 'The LRN must be 12 digits';
                    return null;
                  },
                ),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Gmail'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your Gmail';
                    if (!v.trim().toLowerCase().endsWith('@gmail.com')) {
                      return 'Use a Gmail address (ends with @gmail.com)';
                    }
                    return null;
                  },
                ),
                FieldRow(
                  children: [
                    TextFormField(
                      controller: _password,
                      obscureText: _hidePassword,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        suffixIcon: IconButton(
                          tooltip: _hidePassword ? 'Show password' : 'Hide password',
                          icon: Icon(
                            _hidePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                          onPressed: () =>
                              setState(() => _hidePassword = !_hidePassword),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Enter a password';
                        if (v.length < 8) return 'Use at least 8 characters';
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _hidePassword,
                      decoration:
                          const InputDecoration(labelText: 'Confirm password'),
                      validator: (v) =>
                          v != _password.text ? 'Passwords do not match' : null,
                    ),
                  ],
                ),
              ],
            ),
            _divider(),
            FormSection(
              title: 'Personal details',
              children: [
                FieldRow(
                  children: [
                    TextFormField(
                      controller: _firstName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'First name'),
                      validator: (v) => _required(v, 'first name'),
                    ),
                    TextFormField(
                      controller: _lastName,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Last name'),
                      validator: (v) => _required(v, 'last name'),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _middleName,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Middle name (optional)',
                  ),
                ),
                FieldRow(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _gender,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: _genders
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _gender = v),
                      validator: (v) => v == null ? 'Select your gender' : null,
                    ),
                    TextFormField(
                      controller: _birthday,
                      readOnly: true,
                      onTap: _pickBirthday,
                      decoration: const InputDecoration(
                        labelText: 'Birthday',
                        suffixIcon: Icon(Icons.calendar_today_outlined, size: 20),
                      ),
                      validator: (v) => _required(v, 'birthday'),
                    ),
                  ],
                ),
                TextFormField(
                  controller: _address,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Address'),
                  validator: (v) => _required(v, 'address'),
                ),
              ],
            ),
            _divider(),
            FormSection(
              title: 'School',
              children: [
                FieldRow(
                  children: [
                    DropdownButtonFormField<String>(
                      value: _grade,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Grade level'),
                      items: _grades
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (v) => setState(() => _grade = v),
                      validator: (v) => v == null ? 'Select your grade level' : null,
                    ),
                    TextFormField(
                      controller: _section,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(labelText: 'Section'),
                      validator: (v) => _required(v, 'section'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            CheckboxListTile(
              value: _consent,
              onChanged: (v) => setState(() => _consent = v ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'I agree that the library may use my personal information to validate my library card.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              ErrorBanner(_error!),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Create account'),
            ),
          ],
        ),
      ),
    );
  }
}