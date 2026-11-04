import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';
import '../consult/consult_screen.dart';
import 'emergency_service.dart';

class GuidanceScreen extends StatefulWidget {
  const GuidanceScreen({super.key, required this.result, this.symptoms = const [], this.childId});

  final EmergencyResult result;
  final List<String> symptoms;
  final int? childId;

  @override
  State<GuidanceScreen> createState() => _GuidanceScreenState();
}

class _GuidanceScreenState extends State<GuidanceScreen> {
  final _tts = FlutterTts();
  bool _speaking = false;
  int _current = 0;

  Guidance get g => widget.result.guidance;

  @override
  void initState() {
    super.initState();
    _tts
      ..setLanguage('ar-SA')
      ..setSpeechRate(0.42)
      ..setCompletionHandler(() {
        if (mounted) setState(() => _speaking = false);
      });

    // read it out automatically for critical cases, the parent's hands are busy
    if (g.callEmergency) WidgetsBinding.instance.addPostFrameCallback((_) => _toggleSpeech());
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeech() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
    } else {
      setState(() => _speaking = true);
      await _tts.speak(g.speechText);
    }
  }

  Future<void> _consult() async {
    final state = context.read<AppState>();
    final caseId = widget.result.caseId;
    if (!state.loggedIn || caseId == null) {
      showError(context, 'سجّل الدخول وأضف طفلك حتى تتمكن من التواصل مع متطوع');
      return;
    }
    try {
      final c = await state.api.post('/consultations', {'case_id': caseId});
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsultScreen(consultationId: c['id'])));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  void _emergencySheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.paper,
      builder: (_) => _EmergencySheet(caseId: widget.result.caseId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sevColor = AppColors.severity(g.severity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('خطوات الإسعاف'),
        actions: [
          IconButton(
            tooltip: _speaking ? 'إيقاف' : 'اقرأ بصوت',
            icon: Icon(_speaking ? Icons.stop_circle_outlined : Icons.volume_up_rounded),
            onPressed: _toggleSpeech,
          ),
        ],
      ),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 140), children: [
        if (g.fromOffline)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('إرشادات من النسخة المحفوظة على جهازك',
                style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
          ),
        Row(children: [
          SeverityTag(g.severity),
          const Spacer(),
          if (g.matched)
            Text('تطابق ${(g.confidence * 100).round()}٪',
                style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        ]),
        const SizedBox(height: 12),
        Text(g.headline, style: Theme.of(context).textTheme.titleLarge?.copyWith(height: 1.45)),
        if (!g.matched && g.candidates.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('هل تقصد: ${g.candidates.map((c) => c.nameAr).take(3).join('، ')}؟',
              style: const TextStyle(color: AppColors.brandDeep)),
        ],
        const SizedBox(height: 20),
        if (g.callEmergency) ...[
          _BigCall(color: sevColor),
          const SizedBox(height: 20),
        ],
        const SectionLabel('افعل الآن'),
        for (final s in g.steps)
          _StepRow(
            step: s,
            active: s.order - 1 == _current,
            done: s.order - 1 < _current,
            onTap: () => setState(() => _current = s.order),
          ),
        const SizedBox(height: 18),
        const SectionLabel('لا تفعل'),
        Panel(
          color: AppColors.signalSoft,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final d in g.doNot)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.close_rounded, size: 18, color: AppColors.signal),
                  const SizedBox(width: 10),
                  Expanded(child: Text(d, style: const TextStyle(height: 1.5, color: AppColors.ink))),
                ]),
              ),
          ]),
        ),
        const SizedBox(height: 18),
        const SectionLabel('راقب هذه العلامات'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final w in g.watchFor)
            Chip(label: Text(w), avatar: const Icon(Icons.visibility_outlined, size: 16)),
        ]),
        const SizedBox(height: 22),
        Text(g.disclaimer, style: const TextStyle(fontSize: 12.5, color: AppColors.inkSoft, height: 1.6)),
      ]),
      bottomSheet: Container(
        color: AppColors.paper,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: SafeArea(
          top: false,
          child: Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _emergencySheet,
                icon: const Icon(Icons.location_on_outlined),
                label: const Text('أقرب مستشفى'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _consult,
                icon: const Icon(Icons.medical_services_outlined),
                label: const Text('كلّم متطوع'),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _BigCall extends StatelessWidget {
  const _BigCall({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => callNumber('997'),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(children: [
            Icon(Icons.call_rounded, color: Colors.white, size: 32),
            SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('اتصل بالإسعاف 997',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('ابقَ على الخط، والخطوات تحت',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.active, required this.done, required this.onTap});

  final GuideStep step;
  final bool active;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = step.warning ? AppColors.signal : AppColors.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        decoration: BoxDecoration(
          color: active ? Colors.white : (done ? AppColors.mist.withValues(alpha: 0.5) : Colors.white),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: active ? accent : AppColors.line, width: active ? 1.6 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? AppColors.calm : (active ? accent : AppColors.mist),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: done
                    ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
                    : Icon(stepIcon(step.icon), color: active ? Colors.white : AppColors.brandDeep, size: 19),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  step.text,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.6,
                    color: done ? AppColors.inkSoft : AppColors.ink,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class _EmergencySheet extends StatefulWidget {
  const _EmergencySheet({this.caseId});
  final int? caseId;

  @override
  State<_EmergencySheet> createState() => _EmergencySheetState();
}

class _EmergencySheetState extends State<_EmergencySheet> {
  List<Hospital> _hospitals = [];
  String? _share;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final svc = EmergencyService(context.read<AppState>());
    if (widget.caseId != null) {
      final info = await svc.emergencyInfo(widget.caseId!);
      if (info != null) {
        _share = info['share_text'];
        _hospitals = [
          for (final h in info['hospitals'])
            Hospital(h['name_ar'], (h['distance_km'] as num).toDouble(), h['phone'], h['maps']),
        ];
      }
    }
    if (_hospitals.isEmpty) _hospitals = await svc.nearestHospitals();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('الطوارئ القريبة منك', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 14),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_hospitals.isEmpty)
          const Text('لم نتمكن من تحديد موقعك. فعّل الموقع أو اتصل 997.')
        else
          for (final h in _hospitals)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Panel(
                onTap: () => launchUrl(Uri.parse(h.mapsUrl), mode: LaunchMode.externalApplication),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(children: [
                  const Icon(Icons.local_hospital_outlined, color: AppColors.brandDeep),
                  const SizedBox(width: 12),
                  Expanded(child: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                  Text('${h.distanceKm.toStringAsFixed(1)} كم', style: const TextStyle(color: AppColors.inkSoft)),
                ]),
              ),
            ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.signal),
              onPressed: () => callNumber('997'),
              icon: const Icon(Icons.call_rounded),
              label: const Text('997'),
            ),
          ),
          if (_share != null) ...[
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                // sms keeps working on weak networks, better than whatsapp here
                onPressed: () => launchUrl(Uri(scheme: 'sms', queryParameters: {'body': _share!})),
                icon: const Icon(Icons.share_location_outlined),
                label: const Text('أرسل موقعي'),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
