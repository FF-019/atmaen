import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class ChildForm extends StatefulWidget {
  const ChildForm({super.key, this.existing});
  final ChildProfile? existing;

  @override
  State<ChildForm> createState() => _ChildFormState();
}

class _ChildFormState extends State<ChildForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _weight = TextEditingController(text: widget.existing?.weightKg?.toString());
  late final _height = TextEditingController(text: widget.existing?.heightCm?.toStringAsFixed(0));
  late final _allergies = TextEditingController(text: widget.existing?.allergies);
  late final _conditions = TextEditingController(text: widget.existing?.conditions);
  late DateTime? _birth = widget.existing?.birthDate;
  late String? _gender = widget.existing?.gender;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_name, _weight, _height, _allergies, _conditions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _birth ?? DateTime(now.year - 2, now.month, now.day),
      firstDate: DateTime(now.year - 17),
      lastDate: now,
    );
    if (d != null) setState(() => _birth = d);
  }

  double? _num(String s) => double.tryParse(s.trim().replaceAll('٫', '.').replaceAll(',', '.'));

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_birth == null) {
      showError(context, 'اختر تاريخ الميلاد');
      return;
    }
    setState(() => _busy = true);
    final draft = ChildProfile(
      id: widget.existing?.id ?? 0,
      name: _name.text.trim(),
      gender: _gender,
      birthDate: _birth!,
      weightKg: _num(_weight.text),
      heightCm: _num(_height.text),
      allergies: _allergies.text.trim().isEmpty ? null : _allergies.text.trim(),
      conditions: _conditions.text.trim().isEmpty ? null : _conditions.text.trim(),
      ageYears: 0,
      ageMonths: 0,
    );
    try {
      await context.read<AppState>().saveChild(draft, id: widget.existing?.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('حذف ${widget.existing!.name}؟'),
        content: const Text('سيُحذف ملف الطفل وسجل الحالات الخاص به.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: AppColors.signal)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await context.read<AppState>().deleteChild(widget.existing!.id);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'تعديل البيانات' : 'إضافة طفل'),
        actions: [
          if (editing) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          TextFormField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'الاسم'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'اكتب الاسم' : null,
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'male', label: Text('ولد')),
              ButtonSegment(value: 'female', label: Text('بنت')),
            ],
            selected: {if (_gender != null) _gender!},
            emptySelectionAllowed: true,
            showSelectedIcon: false,
            onSelectionChanged: (v) => setState(() => _gender = v.isEmpty ? null : v.first),
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(14),
            child: InputDecorator(
              decoration: const InputDecoration(labelText: 'تاريخ الميلاد', suffixIcon: Icon(Icons.calendar_month_outlined)),
              child: Text(_birth == null ? 'اختر' : intl.DateFormat('d MMMM y', 'ar').format(_birth!)),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: TextFormField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'الوزن', suffixText: 'كجم'),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return null;
                  final n = _num(v);
                  return (n == null || n <= 0 || n > 150) ? 'وزن غير صحيح' : null;
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _height,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'الطول', suffixText: 'سم'),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          const Text('الوزن مهم جداً في حالات الأدوية، حدّثه كل فترة.',
              style: TextStyle(fontSize: 12.5, color: AppColors.inkSoft)),
          const SizedBox(height: 14),
          TextFormField(
            controller: _allergies,
            decoration: const InputDecoration(labelText: 'حساسية (إن وجدت)', hintText: 'مثل: بنسلين، عسل، فول سوداني'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _conditions,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'أمراض مزمنة أو أدوية يأخذها'),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4))
                : const Text('حفظ'),
          ),
        ]),
      ),
    );
  }
}
