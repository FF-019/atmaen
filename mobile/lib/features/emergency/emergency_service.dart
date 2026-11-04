import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../../core/api_client.dart';
import '../../core/app_state.dart';
import '../../models/models.dart';

class EmergencyResult {
  final Guidance guidance;
  final int? caseId;
  EmergencyResult(this.guidance, this.caseId);
}

/// Decides where the guidance comes from:
///  logged in + child + online  -> open a real case on the server
///  online but no account       -> stateless /ai/analyze
///  offline                     -> local bundle, case queued for later
class EmergencyService {
  EmergencyService(this.state);
  final AppState state;

  ApiClient get api => state.api;

  Future<Position?> _position() async {
    try {
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      // don't hold the emergency screen for a perfect fix
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 6)),
      );
    } catch (_) {
      return Geolocator.getLastKnownPosition();
    }
  }

  Future<EmergencyResult> analyze({
    required String method, // text | barcode | image
    String? value,
    File? image,
    int? chemicalId,
    int? childId,
    List<String> symptoms = const [],
  }) async {
    final pos = await _position();

    if (state.online && state.loggedIn && childId != null && method != 'image') {
      final body = {
        'child_id': childId,
        'input_method': method,
        'input_value': value,
        'chemical_id': chemicalId,
        'symptoms': symptoms,
        'latitude': pos?.latitude,
        'longitude': pos?.longitude,
      };
      try {
        final res = await api.post('/cases', body);
        return EmergencyResult(Guidance.fromJson(res['guidance']), res['case']['id']);
      } on ApiException catch (e) {
        if (!e.isOffline) rethrow;
        await state.offline.queueCase(body);
        return EmergencyResult(_local(method, value, symptoms), null);
      }
    }

    if (state.online) {
      try {
        final Map<String, dynamic> res;
        if (method == 'image' && image != null) {
          res = await api.upload('/ai/analyze/image', image, fields: {
            if (childId != null) 'child_id': '$childId',
            'symptoms': jsonEncode(symptoms),
          });
        } else if (method == 'barcode') {
          res = await api.post('/ai/analyze/barcode', {'barcode': value, 'child_id': childId, 'symptoms': symptoms});
        } else {
          res = await api.post('/ai/analyze/text', {'text': value, 'child_id': childId, 'symptoms': symptoms});
        }
        return EmergencyResult(Guidance.fromJson(res), null);
      } on ApiException catch (e) {
        if (!e.isOffline) rethrow;
      }
    }

    return EmergencyResult(_local(method, value, symptoms), null);
  }

  Guidance _local(String method, String? value, List<String> symptoms) {
    final o = state.offline;
    Map<String, dynamic>? chem;
    if (method == 'barcode' && value != null) chem = o.findByBarcode(value);
    if (method == 'text' && value != null) chem = o.findChemical(value);
    return o.guidanceFor(chem, symptoms: symptoms);
  }

  Future<List<Chemical>> suggest(String q) async {
    if (q.trim().length < 2 || !state.online) return [];
    try {
      final rows = await api.get('/chemicals', query: {'q': q.trim(), 'limit': 6}) as List;
      return rows.map((j) => Chemical.fromJson(j)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> emergencyInfo(int caseId) async {
    try {
      return Map<String, dynamic>.from(await api.get('/cases/$caseId/emergency'));
    } catch (_) {
      return null;
    }
  }

  Future<List<Hospital>> nearestHospitals() async {
    final pos = await _position();
    if (pos == null || !state.online) return [];
    try {
      final rows = await api.get('/hospitals/nearest', query: {'lat': pos.latitude, 'lng': pos.longitude, 'limit': 3}) as List;
      return [
        for (final h in rows)
          Hospital(h['name_ar'], (h['distance_km'] as num).toDouble(), h['phone'],
              'https://maps.google.com/?q=${h['latitude']},${h['longitude']}'),
      ];
    } catch (_) {
      return [];
    }
  }
}
