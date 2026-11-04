import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../consult/consult_screen.dart';

class QueueScreen extends StatefulWidget {
  const QueueScreen({super.key});

  @override
  State<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends State<QueueScreen> {
  List<Map<String, dynamic>> _queue = [];
  List<Map<String, dynamic>> _mine = [];
  String? _error;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _load();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<AppState>().api;
    try {
      final q = await api.get('/consultations/queue') as List;
      final m = await api.get('/consultations/mine') as List;
      if (!mounted) return;
      setState(() {
        _error = null;
        _queue = q.cast<Map<String, dynamic>>();
        _mine = m.cast<Map<String, dynamic>>().where((c) => c['status'] == 'active').toList();
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _toggle(bool v) async {
    final s = context.read<AppState>();
    try {
      await s.api.post('/volunteers/me/availability', {'available': v});
      await s.refreshMe();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _accept(int id) async {
    try {
      await context.read<AppState>().api.post('/consultations/$id/accept');
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ConsultScreen(consultationId: id)));
      _load();
    } catch (e) {
      if (mounted) showError(context, e);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = context.watch<AppState>().user!;

    return Scaffold(
      appBar: AppBar(title: Text('أهلاً د. ${u.firstName}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
          Panel(
            color: u.isAvailable ? AppColors.calmSoft : AppColors.card,
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(u.isAvailable ? 'أنت متاح الآن' : 'أنت غير متاح',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 2),
                  Text(
                    u.isVerified ? 'تصلك الحالات الجديدة حسب خطورتها' : 'حسابك بانتظار التحقق من الإدارة',
                    style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                  ),
                ]),
              ),
              Switch(value: u.isAvailable, onChanged: u.isVerified ? _toggle : null),
            ]),
          ),
          if (_mine.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionLabel('استشاراتك الجارية'),
            for (final c in _mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Panel(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => ConsultScreen(consultationId: c['id'])))
                      .then((_) => _load()),
                  child: Row(children: [
                    const Icon(Icons.forum_outlined, color: AppColors.calm),
                    const SizedBox(width: 12),
                    Expanded(child: Text(c['parent']?['name'] ?? 'ولي أمر')),
                    const Icon(Icons.chevron_left_rounded),
                  ]),
                ),
              ),
          ],
          const SizedBox(height: 24),
          SectionLabel('بانتظار متطوع', trailing: Text('${_queue.length}')),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AppColors.inkSoft))
          else if (_queue.isEmpty)
            const Panel(
              child: Text('لا توجد حالات الآن. سنُظهر لك أي حالة جديدة هنا.',
                  style: TextStyle(color: AppColors.inkSoft)),
            )
          else
            for (final c in _queue) _QueueCard(data: c, onAccept: () => _accept(c['id'])),
        ]),
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  const _QueueCard({required this.data, required this.onAccept});
  final Map<String, dynamic> data;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final cs = data['case'];
    final child = data['child'];
    final waited = DateTime.now().toUtc().difference(DateTime.parse('${data['created_at']}Z')).inMinutes;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SeverityTag(cs['severity']),
            const Spacer(),
            Text(waited < 1 ? 'الآن' : 'منذ $waited د', style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
          ]),
          const SizedBox(height: 12),
          Text(cs['chemical']?['name_ar'] ?? cs['input_value'] ?? 'مادة غير معروفة',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            [
              '${child['age_years']} سنة',
              if (child['weight_kg'] != null) '${child['weight_kg']} كجم',
              if (cs['symptoms'] != null) 'أعراض: ${cs['symptoms']}',
            ].join(' · '),
            style: const TextStyle(color: AppColors.inkSoft),
          ),
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(46)),
            onPressed: onAccept,
            child: const Text('قبول الحالة'),
          ),
        ]),
      ),
    );
  }
}
