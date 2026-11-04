import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/models.dart';
import 'api_client.dart';

/// Local copy of the protocols, chemical names and library.
///
/// First launch uses assets/offline/bundle.json (shipped with the app) so the
/// emergency steps work even if the phone never had internet. After that we
/// refresh from /offline/bundle whenever the version changes.
class OfflineStore {
  Database? _db;
  Map<String, dynamic> _bundle = {};

  String get version => _bundle['version'] ?? '';
  List<Article> get library => [for (final a in _bundle['library'] ?? []) Article.fromJson(a)];

  Future<void> init() async {
    _db = await openDatabase(
      p.join(await getDatabasesPath(), 'atmaen_offline.db'),
      version: 1,
      onCreate: (db, _) async {
        await db.execute('CREATE TABLE bundle (id INTEGER PRIMARY KEY, version TEXT, json TEXT)');
        await db.execute(
          'CREATE TABLE pending_cases (id INTEGER PRIMARY KEY AUTOINCREMENT, payload TEXT, created_at TEXT)',
        );
      },
    );

    final rows = await _db!.query('bundle', limit: 1);
    if (rows.isNotEmpty) {
      _bundle = jsonDecode(rows.first['json'] as String);
    } else {
      final raw = await rootBundle.loadString('assets/offline/bundle.json');
      _bundle = jsonDecode(raw);
      await _save();
    }
  }

  Future<void> _save() async {
    await _db!.insert(
      'bundle',
      {'id': 1, 'version': version, 'json': jsonEncode(_bundle)},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Called on app start and when connectivity comes back. Never throws.
  Future<bool> refresh(ApiClient api) async {
    try {
      final v = await api.get('/offline/version');
      if (v['version'] == version) return false;
      _bundle = Map<String, dynamic>.from(await api.get('/offline/bundle'));
      await _save();
      return true;
    } catch (_) {
      return false;
    }
  }

  // matching -------------------------------------------------------------

  static String normalize(String s) {
    var t = s.toLowerCase().trim();
    t = t.replaceAll(RegExp('[ً-ٰٟـ]'), '');
    const map = {'أ': 'ا', 'إ': 'ا', 'آ': 'ا', 'ى': 'ي', 'ة': 'ه', 'ؤ': 'و', 'ئ': 'ي'};
    map.forEach((k, v) => t = t.replaceAll(k, v));
    t = t.replaceAll(RegExp(r'[^\w\s؀-ۿ]'), ' ');
    return t.split(RegExp(r'\s+')).map((w) => w.startsWith('ال') && w.length > 4 ? w.substring(2) : w).join(' ');
  }

  Map<String, dynamic>? findChemical(String input) {
    final q = normalize(input);
    if (q.length < 2) return null;
    Map<String, dynamic>? best;
    var bestScore = 0.0;
    for (final c in _bundle['chemicals'] ?? []) {
      final names = [c['name_ar'], c['name_en'], ...(c['aliases'] as String).split(',')];
      for (final n in names) {
        final name = normalize(n);
        if (name.isEmpty) continue;
        double score;
        if (name == q) {
          score = 1;
        } else if (name.contains(q) || q.contains(name)) {
          score = 0.85;
        } else {
          score = _similarity(q, name);
        }
        if (score > bestScore) {
          bestScore = score;
          best = Map<String, dynamic>.from(c);
        }
      }
    }
    return bestScore >= 0.75 ? best : null;
  }

  Map<String, dynamic>? findByBarcode(String code) {
    final digits = code.replaceAll(RegExp(r'\D'), '');
    for (final pr in _bundle['products'] ?? []) {
      if (pr['barcode'] == digits) {
        return (_bundle['chemicals'] as List).cast<Map<String, dynamic>>().firstWhere(
              (c) => c['id'] == pr['chemical_id'],
            );
      }
    }
    return null;
  }

  // levenshtein based, good enough for typos in short names
  static double _similarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0;
    final m = a.length, n = b.length;
    var prev = List<int>.generate(n + 1, (i) => i);
    for (var i = 1; i <= m; i++) {
      final cur = List<int>.filled(n + 1, 0);
      cur[0] = i;
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur[j] = [prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y);
      }
      prev = cur;
    }
    return 1 - prev[n] / (m > n ? m : n);
  }

  /// Same shape as the server guidance but built locally. Simpler: no
  /// age-specific steps, so it always tells the parent to call when in doubt.
  Guidance guidanceFor(Map<String, dynamic>? chem, {List<String> symptoms = const []}) {
    final cat = chem?['category'] ?? 'unknown';
    final proto = (_bundle['protocols'][cat] ?? _bundle['protocols']['unknown']) as Map<String, dynamic>;

    const order = ['low', 'moderate', 'high', 'critical'];
    var sev = proto['severity'] as String;
    if (chem != null && order.indexOf(chem['hazard_level']) > order.indexOf(sev)) sev = chem['hazard_level'];
    const redFlags = {'breathing', 'seizure', 'unconscious'};
    if (symptoms.any(redFlags.contains)) sev = 'critical';

    final texts = <(String, String?)>[
      for (final t in _bundle['first_steps']) (t as String, 'hand'),
      for (final s in proto['steps']) (s['text'] as String, s['icon'] as String?),
    ];
    final urgent = sev == 'critical';
    if (urgent) texts.insert(0, ('اتصل بالإسعاف 997 الآن وشغّل مكبر الصوت وتابع الخطوات', 'phone'));

    final steps = [
      for (var i = 0; i < texts.length; i++) GuideStep(i + 1, texts[i].$1, texts[i].$2, urgent && texts[i].$2 == 'phone'),
    ];
    final headline = chem == null ? proto['headline'] as String : '${chem['name_ar']}: ${proto['headline']}';

    return Guidance(
      matched: chem != null,
      confidence: chem == null ? 0 : 0.8,
      chemical: chem == null
          ? null
          : Chemical(
              id: chem['id'],
              nameAr: chem['name_ar'],
              nameEn: chem['name_en'],
              category: cat,
              hazardLevel: chem['hazard_level'],
            ),
      severity: sev,
      callEmergency: urgent,
      headline: headline,
      doNot: [...List<String>.from(_bundle['universal_do_not']), ...List<String>.from(proto['do_not'])],
      steps: steps,
      watchFor: List<String>.from(proto['watch_for']),
      speechText: '$headline. ${steps.map((s) => s.text).join('. ')}',
      disclaimer: _bundle['disclaimer'],
      fromOffline: true,
    );
  }

  // cases opened offline get synced when we're back online
  Future<void> queueCase(Map<String, dynamic> payload) async {
    await _db!.insert('pending_cases', {'payload': jsonEncode(payload), 'created_at': DateTime.now().toIso8601String()});
  }

  Future<int> syncPending(ApiClient api) async {
    final rows = await _db!.query('pending_cases', orderBy: 'id');
    var sent = 0;
    for (final r in rows) {
      try {
        await api.post('/cases', jsonDecode(r['payload'] as String));
        await _db!.delete('pending_cases', where: 'id = ?', whereArgs: [r['id']]);
        sent++;
      } on ApiException catch (e) {
        if (e.isOffline) break;
        // bad payload (child deleted etc.), drop it so it doesn't block the queue
        await _db!.delete('pending_cases', where: 'id = ?', whereArgs: [r['id']]);
      }
    }
    return sent;
  }
}
