import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'enrollees_dao.g.dart';

@DriftAccessor(tables: [Enrollees])
class EnrolleesDao extends DatabaseAccessor<AppDatabase>
    with _$EnrolleesDaoMixin {
  EnrolleesDao(super.db);

  Future<List<Enrollee>> getAllForEvent(String eventId) =>
      select(enrollees).get();

  Future<Enrollee?> getById(String id) =>
      (select(enrollees)..where((e) => e.id.equals(id))).getSingleOrNull();

  Future<Enrollee?> getByTally(String tally) =>
      (select(enrollees)..where((e) => e.tallyNumber.equals(tally)))
          .getSingleOrNull();

  Future<void> upsertEnrollee(EnrolleesCompanion entry) =>
      into(enrollees).insertOnConflictUpdate(entry);

  Future<void> upsertEnrollees(List<EnrolleesCompanion> entries) =>
      batch((b) => b.insertAllOnConflictUpdate(enrollees, entries));

  /// Returns all enrollees that have a face embedding (for matching).
  Future<List<Enrollee>> getWithFaceEmbedding() =>
      (select(enrollees)
            ..where((e) => e.faceEmbedding.isNotNull()))
          .get();
}
