import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class HoursScreen extends StatefulWidget {
  const HoursScreen({super.key});

  @override
  State<HoursScreen> createState() => _HoursScreenState();
}

class _HoursScreenState extends State<HoursScreen> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await context.read<AppState>().api.get('/volunteers/me/hours');
      if (mounted) setState(() => _data = Map<String, dynamic>.from(d));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const Text('ساعاتي التطوعية')),
      body: d == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
                Panel(
                  color: AppColors.ink,
                  padding: const EdgeInsets.all(22),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('إجمالي الساعات', style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 4),
                    Text('${d['total_hours']}',
                        style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.w700, height: 1.1)),
                    const SizedBox(height: 14),
                    Row(children: [
                      _stat('${d['consultations']}', 'استشارة'),
                      _stat('${d['last_30_days_hours']}', 'ساعة هذا الشهر'),
                      _stat(d['avg_rating'] == null ? '-' : '${d['avg_rating']}', 'التقييم'),
                    ]),
                  ]),
                ),
                const SizedBox(height: 24),
                const SectionLabel('السجل'),
                for (final row in d['log'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(children: [
                        SeverityTag(row['severity']),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            row['date'] == null
                                ? ''
                                : intl.DateFormat('d MMM y', 'ar').format(DateTime.parse(row['date']).toLocal()),
                          ),
                        ),
                        Text('${(row['minutes'] as num).round()} د', style: const TextStyle(color: AppColors.inkSoft)),
                      ]),
                    ),
                  ),
              ]),
            ),
    );
  }

  Widget _stat(String v, String label) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(v, style: const TextStyle(color: AppColors.aqua, fontSize: 18, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ]),
      );
}
