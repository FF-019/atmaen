import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import 'emergency_service.dart';
import 'guidance_screen.dart';
import 'scanner_screen.dart';

const symptomOptions = <String, String>{
  'none': 'لا توجد أعراض',
  'vomiting': 'قيء',
  'cough': 'سعال أو اختناق',
  'drooling': 'سيلان لعاب',
  'mouth_burn': 'ألم في الفم',
  'drowsy': 'نعاس شديد',
  'breathing': 'صعوبة تنفس',
  'seizure': 'تشنجات',
  'unconscious': 'فاقد الوعي',
};

class IdentifyScreen extends StatefulWidget {
  const IdentifyScreen({super.key});

  @override
  State<IdentifyScreen> createState() => _IdentifyScreenState();
}

class _IdentifyScreenState extends State<IdentifyScreen> {
  final _text = TextEditingController();
  late final EmergencyService _svc = EmergencyService(context.read<AppState>());
  Timer? _debounce;
  List<Chemical> _suggestions = [];
  Chemical? _picked;
  int? _childId;
  final Set<String> _symptoms = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final kids = context.read<AppState>().children;
    if (kids.length == 1) _childId = kids.first.id;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _text.dispose();
    super.dispose();
  }

  void _onType(String v) {
    setState(() => _picked = null); // also refreshes the submit button
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () async {
      final s = await _svc.suggest(v);
      if (mounted) setState(() => _suggestions = s);
    });
  }

  Future<void> _go(String method, {String? value, File? image}) async {
    setState(() => _busy = true);
    try {
      final res = await _svc.analyze(
        method: method,
        value: value,
        image: image,
        chemicalId: _picked?.id,
        childId: _childId,
        symptoms: _symptoms.where((s) => s != 'none').toList(),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => GuidanceScreen(result: res, symptoms: _symptoms.toList(), childId: _childId),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final code = await Navigator.of(context).push<String>(MaterialPageRoute(builder: (_) => const ScannerScreen()));
    if (code != null) _go('barcode', value: code);
  }

  Future<void> _photo() async {
    final x = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 1280, imageQuality: 85);
    if (x != null) _go('image', image: File(x.path));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final kids = state.children;

    return Scaffold(
      appBar: AppBar(title: const Text('ما الذي بلعه الطفل؟')),
      body: Column(children: [
        if (!state.online) const OfflineBanner(),
        Expanded(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 24), children: [
            _CallStrip(),
            const SizedBox(height: 22),
            if (kids.isNotEmpty) ...[
              const SectionLabel('الطفل'),
              SizedBox(
                height: 44,
                child: ListView(scrollDirection: Axis.horizontal, children: [
                  for (final k in kids)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: ChoiceChip(
                        label: Text('${k.name} · ${k.ageText}'),
                        selected: _childId == k.id,
                        onSelected: (_) => setState(() => _childId = k.id),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 20),
            ],
            const SectionLabel('اسم المادة'),
            TextField(
              controller: _text,
              onChanged: _onType,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) => v.trim().length > 1 ? _go('text', value: v.trim()) : null,
              decoration: const InputDecoration(
                hintText: 'مثال: كلور، بنادول، جاز، بطارية ساعة',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            if (_suggestions.isNotEmpty && _picked == null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final c in _suggestions)
                      ListTile(
                        dense: true,
                        title: Text(c.nameAr, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text(c.nameEn, textDirection: TextDirection.ltr),
                        trailing: SeverityTag(c.hazardLevel),
                        onTap: () => setState(() {
                          _picked = c;
                          _text.text = c.nameAr;
                          _suggestions = [];
                        }),
                      ),
                  ]),
                ),
              ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: _InputTile(icon: Icons.qr_code_scanner_rounded, label: 'مسح الباركود', onTap: _busy ? null : _scan),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InputTile(
                  icon: Icons.photo_camera_outlined,
                  label: 'تصوير العبوة',
                  onTap: _busy || !state.online ? null : _photo,
                ),
              ),
            ]),
            const SizedBox(height: 24),
            const SectionLabel('هل تظهر عليه أعراض؟'),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final e in symptomOptions.entries)
                FilterChip(
                  label: Text(e.value),
                  selected: _symptoms.contains(e.key),
                  onSelected: (on) => setState(() {
                    if (e.key == 'none') {
                      _symptoms
                        ..clear()
                        ..addAll(on ? ['none'] : []);
                    } else {
                      _symptoms.remove('none');
                      on ? _symptoms.add(e.key) : _symptoms.remove(e.key);
                    }
                  }),
                ),
            ]),
          ]),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: FilledButton(
              onPressed: _busy || _text.text.trim().length < 2 ? null : () => _go('text', value: _text.text.trim()),
              child: _busy
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
                  : const Text('أعطني الخطوات'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _CallStrip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Panel(
      color: AppColors.signalSoft,
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Row(children: [
        const Expanded(
          child: Text('فاقد الوعي، يتشنج أو لا يتنفس جيداً؟',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.signal,
            minimumSize: const Size(0, 44),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: () => callNumber('997'),
          icon: const Icon(Icons.call_rounded, size: 20),
          label: const Text('997'),
        ),
      ]),
    );
  }
}

class _InputTile extends StatelessWidget {
  const _InputTile({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1,
      child: Panel(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 18),
        child: Column(children: [
          Icon(icon, size: 28, color: AppColors.brandDeep),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}
