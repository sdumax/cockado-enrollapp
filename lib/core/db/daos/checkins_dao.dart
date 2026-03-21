import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'checkins_dao.g.dart';

@DriftAccessor(tables: [Checkins])
class CheckinsDao extends DatabaseAccessor<AppDatabase>
    with _$CheckinsDaoMixin {
  CheckinsDao(super.db);

  Future<int> insertCheckin(CheckinsCompanion entry) =>
      into(checkins).insert(entry);

  Future<List<Checkin>> getPending() =>
      (select(checkins)
            ..where((c) => c.syncStatus.equals('PENDING')))
          .get();

  Future<void> markSynced(List<int> ids) =>
      (update(checkins)..where((c) => c.id.isIn(ids)))
          .write(const CheckinsCompanion(syncStatus: Value('SYNCED')));

  Future<bool> hasCheckinForEvent(String enrolleeId, String eventId) async {
    final result = await (select(checkins)
          ..where((c) =>
              c.enrolleeId.equals(enrolleeId) &
              c.eventId.equals(eventId)))
        .getSingleOrNull();
    return result != null;
  }
}
