import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/app_user.dart';
import '../../services/user_service.dart';
import '../../theme/app_colors.dart';

Future<void> _showSheet(BuildContext context, Widget child) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => child,
  );
}

Future<void> showAddLibrarianSheet(BuildContext context) =>
    _showSheet(context, const _AddLibrarianForm());

Future<void> showEditUserSheet(BuildContext context, AppUser user) =>
    _showSheet(context, _EditUserForm(user: user));

String? _required(String? v) =>
    (v == null || v.trim().isEmpty) ? 'Required' : null;

class _SheetFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SheetFrame({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

class _NameFields extends StatelessWidget {
  final TextEditingController first, middle, last;
  const _NameFields({
    required this.first,
    required this.middle,
    required this.last,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextFormField(
          controller: first,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'First name'),
          validator: _required,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: middle,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Middle name (optional)',
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: last,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Last name'),
          validator: _required,
        ),
      ],
    );
  }
}

// ───────────────────────── Add librarian ─────────────────────────

class _AddLibrarianForm extends StatefulWidget {
  const _AddLibrarianForm();

  @override
  State<_AddLibrarianForm> createState() => _AddLibrarianFormState();
}

class _AddLibrarianFormState extends State<_AddLibrarianForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _first = TextEditingController();
  final _middle = TextEditingController();
  final _last = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await UserService.instance.addLibrarian(
        email: _email.text,
        first: _first.text,
        middle: _middle.text,
        last: _last.text,
      );
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Librarian added')));
    } on AccountExistsException {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'An account with this email already exists.';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not add the account. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _SheetFrame(
      title: 'Add authorized account',
      children: [
        Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Google account email',
                ),
                validator: (v) {
                  final s = (v ?? '').trim();
                  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(s)
                      ? null
                      : 'Enter a valid email';
                },
              ),
              const SizedBox(height: 12),
              _NameFields(first: _first, middle: _middle, last: _last),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Role: Librarian. They can sign in right away with this Google account.',
          style: t.bodySmall,
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Color(0xFFE57373))),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Add librarian'),
        ),
      ],
    );
  }
}

// ───────────────────────── Edit user ─────────────────────────

class _EditUserForm extends StatefulWidget {
  final AppUser user;
  const _EditUserForm({required this.user});

  @override
  State<_EditUserForm> createState() => _EditUserFormState();
}

class _EditUserFormState extends State<_EditUserForm> {
  final _formKey = GlobalKey<FormState>();
  late final _first = TextEditingController(text: widget.user.nameParts.first);
  late final _middle = TextEditingController(
    text: widget.user.nameParts.middle,
  );
  late final _last = TextEditingController(text: widget.user.nameParts.last);
  late final _idDigits = TextEditingController(
    text: _digitsOf(widget.user.studentId),
  );
  late final _age = TextEditingController(
    text: widget.user.age?.toString() ?? '',
  );
  late final _course = TextEditingController(text: widget.user.course ?? '');
  String? _sex;
  bool _saving = false;
  String? _error;

  bool get _isStudent => widget.user.role == 'student';

  static String _digitsOf(String? id) {
    final m = RegExp(r'^GC-(\d{6})$').firstMatch(id ?? '');
    return m?.group(1) ?? '';
  }

  @override
  void initState() {
    super.initState();
    _sex = widget.user.sex;
  }

  @override
  void dispose() {
    _first.dispose();
    _middle.dispose();
    _last.dispose();
    _idDigits.dispose();
    _age.dispose();
    _course.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isStudent && _sex == null) {
      setState(() => _error = 'Please select sex.');
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    final fields = <String, Object?>{
      ...UserService.nameFields(_first.text, _middle.text, _last.text),
    };
    if (_isStudent) {
      fields['studentId'] = 'GC-${_idDigits.text}';
      fields['age'] = int.parse(_age.text);
      fields['sex'] = _sex;
      fields['course'] = _course.text.trim();
    }
    try {
      await UserService.instance.updateInfo(widget.user.email, fields);
      nav.pop();
      messenger.showSnackBar(const SnackBar(content: Text('Changes saved')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save changes. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return _SheetFrame(
      title: 'Edit information',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _NameFields(first: _first, middle: _middle, last: _last),
              if (_isStudent) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _idDigits,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Student ID',
                    prefixText: 'GC-',
                    floatingLabelBehavior: FloatingLabelBehavior.always,
                  ),
                  validator: (v) =>
                      (v ?? '').length == 6 ? null : 'Enter the 6 digits',
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _age,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(labelText: 'Age'),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return (n != null && n >= 10 && n <= 99)
                        ? null
                        : 'Enter a valid age';
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _course,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(labelText: 'Course'),
                  validator: _required,
                ),
                const SizedBox(height: 14),
                Text('Sex', style: t.bodySmall),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final s in const ['Male', 'Female'])
                      ChoiceChip(
                        label: Text(s),
                        selected: _sex == s,
                        selectedColor: AppColors.gold.withValues(alpha: 0.2),
                        onSelected: (_) => setState(() => _sex = s),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(color: Color(0xFFE57373))),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save changes'),
        ),
      ],
    );
  }
}
