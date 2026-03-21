import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cockado_enrollapp/core/db/database_provider.dart';
import 'package:cockado_enrollapp/core/db/daos/sync_dao.dart';

const _keyLastSyncedAt = 'lastSyncedAt';
const _keyLocalHash = 'localDataHash';
const _keyActiveEventId = 'activeEventId';

class SyncStatusRepository {
  SyncStatusRepository(this._dao);

  final SyncDao _dao;

  Future<String?> getLastSyncedAt() => _dao.getMeta(_keyLastSyncedAt);
  Future<void> setLastSyncedAt(String iso8601) =>
      _dao.setMeta(_keyLastSyncedAt, iso8601);

  Future<String?> getLocalHash() => _dao.getMeta(_keyLocalHash);
  Future<void> setLocalHash(String hash) => _dao.setMeta(_keyLocalHash, hash);

  Future<String?> getActiveEventId() => _dao.getMeta(_keyActiveEventId);
  Future<void> setActiveEventId(String id) =>
      _dao.setMeta(_keyActiveEventId, id);
}

final syncStatusRepositoryProvider = Provider<SyncStatusRepository>((ref) {
  final db = ref.watch(databaseProvider);
  return SyncStatusRepository(db.syncDao);
});
