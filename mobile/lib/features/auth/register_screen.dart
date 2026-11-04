import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.asVolunteer = false});
  final bool asVolunteer;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _specialty = TextEditingController();
  final _institution = TextEditingController();
  final _license = TextEditingController();
  bool _busy = false;

  bool get _vol => widget.asVolunteer;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _pass, _specialty, _institution, _license]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<AppState>().register({
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        'password': _pass.text,
        'role': _vol ? 'volunteer' : 'parent',
        if (_vol) ...{
          'specialty': _specialty.text.trim(),
          'institution': _institution.text.trim(),
          'license_no': _license.text.trim().isEmpty ? null : _license.text.trim(),
        },
      });
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _required(String? v) => (v == null || v.trim().length < 2) ? 'هذا الحقل مطلوب' : null;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            Text(_vol ? 'انضم كمتطوع طبي' : 'حساب جديد', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              _vol
                  ? 'بعد التسجيل تراجع الإدارة بياناتك، وبعد التحقق تبدأ باستقبال الحالات وتُحسب ساعاتك التطوعية.'
                  : 'أضف أطفالك بعد التسجيل حتى تكون الإرشادات مناسبة لعمرهم ووزنهم.',
              style: const TextStyle(color: AppColors.inkSoft, height: 1.6),
            ),
            const SizedBox(height: 24),
            TextFormField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم'), validator: _required),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'البريد الإلكتروني'),
              validator: (v) => (v == null || !v.contains('@')) ? 'اكتب بريداً صحيحاً' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رقم الجوال (اختياري)', hintText: '05xxxxxxxx'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pass,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'كلمة المرور', helperText: '8 أحرف على الأقل، حروف وأرقام'),
              validator: (v) {
                if (v == null || v.length < 8) return '8 أحرف على الأقل';
                if (!RegExp(r'[0-9]').hasMatch(v) || !RegExp(r'[A-Za-z]').hasMatch(v)) {
                  return 'استخدم حروفاً وأرقاماً';
                }
                return null;
              },
            ),
            if (_vol) ...[
              const SizedBox(height: 24),
              const SectionLabel('البيانات المهنية'),
              TextFormField(
                controller: _specialty,
                decoration: const InputDecoration(labelText: 'التخصص', hintText: 'طب أطفال، طوارئ، طالب امتياز...'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _institution,
                decoration: const InputDecoration(labelText: 'جهة العمل أو الدراسة'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _license,
                textDirection: TextDirection.ltr,
                decoration: const InputDecoration(labelText: 'رقم الترخيص من الهيئة (إن وجد)'),
              ),
            ],
            const SizedBox(height: 28),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                  : const Text('إنشاء الحساب'),
            ),
          ]),
        ),
      ),
    );
  }
}
