import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/app_state.dart';
import '../../core/config.dart';
import '../../core/theme.dart';
import '../../models/models.dart';
import '../../widgets/common.dart';

class ConsultScreen extends StatefulWidget {
  const ConsultScreen({super.key, required this.consultationId});
  final int consultationId;

  @override
  State<ConsultScreen> createState() => _ConsultScreenState();
}

class _ConsultScreenState extends State<ConsultScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  WebSocketChannel? _ws;
  StreamSubscription? _wsSub;
  Timer? _poll;

  Consultation? _c;
  Map<String, dynamic>? _child;
  Map<String, dynamic>? _case;
  final List<ChatMessage> _messages = [];
  bool _otherTyping = false;
  Timer? _typingTimer;

  AppState get _state => context.read<AppState>();
  bool get _isVolunteer => _state.user?.isVolunteer ?? false;
  int get _me => _state.user!.id;

  @override
  void initState() {
    super.initState();
    _load();
    _connect();
    // fallback in case the socket can't connect (some networks block ws)
    _poll = Timer.periodic(const Duration(seconds: 8), (_) => _load(quiet: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    _typingTimer?.cancel();
    _wsSub?.cancel();
    _ws?.sink.close();
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load({bool quiet = false}) async {
    try {
      final d = await _state.api.get('/consultations/${widget.consultationId}');
      if (!mounted) return;
      setState(() {
        _c = Consultation.fromJson(d);
        _child = d['child'];
        _case = d['case'];
        final known = _messages.map((m) => m.id).toSet();
        for (final m in d['messages']) {
          if (!known.contains(m['id'])) _messages.add(ChatMessage.fromJson(m));
        }
      });
      _toBottom();
    } catch (e) {
      if (!quiet && mounted) showError(context, e);
    }
  }

  void _connect() {
    final url = '${AppConfig.wsUrl}/api/consultations/${widget.consultationId}/ws?token=${_state.api.token}';
    try {
      _ws = WebSocketChannel.connect(Uri.parse(url));
      _wsSub = _ws!.stream.listen(_onEvent, onError: (_) {}, onDone: () {});
    } catch (_) {
      // polling covers it
    }
  }

  void _onEvent(dynamic raw) {
    final ev = jsonDecode(raw as String) as Map<String, dynamic>;
    switch (ev['type']) {
      case 'message':
        final m = ChatMessage.fromJson(ev['message']);
        if (_messages.every((x) => x.id != m.id)) {
          setState(() {
            _messages.add(m);
            _otherTyping = false;
          });
          _toBottom();
        }
      case 'status':
        _load(quiet: true);
      case 'typing':
        if (ev['user_id'] != _me) {
          setState(() => _otherTyping = true);
          _typingTimer?.cancel();
          _typingTimer = Timer(const Duration(seconds: 3), () {
            if (mounted) setState(() => _otherTyping = false);
          });
        }
    }
  }

  void _toBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      final m = await _state.api.post('/consultations/${widget.consultationId}/messages', {'body': text});
      final msg = ChatMessage.fromJson(m);
      if (_messages.every((x) => x.id != msg.id)) setState(() => _messages.add(msg));
      _toBottom();
    } catch (e) {
      _input.text = text;
      if (mounted) showError(context, e);
    }
  }

  Future<void> _end() async {
    final notes = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('إنهاء الاستشارة'),
        content: TextField(
          controller: notes,
          maxLines: 3,
          decoration: const InputDecoration(hintText: 'ملخص النصيحة (يظهر في سجل الطفل)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('رجوع')),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إنهاء'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _state.api.post('/consultations/${widget.consultationId}/end', {'notes': notes.text.trim()});
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _rate(int stars) async {
    try {
      await _state.api.post('/consultations/${widget.consultationId}/rate', {'rating': stars});
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    return Scaffold(
      appBar: AppBar(
        title: Text(c == null
            ? 'الاستشارة'
            : _isVolunteer
                ? (c.parentName ?? 'ولي الأمر')
                : (c.volunteerName ?? 'بانتظار متطوع')),
        actions: [
          if (c?.videoLink != null && c!.status == 'active')
            IconButton(
              tooltip: 'مكالمة فيديو',
              icon: const Icon(Icons.videocam_outlined),
              onPressed: () => launchUrl(Uri.parse(c.videoLink!), mode: LaunchMode.externalApplication),
            ),
          if (_isVolunteer && c?.status == 'active')
            TextButton(onPressed: _end, child: const Text('إنهاء')),
        ],
      ),
      body: c == null
          ? const Center(child: CircularProgressIndicator())
          : Column(children: [
              _Header(consultation: c, child: _child, caseData: _case, isVolunteer: _isVolunteer),
              Expanded(
                child: ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  itemCount: _messages.length + (_otherTyping ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == _messages.length) return const _Typing();
                    final m = _messages[i];
                    return _Bubble(message: m, mine: m.senderId == _me);
                  },
                ),
              ),
              if (c.isOpen)
                _Composer(
                  controller: _input,
                  onSend: _send,
                  onTyping: () => _ws?.sink.add(jsonEncode({'type': 'typing'})),
                )
              else if (!_isVolunteer && c.status == 'completed')
                _RateBar(current: c.rating, onRate: _rate),
            ]),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.consultation, this.child, this.caseData, required this.isVolunteer});

  final Consultation consultation;
  final Map<String, dynamic>? child;
  final Map<String, dynamic>? caseData;
  final bool isVolunteer;

  @override
  Widget build(BuildContext context) {
    final status = consultation.status;
    final (label, color) = switch (status) {
      'pending' => ('نبحث لك عن متطوع متاح...', AppColors.amber),
      'active' => ('المتطوع معك الآن', AppColors.calm),
      'completed' => ('انتهت الاستشارة', AppColors.inkSoft),
      _ => ('أُلغيت', AppColors.inkSoft),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.line))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (status == 'pending')
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Container(width: 9, height: 9, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ]),
        if (isVolunteer && child != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 6, children: [
            _fact('${child!['name']}'),
            _fact('${child!['age_years']} سنة'),
            if (child!['weight_kg'] != null) _fact('${child!['weight_kg']} كجم'),
            if (child!['allergies'] != null) _fact('حساسية: ${child!['allergies']}'),
            if (caseData?['chemical'] != null) _fact('المادة: ${caseData!['chemical']['name_ar']}'),
            if (caseData?['symptoms'] != null) _fact('أعراض: ${caseData!['symptoms']}'),
          ]),
        ],
      ]),
    );
  }

  Widget _fact(String t) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: AppColors.mist, borderRadius: BorderRadius.circular(8)),
        child: Text(t, style: const TextStyle(fontSize: 13, color: AppColors.brandDeep)),
      );
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});
  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final time = intl.DateFormat.Hm().format(message.createdAt.toLocal());
    return Align(
      alignment: mine ? AlignmentDirectional.centerStart : AlignmentDirectional.centerEnd,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.76),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
        decoration: BoxDecoration(
          color: mine ? AppColors.ink : Colors.white,
          border: mine ? null : Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(message.body, style: TextStyle(color: mine ? Colors.white : AppColors.ink, height: 1.5)),
          const SizedBox(height: 2),
          Text(time, style: TextStyle(fontSize: 11, color: mine ? Colors.white54 : AppColors.inkSoft)),
        ]),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) => const Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: EdgeInsets.all(8),
          child: Text('يكتب...', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
        ),
      );
}

class _Composer extends StatelessWidget {
  const _Composer({required this.controller, required this.onSend, required this.onTyping});
  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback onTyping;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              onChanged: (_) => onTyping(),
              decoration: const InputDecoration(
                hintText: 'اكتب رسالتك...',
                filled: true,
                fillColor: AppColors.paper,
                border: OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(22))),
                enabledBorder:
                    OutlineInputBorder(borderSide: BorderSide.none, borderRadius: BorderRadius.all(Radius.circular(22))),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: AppColors.brand),
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded, textDirection: TextDirection.ltr),
          ),
        ]),
      ),
    );
  }
}

class _RateBar extends StatelessWidget {
  const _RateBar({this.current, required this.onRate});
  final int? current;
  final ValueChanged<int> onRate;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(current == null ? 'كيف كانت الاستشارة؟' : 'شكراً لتقييمك'),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var i = 1; i <= 5; i++)
              IconButton(
                onPressed: current == null ? () => onRate(i) : null,
                icon: Icon(
                  i <= (current ?? 0) ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: AppColors.amber,
                  size: 32,
                ),
              ),
          ]),
        ]),
      ),
    );
  }
}
