import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncMeta, SyncQueue])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  // ── SyncMeta ──────────────────────────────────────────────────────────────

  Future<String?> getMeta(String key) async {
    final row = await (select(syncMeta)..where((m) => m.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setMeta(String key, String value) =>
      into(syncMeta).insertOnConflictUpdate(
        SyncMetaCompanion(key: Value(key), value: Value(value)),
      );

  // ── SyncQueue ─────────────────────────────────────────────────────────────

  Future<int> enqueue(SyncQueueCompanion entry) =>
      into(syncQueue).insert(entry);

  Future<List<SyncQueueData>> getPendingQueue({int limit = 50}) =>
      (select(syncQueue)
            ..orderBy([(q) => OrderingTerm.asc(q.createdAt)])
            ..limit(limit))
          .get();

  Future<void> deleteQueueEntry(int id) =>
      (delete(syncQueue)..where((q) => q.id.equals(id))).go();

  Future<void> incrementAttempts(int id) async {
    await customUpdate(
      'UPDATE sync_queue SET attempts = attempts + 1 WHERE id = ?',
      variables: [Variable.withInt(id)],
      updates: {syncQueue},
    );
  }
}
