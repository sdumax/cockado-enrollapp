import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cockado_enrollapp/core/db/app_database.dart';
import 'package:cockado_enrollapp/core/db/database_provider.dart';
import 'sync_status_repository.dart';

const _apiBase = 'https://api.coccheckin.app/v1';
const _enrolleeBatchSize = 100;

// ── SyncProgress ──────────────────────────────────────────────────────────────

class SyncProgress {
  const SyncProgress({
    required this.current,
    required this.total,
    this.isDone = false,
    this.error,
  });

  final int current;
  final int total;
  final bool isDone;
  final String? error;
}

// ── SyncService ───────────────────────────────────────────────────────────────

class SyncService {
  SyncService(this._dio, this._db, this._syncRepo);

  final Dio _dio;
  final AppDatabase _db;
  final SyncStatusRepository _syncRepo;

  /// Check if a sync is needed by comparing server hash to local hash.
  /// Returns true if sync required, false if up to date.
  Future<bool> isSyncRequired(String eventId) async {
    final response = await _dio.get<Map<String, dynamic>>(
      '/sync/status',
      queryParameters: {'eventId': eventId},
    );
    final serverHash = response.data?['hash'] as String?;
    if (serverHash == null) return true;

    final localHash = await _syncRepo.getLocalHash();
    return localHash == null || localHash != serverHash;
  }

  /// Full pull: download all enrollees for the event, upsert to local DB.
  /// Yields progress as [SyncProgress] via a Stream.
  Stream<SyncProgress> pullEnrollees(String eventId) async* {
    try {
      final enrolleesResponse = await _dio.get<Map<String, dynamic>>(
        '/enrollees',
        queryParameters: {'eventId': eventId},
      );

      final rawData = enrolleesResponse.data?['data'];
      if (rawData == null || rawData is! List) {
        yield const SyncProgress(
          current: 0,
          total: 0,
          error: 'Invalid response: missing or malformed "data" field.',
        );
        return;
      }

      final data = rawData.cast<Map<String, dynamic>>();
      final total = data.length;

      yield SyncProgress(current: 0, total: total);

      var processed = 0;
      while (processed < total) {
        final end = (processed + _enrolleeBatchSize).clamp(0, total);
        final batch = data.sublist(processed, end);

        final companions = batch.map(_enrolleeFromJson).toList();
        await _db.enrolleesDao.upsertEnrollees(companions);

        processed = end;
        yield SyncProgress(current: processed, total: total);
      }

      // Persist sync metadata
      await _syncRepo.setLastSyncedAt(DateTime.now().toIso8601String());

      // Re-fetch the server hash to record the post-sync state
      final statusResponse = await _dio.get<Map<String, dynamic>>(
        '/sync/status',
        queryParameters: {'eventId': eventId},
      );
      final serverHash = statusResponse.data?['hash'] as String?;
      if (serverHash != null) {
        await _syncRepo.setLocalHash(serverHash);
      }

      yield SyncProgress(current: total, total: total, isDone: true);
    } on DioException catch (e) {
      yield SyncProgress(
        current: 0,
        total: 0,
        error: e.message ?? e.toString(),
      );
    } catch (e) {
      yield SyncProgress(current: 0, total: 0, error: e.toString());
    }
  }

  /// Incremental pull: download only records updated since lastSyncedAt.
  Future<void> incrementalPull(String eventId) async {
    final lastSyncedAt = await _syncRepo.getLastSyncedAt();

    final queryParams = <String, dynamic>{'eventId': eventId};
    if (lastSyncedAt != null) {
      queryParams['updatedSince'] = lastSyncedAt;
    }

    final response = await _dio.get<Map<String, dynamic>>(
      '/enrollees',
      queryParameters: queryParams,
    );

    final rawData = response.data?['data'];
    if (rawData == null || rawData is! List) return;

    final companions = rawData
        .cast<Map<String, dynamic>>()
        .map(_enrolleeFromJson)
        .toList();

    if (companions.isNotEmpty) {
      await _db.enrolleesDao.upsertEnrollees(companions);
    }

    await _syncRepo.setLastSyncedAt(DateTime.now().toIso8601String());
  }

  /// Pull and store the available events list.
  Future<void> syncEvents() async {
    final response = await _dio.get<Map<String, dynamic>>('/events');

    final rawData = response.data?['data'];
    if (rawData == null || rawData is! List) return;

    final companions = rawData
        .cast<Map<String, dynamic>>()
        .map(_eventFromJson)
        .toList();

    if (companions.isNotEmpty) {
      await _db.eventsDao.upsertEvents(companions);
    }
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  EnrolleesCompanion _enrolleeFromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null || value is! String || value.isEmpty) return null;
      return DateTime.tryParse(value);
    }

    return EnrolleesCompanion(
      id: Value(json['id'] as String),
      fullName: Value(json['fullName'] as String),
      email: Value(json['email'] as String?),
      phone: Value(json['phone'] as String?),
      gender: Value(json['gender'] as String?),
      maritalStatus: Value(json['maritalStatus'] as String?),
      dob: Value(parseDate(json['dob'])),
      address: Value(json['address'] as String?),
      city: Value(json['city'] as String?),
      zone: Value(json['zone'] as String?),
      baptismDate: Value(parseDate(json['baptismDate'])),
      tallyNumber: Value(json['tallyNumber'] as String?),
      createdAt: Value(DateTime.parse(json['createdAt'] as String)),
      updatedAt: Value(DateTime.parse(json['updatedAt'] as String)),
    );
  }

  EventsCompanion _eventFromJson(Map<String, dynamic> json) {
    return EventsCompanion(
      id: Value(json['id'] as String),
      name: Value(json['name'] as String),
      date: Value(DateTime.parse(json['date'] as String)),
      isActive: json.containsKey('isActive')
          ? Value(json['isActive'] as bool)
          : const Value.absent(),
    );
  }
}

// ── Riverpod providers ────────────────────────────────────────────────────────

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: _apiBase,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Auth interceptor placeholder — reads token from secure storage.
  // Full JWT wiring in Phase 8; for now just adds an empty header.
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        options.headers['Authorization'] = 'Bearer ';
        handler.next(options);
      },
    ),
  );

  return dio;
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    ref.watch(dioProvider),
    ref.watch(databaseProvider),
    ref.watch(syncStatusRepositoryProvider),
  );
});
