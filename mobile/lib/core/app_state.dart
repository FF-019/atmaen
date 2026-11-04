import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/models.dart';
import 'api_client.dart';
import 'offline_store.dart';

class AppState extends ChangeNotifier {
  AppState({ApiClient? api, OfflineStore? offline})
      : api = api ?? ApiClient(),
        offline = offline ?? OfflineStore();

  final ApiClient api;
  final OfflineStore offline;
  final _secure = const FlutterSecureStorage();
  StreamSubscription? _netSub;

  AppUser? user;
  List<ChildProfile> children = [];
  bool online = true;
  bool ready = false;

  bool get loggedIn => user != null;

  Future<void> boot() async {
    api.onUnauthorized = () => logout(silent: true);
    await offline.init();

    final results = await Connectivity().checkConnectivity();
    online = !results.contains(ConnectivityResult.none);
    _netSub = Connectivity().onConnectivityChanged.listen(_onNet);

    final saved = await _secure.read(key: 'token');
    if (saved != null) {
      api.token = saved;
      try {
        user = AppUser.fromJson(await api.get('/auth/me'));
        if (!user!.isVolunteer) await loadChildren();
      } on ApiException catch (e) {
        // offline at launch: keep the token, the user can still use the
        // offline guide. anything else means the token is bad.
        if (!e.isOffline) await _clearToken();
      }
    }
    if (online) unawaited(offline.refresh(api));
    ready = true;
    notifyListeners();
  }

  void _onNet(List<ConnectivityResult> r) {
    final now = !r.contains(ConnectivityResult.none);
    if (now == online) return;
    online = now;
    notifyListeners();
    if (online) {
      offline.refresh(api);
      if (loggedIn) offline.syncPending(api);
    }
  }

  // auth -----------------------------------------------------------------

  Future<void> _onAuth(Map<String, dynamic> res) async {
    api.token = res['access_token'];
    await _secure.write(key: 'token', value: api.token);
    user = AppUser.fromJson(res['user']);
    if (!user!.isVolunteer) await loadChildren();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    await _onAuth(await api.post('/auth/login', {'email': email.trim(), 'password': password}));
  }

  Future<void> register(Map<String, dynamic> data) async {
    await _onAuth(await api.post('/auth/register', data));
  }

  Future<void> logout({bool silent = false}) async {
    if (!silent) {
      try {
        await api.post('/auth/logout');
      } catch (_) {}
    }
    await _clearToken();
    user = null;
    children = [];
    notifyListeners();
  }

  Future<void> _clearToken() async {
    api.token = null;
    await _secure.delete(key: 'token');
  }

  Future<void> refreshMe() async {
    user = AppUser.fromJson(await api.get('/auth/me'));
    notifyListeners();
  }

  // children -------------------------------------------------------------

  Future<void> loadChildren() async {
    final rows = await api.get('/children') as List;
    children = rows.map((j) => ChildProfile.fromJson(j)).toList();
    notifyListeners();
  }

  Future<void> saveChild(ChildProfile draft, {int? id}) async {
    if (id == null) {
      await api.post('/children', draft.toJson());
    } else {
      await api.patch('/children/$id', draft.toJson());
    }
    await loadChildren();
  }

  Future<void> deleteChild(int id) async {
    await api.delete('/children/$id');
    await loadChildren();
  }

  @override
  void dispose() {
    _netSub?.cancel();
    super.dispose();
  }
}
