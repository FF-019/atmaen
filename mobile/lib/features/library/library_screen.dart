import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

const _categories = <String, (String, IconData)>{
  'ingestion': ('البلع والتسمم', Icons.science_outlined),
  'prevention': ('الوقاية', Icons.shield_outlined),
  'choking': ('الاختناق', Icons.air_rounded),
  'burns': ('الحروق', Icons.local_fire_department_outlined),
  'bleeding': ('النزيف', Icons.healing_outlined),
  'general': ('عام', Icons.favorite_border_rounded),
};

/// The library always reads from the offline store, so it works the same
/// with or without internet. The store refreshes itself in the background.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key, this.initialCategory});
  final String? initialCategory;

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  late String? _cat = widget.initialCategory;

  @override
  Widget build(BuildContext context) {
    final all = context.watch<AppState>().offline.library;
    final items = _cat == null ? all : all.where((a) => a.category == _cat).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('مكتبة الإسعافات')),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 24), children: [
        const Text('كل المحتوى هنا محفوظ على جهازك ويعمل بدون إنترنت.',
            style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
        const SizedBox(height: 14),
        SizedBox(
          height: 42,
          child: ListView(scrollDirection: Axis.horizontal, children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ChoiceChip(label: const Text('الكل'), selected: _cat == null, onSelected: (_) => setState(() => _cat = null)),
            ),
            for (final e in _categories.entries)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: ChoiceChip(
                  label: Text(e.value.$1),
                  selected: _cat == e.key,
                  onSelected: (_) => setState(() => _cat = e.key),
                ),
              ),
          ]),
        ),
        const SizedBox(height: 16),
        for (final a in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Panel(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ArticleScreen(article: a))),
              child: Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(14)),
                  child: Icon(_categories[a.category]?.$2 ?? Icons.article_outlined, color: AppColors.brandDeep),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5)),
                    if (a.summary != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text(a.summary!, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
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

class ArticleScreen extends StatelessWidget {
  const ArticleScreen({super.key, required this.article});
  final Article article;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ListView(padding: const EdgeInsets.fromLTRB(24, 0, 24, 32), children: [
        Text(_categories[article.category]?.$1 ?? '',
            style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Text(article.title, style: Theme.of(context).textTheme.headlineMedium),
        if (article.summary != null) ...[
          const SizedBox(height: 10),
          Text(article.summary!, style: const TextStyle(fontSize: 16, color: AppColors.inkSoft)),
        ],
        const SizedBox(height: 26),
        for (final (i, step) in article.steps.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              SizedBox(
                width: 34,
                child: Text('${i + 1}'.padLeft(2, '0'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.aqua)),
              ),
              Expanded(child: Text(step, style: const TextStyle(fontSize: 16.5, height: 1.7))),
            ]),
          ),
      ]),
    );
  }
}
