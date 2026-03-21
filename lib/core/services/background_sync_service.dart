import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:workmanager/workmanager.dart';
import 'package:cockado_enrollapp/core/db/app_database.dart';
import 'package:cockado_enrollapp/features/init/sync_status_repository.dart';

const _apiBase = 'https://api.coccheckin.app/v1';
const _jwtStorageKey = 'coc_jwt_token';

const _taskPullEnrollees = 'coc.pullEnrollees';
const _taskPushCheckins = 'coc.pushCheckins';

// ── Workmanager callback dispatcher ──────────────────────────────────────────

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      switch (taskName) {
        case _taskPullEnrollees:
          await _runIncrementalPull();
          return true;
        case _taskPushCheckins:
          await _runPushCheckins();
          return true;
        default:
          return false;
      }
    } catch (_) {
      return false;
    }
  });
}

// ── Background task implementations ──────────────────────────────────────────

Future<void> _runIncrementalPull() async {
  final db = await openAppDatabase();
  try {
    final syncRepo = SyncStatusRepository(db.syncDao);

    final eventId = await syncRepo.getActiveEventId();
    if (eventId == null || eventId.isEmpty) return;

    final lastSyncedAt = await syncRepo.getLastSyncedAt();

    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: _jwtStorageKey);

    final dio = Dio(BaseOptions(baseUrl: _apiBase));
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    final queryParams = <String, dynamic>{'eventId': eventId};
    if (lastSyncedAt != null && lastSyncedAt.isNotEmpty) {
      queryParams['updatedSince'] = lastSyncedAt;
    }

    final response = await dio.get<List<dynamic>>(
      '/enrollees',
      queryParameters: queryParams,
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      final data = response.data;
      if (data != null && data.isNotEmpty) {
        final companions = data
            .whereType<Map<String, dynamic>>()
            .map((json) => _enrolleeJsonToCompanion(json))
            .where((c) => c != null)
            .cast<EnrolleesCompanion>()
            .toList();

        if (companions.isNotEmpty) {
          await db.enrolleesDao.upsertEnrollees(companions);
        }
      }

      await syncRepo.setLastSyncedAt(DateTime.now().toUtc().toIso8601String());
    }
  } finally {
    await db.close();
  }
}

Future<void> _runPushCheckins() async {
  final db = await openAppDatabase();
  try {
    final pending = await db.checkinsDao.getPending();
    if (pending.isEmpty) return;

    final storage = const FlutterSecureStorage();
    final token = await storage.read(key: _jwtStorageKey);

    final dio = Dio(BaseOptions(baseUrl: _apiBase));
    if (token != null && token.isNotEmpty) {
      dio.options.headers['Authorization'] = 'Bearer $token';
    }

    final payload = pending
        .map((c) => {
              'id': c.id,
              'enrolleeId': c.enrolleeId,
              'eventId': c.eventId,
              'method': c.method,
              'deviceId': c.deviceId,
              'timestamp': c.timestamp.toUtc().toIso8601String(),
              'syncStatus': c.syncStatus,
            })
        .toList();

    final response = await dio.post<dynamic>(
      '/checkins/batch',
      data: payload,
    );

    final statusCode = response.statusCode ?? 0;
    if (statusCode >= 200 && statusCode < 300) {
      final ids = pending.map((c) => c.id).toList();
      await db.checkinsDao.markSynced(ids);
    }
    // On non-2xx: leave as PENDING, will retry next cycle.
  } catch (_) {
    // Leave records as PENDING; workmanager will retry on the next cycle.
  } finally {
    await db.close();
  }
}

// ── JSON helper ───────────────────────────────────────────────────────────────

EnrolleesCompanion? _enrolleeJsonToCompanion(Map<String, dynamic> json) {
  try {
    final id = json['id'] as String?;
    final fullName = json['fullName'] as String?;
    if (id == null || fullName == null) return null;

    DateTime parseDate(dynamic raw) {
      if (raw == null) return DateTime.now().toUtc();
      return DateTime.tryParse(raw.toString())?.toUtc() ?? DateTime.now().toUtc();
    }

    return EnrolleesCompanion.insert(
      id: id,
      fullName: fullName,
      email: Value(json['email'] as String?),
      phone: Value(json['phone'] as String?),
      gender: Value(json['gender'] as String?),
      maritalStatus: Value(json['maritalStatus'] as String?),
      dob: Value(
        json['dob'] != null ? DateTime.tryParse(json['dob'].toString())?.toUtc() : null,
      ),
      address: Value(json['address'] as String?),
      city: Value(json['city'] as String?),
      zone: Value(json['zone'] as String?),
      baptismDate: Value(
        json['baptismDate'] != null
            ? DateTime.tryParse(json['baptismDate'].toString())?.toUtc()
            : null,
      ),
      tallyNumber: Value(json['tallyNumber'] as String?),
      faceEmbedding: const Value(null),
      fingerprintTemplate: const Value(null),
      photoPath: Value(json['photoPath'] as String?),
      createdAt: parseDate(json['createdAt']),
      updatedAt: parseDate(json['updatedAt']),
      syncedAt: Value(DateTime.now().toUtc()),
    );
  } catch (_) {
    return null;
  }
}

// ── BackgroundSyncService ─────────────────────────────────────────────────────

class BackgroundSyncService {
  static Future<void> initialize() async {
    await Workmanager().initialize(callbackDispatcher, isInDebugMode: false);
  }

  static Future<void> registerTasks() async {
    // Incremental pull every 15 minutes
    await Workmanager().registerPeriodicTask(
      _taskPullEnrollees,
      _taskPullEnrollees,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );

    // Push PENDING checkins every 5 minutes
    await Workmanager().registerPeriodicTask(
      _taskPushCheckins,
      _taskPushCheckins,
      frequency: const Duration(minutes: 5),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  static Future<void> cancelAll() async {
    await Workmanager().cancelAll();
  }
}

final backgroundSyncServiceProvider = Provider<BackgroundSyncService>((ref) {
  return BackgroundSyncService();
});
