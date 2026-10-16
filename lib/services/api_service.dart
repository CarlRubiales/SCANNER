import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/scan_result.dart';

class ApiService {
  static const String keyServerUrl = 'scanner_server_url';
  static const String keyOperatorName = 'scanner_operator_name';
  static const String keyContinuousMode = 'scanner_continuous_mode';
  static const String keyOfflineQueue = 'scanner_offline_queue';
  static const String keyLocalHistory = 'scanner_local_history';

  // Smart candidate URLs: probes in order without exposing URLs to the user/professor
  static const String currentHostIpPort80 = 'http://192.168.86.23';
  static const String currentHostIpPort8000 = 'http://192.168.86.23:8000';
  static const String currentHostIp = currentHostIpPort80;
  static const String emulatorHostIp = 'http://10.0.2.2:8000';
  static const String localhostIp = 'http://127.0.0.1:8000';

  static String? _cachedWorkingUrl;

  static List<String> get candidateUrls {
    if (kIsWeb) return [localhostIp];
    try {
      if (Platform.isAndroid) {
        // Port 80 passes straight through Windows Firewall via Apache reverse proxy!
        // Port 8000 connects directly to artisan serve
        return [currentHostIpPort80, currentHostIpPort8000, emulatorHostIp, localhostIp];
      }
    } catch (_) {}
    return [currentHostIpPort80, currentHostIpPort8000, localhostIp, emulatorHostIp];
  }

