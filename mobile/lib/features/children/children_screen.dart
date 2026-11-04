import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../widgets/common.dart';
import 'child_form.dart';

class ChildrenScreen extends StatelessWidget {
  const ChildrenScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: const Text('أطفالي')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChildForm())),
        icon: const Icon(Icons.add_rounded),
        label: const Text('طفل جديد'),
      ),
      body: s.children.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('لم تضف أي طفل بعد.\nالعمر والوزن يساعدان المتطوع على تقدير الخطورة.',
                    textAlign: TextAlign.center, style: TextStyle(color: AppColors.inkSoft, height: 1.7)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
              itemCount: s.children.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (_, i) {
                final k = s.children[i];
                return Panel(
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ChildForm(existing: k))),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.mist,
                      child: Text(k.name.characters.first,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.brandDeep)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(k.name, style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          [
                            k.ageText,
                            if (k.weightKg != null) '${k.weightKg} كجم',
                            if (k.heightCm != null) '${k.heightCm!.toStringAsFixed(0)} سم',
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.inkSoft),
                        ),
                        if (k.allergies != null && k.allergies!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text('حساسية: ${k.allergies}',
                                style: const TextStyle(color: AppColors.signal, fontSize: 13)),
                          ),
                      ]),
                    ),
                    const Icon(Icons.chevron_left_rounded, color: AppColors.inkSoft),
                  ]),
                );
              },
            ),
    );
  }
}
