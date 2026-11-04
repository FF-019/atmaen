import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import '../children/child_form.dart';
import '../emergency/identify_screen.dart';
import '../library/library_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  List<Map<String, dynamic>> _recent = [];

  @override
  void initState() {
    super.initState();
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    try {
      final rows = await context.read<AppState>().api.get('/cases') as List;
      if (mounted) setState(() => _recent = rows.take(3).cast<Map<String, dynamic>>().toList());
    } catch (_) {}
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'صباح الخير';
    if (h < 18) return 'مساء الخير';
    return 'مساء النور';
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return SafeArea(
      child: Column(children: [
        if (!s.online) const OfflineBanner(),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              await s.loadChildren();
              await _loadRecent();
            },
            child: ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 24), children: [
              Row(children: [
                const Logo(size: 36),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('${_greeting()}، ${s.user?.firstName ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge),
                ),
              ]),
              const SizedBox(height: 24),
              _EmergencyCard(
                onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const IdentifyScreen())),
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _QuickCall(number: '997', label: 'الهلال الأحمر', color: AppColors.signal),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _QuickCall(number: '937', label: 'الاستشارات الطبية', color: AppColors.brandDeep),
                ),
              ]),
              const SizedBox(height: 28),
              SectionLabel('أطفالي',
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChildForm())),
                    child: const Text('إضافة'),
                  )),
              if (s.children.isEmpty)
                Panel(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChildForm())),
                  child: const Row(children: [
                    Icon(Icons.add_circle_outline_rounded, color: AppColors.brand),
                    SizedBox(width: 12),
                    Expanded(child: Text('أضف طفلك ليحصل على إرشادات تناسب عمره ووزنه')),
                  ]),
                )
              else
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: s.children.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (_, i) {
                      final k = s.children[i];
                      return SizedBox(
                        width: 150,
                        child: Panel(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(k.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const Spacer(),
                            Text([k.ageText, if (k.weightKg != null) '${k.weightKg!.toStringAsFixed(0)} كجم'].join(' · '),
                                style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
              if (_recent.isNotEmpty) ...[
                const SizedBox(height: 28),
                const SectionLabel('آخر الحالات'),
                Panel(
                  padding: EdgeInsets.zero,
                  child: Column(children: [
                    for (final (i, c) in _recent.indexed) ...[
                      if (i > 0) const Divider(height: 1),
                      ListTile(
                        title: Text(c['chemical']?['name_ar'] ?? c['input_value'] ?? 'غير معروف'),
                        subtitle: Text(intl.DateFormat('d MMM، HH:mm', 'ar').format(DateTime.parse(c['created_at']).toLocal())),
                        trailing: SeverityTag(c['severity']),
                      ),
                    ],
                  ]),
                ),
              ],
              const SizedBox(height: 28),
              const SectionLabel('للوقاية'),
              Panel(
                color: AppColors.mist,
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute(builder: (_) => const LibraryScreen(initialCategory: 'prevention'))),
                child: const Row(children: [
                  Icon(Icons.shield_outlined, color: AppColors.brandDeep),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('معظم الحوادث تحدث من أدوية الكبار والمنظفات تحت المغسلة. افحص بيتك في 5 دقائق.'),
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _EmergencyCard extends StatelessWidget {
  const _EmergencyCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ink,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.signal, borderRadius: BorderRadius.circular(8)),
              child: const Text('طوارئ', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 14),
            const Text('طفلك بلع مادة؟',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            const Text('اكتب الاسم، امسح الباركود أو صوّر العبوة',
                style: TextStyle(color: Colors.white70, fontSize: 14)),
            const SizedBox(height: 18),
            Row(children: [
              for (final icon in [Icons.keyboard_alt_outlined, Icons.qr_code_scanner_rounded, Icons.photo_camera_outlined])
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 8),
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, color: AppColors.aqua, size: 21),
                ),
              const Spacer(),
              const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _QuickCall extends StatelessWidget {
  const _QuickCall({required this.number, required this.label, required this.color});
  final String number;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: () => callNumber(number),
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Icon(Icons.call_rounded, color: color, size: 22),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(number, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: color)),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.inkSoft)),
        ]),
      ]),
    );
  }
}