  static Future<List<String>> getCandidateUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(keyServerUrl);
    final list = <String>[];
    if (custom != null && custom.trim().isNotEmpty) {
      final cleaned = custom.trim().replaceAll(RegExp(r'/+$'), '');
      list.add(cleaned);
    }
    if (_cachedWorkingUrl != null && !list.contains(_cachedWorkingUrl!)) {
      list.add(_cachedWorkingUrl!);
    }
    for (final candidate in candidateUrls) {
      if (!list.contains(candidate)) {
        list.add(candidate);
      }
    }
    return list;
  }

  static Future<String> getBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final custom = prefs.getString(keyServerUrl);
    if (custom != null && custom.trim().isNotEmpty) {
      return custom.trim().replaceAll(RegExp(r'/+$'), '');
    }
    if (_cachedWorkingUrl != null) {
      return _cachedWorkingUrl!;
    }
    return currentHostIp;
  }

  static Future<void> setBaseUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final cleaned = url.trim().replaceAll(RegExp(r'/+$'), '');
    await prefs.setString(keyServerUrl, cleaned);
    _cachedWorkingUrl = cleaned;
  }

  static Future<String> getOperatorName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyOperatorName) ?? 'Intake Scanner Unit #1';
  }

  static Future<void> setOperatorName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(keyOperatorName, name.trim());
  }

  static Future<bool> getContinuousMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyContinuousMode) ?? true;
  }

  static Future<void> setContinuousMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyContinuousMode, value);
  }

  /// Check connectivity against the best reachable backend URL
  static Future<bool> testConnection({String? customUrl}) async {
    if (customUrl != null && customUrl.trim().isNotEmpty) {
      try {
        final uri = Uri.parse('${customUrl.trim().replaceAll(RegExp(r'/+$'), '')}/api/v1/scanner/status');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 1800));
        if (res.statusCode == 200) {
          _cachedWorkingUrl = customUrl.trim().replaceAll(RegExp(r'/+$'), '');
          return true;
        }
      } catch (_) {}
      return false;
    }

    final candidates = await getCandidateUrls();
    for (final candidate in candidates) {
      try {
        final uri = Uri.parse('$candidate/api/v1/scanner/status');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          _cachedWorkingUrl = candidate;
          return true;
        }
      } catch (_) {}
    }
    return false;
  }

  /// Get pending offline scans count
  static Future<int> getPendingOfflineCount() async {
    final queue = await getOfflineQueue();
    return queue.length;
  }

  /// Retrieve offline scan queue from device storage
  static Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyOfflineQueue);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save barcode scan to offline queue
  static Future<void> saveToOfflineQueue(String barcode) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getOfflineQueue();
    final now = DateTime.now();

    final exists = queue.any((item) => item['barcode'] == barcode);
    if (!exists) {
      queue.add({
        'barcode': barcode,
        'scanned_at': now.toIso8601String(),
        'display_time': _formatTime(now),
      });
      await prefs.setString(keyOfflineQueue, jsonEncode(queue));
    }

    await saveToLocalHistory(barcode, isSynced: false);
  }

  /// Clear the offline queue after successful sync
  static Future<void> clearOfflineQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyOfflineQueue);
  }

  /// Retrieve local scans history
  static Future<List<Map<String, dynamic>>> getLocalHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(keyLocalHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Save scan to device local history
  static Future<void> saveToLocalHistory(
    String barcode, {
    required bool isSynced,
    ScannedParcel? parcel,
    bool isAlreadyScanned = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getLocalHistory();
    final now = DateTime.now();

    final item = {
      'barcode': barcode,
      'parcel_number': parcel?.parcelNumber ?? _generateParcelNumber(barcode),
      'recipient': parcel?.recipientName ?? 'Package Intake',
      'city': parcel?.city ?? 'Santa Cruz',
      'province': parcel?.province ?? 'Laguna',
      'status': parcel?.status ?? 'scanned',
      'status_label': parcel?.statusLabel ?? 'Scanned',
      'area_name': parcel?.areaName.isNotEmpty == true ? parcel!.areaName : 'Laguna - Santa Cruz',
      'sort_bin': parcel?.sortBin ?? 'Pending Sorting',
      'assigned_rider': parcel?.assignedRider ?? 'Unassigned',
      'scanned_at': _formatTime(now),
      'is_synced': isSynced,
      'is_already_scanned': isAlreadyScanned,
      'timestamp': now.millisecondsSinceEpoch,
    };

    // Remove older duplicate if exists in history, then insert newest at top
    history.removeWhere((h) =>
        (h['barcode'] as String?).toString().trim().toUpperCase() ==
        barcode.trim().toUpperCase());
    history.insert(0, item);
    if (history.length > 50) {
      history.removeRange(50, history.length);
    }

    await prefs.setString(keyLocalHistory, jsonEncode(history));
  }

  /// Mark local history items as synced
  static Future<void> markLocalHistorySynced() async {
    final prefs = await SharedPreferences.getInstance();
    final history = await getLocalHistory();
    for (var item in history) {
      item['is_synced'] = true;
    }
    await prefs.setString(keyLocalHistory, jsonEncode(history));
  }

  /// Process barcode scan directly to the logistics server!
  static Future<ScanResponse> processBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      return ScanResponse.failure('Empty barcode value detected.');
    }

    final operatorName = await getOperatorName();
    final candidates = await getCandidateUrls();

    for (final baseUrl in candidates) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/scanner/scan');
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'barcode': trimmed,
            'operator': operatorName,
            'device': 'Mobile Optical Scanner',
          }),
        ).timeout(const Duration(milliseconds: 2500));

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final scanResponse = ScanResponse.fromJson(data);

          // Cache working host for rapid subsequent scans
          if (!baseUrl.contains('127.0.0.1')) {
            _cachedWorkingUrl = baseUrl;
          }

          if (scanResponse.parcel != null) {
            await saveToLocalHistory(
              trimmed,
              isSynced: true,
              parcel: scanResponse.parcel,
              isAlreadyScanned: scanResponse.isAlreadyScanned,
            );
          }

          return scanResponse;
        }
      } catch (_) {}
    }

    // Direct mode: report immediate connection status without hidden queue
    return ScanResponse.failure(
      'Cannot connect to laptop (192.168.86.23). Ensure phone & laptop are on the same Wi-Fi!',
    );
  }

  /// Sync all pending offline scans to the Laravel backend
  static Future<int> syncOfflineScans() async {
    final queue = await getOfflineQueue();
    if (queue.isEmpty) return 0;

    final candidates = await getCandidateUrls();
    for (final baseUrl in candidates) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/scanner/batch-sync');
        final operatorName = await getOperatorName();

        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
          body: jsonEncode({
            'scans': queue,
            'operator': operatorName,
          }),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          final syncedCount = data['synced_count'] as int? ?? queue.length;
          _cachedWorkingUrl = baseUrl;
          await clearOfflineQueue();
          await markLocalHistorySynced();
          return syncedCount;
        }
      } catch (_) {}
    }
    return 0;
  }

  /// Fetch stats with local fallback
  static Future<ScannerStats> fetchStats() async {
    final candidates = await getCandidateUrls();
    for (final baseUrl in candidates) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/scanner/status');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 1400));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          _cachedWorkingUrl = baseUrl;
          return ScannerStats.fromJson(data);
        }
      } catch (_) {}
    }

    final history = await getLocalHistory();
    return ScannerStats(
      received: 0,
      scanned: history.length,
      sorted: 0,
      assigned: 0,
      inTransit: 0,
      delivered: 0,
      scansToday: history.length,
      online: false,
    );
  }

  /// Fetch combined recent scans (combines server + local device scans)
  static Future<List<Map<String, dynamic>>> fetchRecentScans() async {
    final localList = await getLocalHistory();
    final candidates = await getCandidateUrls();

    for (final baseUrl in candidates) {
      try {
        final uri = Uri.parse('$baseUrl/api/v1/scanner/recent');
        final res = await http.get(uri).timeout(const Duration(milliseconds: 1500));
        if (res.statusCode == 200) {
          final data = jsonDecode(res.body) as Map<String, dynamic>;
          final serverList = (data['data'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();

          final unsynced = localList.where((l) => l['is_synced'] == false).toList();
          return [...unsynced, ...serverList];
        }
      } catch (_) {}
    }

    return localList;
  }

  static String _generateParcelNumber(String barcode) {
    if (barcode.toUpperCase().startsWith('LM-')) return barcode.toUpperCase();
    final clean = barcode.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
    final suffix = clean.length > 6 ? clean.substring(clean.length - 6) : clean.padLeft(6, '0');
    return 'LM-TRK-$suffix';
  }

  static String _formatTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final min = dt.minute.toString().padLeft(2, '0');
    final sec = dt.second.toString().padLeft(2, '0');
    return '$hour:$min:$sec $period';
  }
}
