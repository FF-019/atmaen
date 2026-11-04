import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _editName(BuildContext context) async {
    final s = context.read<AppState>();
    final name = TextEditingController(text: s.user!.name);
    final phone = TextEditingController(text: s.user!.phone);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تعديل البيانات'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'الاسم')),
          const SizedBox(height: 12),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'الجوال'),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حفظ')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await s.api.patch('/auth/me', {'name': name.text.trim(), 'phone': phone.text.trim()});
      await s.refreshMe();
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final u = s.user!;

    return Scaffold(
      appBar: AppBar(title: const Text('حسابي')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        Panel(
          child: Row(children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.ink,
              child: Text(u.name.characters.first,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(u.name, style: Theme.of(context).textTheme.titleMedium),
                Text(u.email, textDirection: TextDirection.ltr, style: const TextStyle(color: AppColors.inkSoft)),
                if (u.isVolunteer)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      u.isVerified ? '${u.specialty} · متطوع موثّق' : 'بانتظار التحقق من الإدارة',
                      style: TextStyle(color: u.isVerified ? AppColors.calm : AppColors.amber, fontSize: 13),
                    ),
                  ),
              ]),
            ),
            IconButton(onPressed: () => _editName(context), icon: const Icon(Icons.edit_outlined)),
          ]),
        ),
        const SizedBox(height: 20),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ListTile(
              leading: const Icon(Icons.cloud_done_outlined),
              title: const Text('النسخة المحفوظة للعمل بدون إنترنت'),
              subtitle: Text('الإصدار ${s.offline.version}', textDirection: TextDirection.ltr),
              trailing: IconButton(
                icon: const Icon(Icons.refresh_rounded),
                onPressed: () async {
                  final changed = await s.offline.refresh(s.api);
                  if (context.mounted) showError(context, changed ? 'تم تحديث المحتوى' : 'المحتوى محدث');
                },
              ),
            ),
            const Divider(height: 1),
            const ListTile(
              leading: Icon(Icons.lock_outline_rounded),
              title: Text('الخصوصية'),
              subtitle: Text('بيانات أطفالك مشفرة ولا تظهر إلا للمتطوع الذي يقبل حالتك'),
            ),
          ]),
        ),
        const SizedBox(height: 28),
        OutlinedButton(
          onPressed: () => s.logout(),
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.signal),
          child: const Text('تسجيل الخروج'),
        ),
      ]),
    );
  }
}
