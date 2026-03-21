import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables.dart';

part 'events_dao.g.dart';

@DriftAccessor(tables: [Events])
class EventsDao extends DatabaseAccessor<AppDatabase> with _$EventsDaoMixin {
  EventsDao(super.db);

  Future<List<Event>> getAllEvents() => select(events).get();

  Future<Event?> getActiveEvent() =>
      (select(events)..where((e) => e.isActive.equals(true)))
          .getSingleOrNull();

  Future<void> upsertEvent(EventsCompanion entry) =>
      into(events).insertOnConflictUpdate(entry);

  Future<void> upsertEvents(List<EventsCompanion> entries) =>
      batch((b) => b.insertAllOnConflictUpdate(events, entries));

  Future<void> setActiveEvent(String eventId) async {
    await (update(events)).write(const EventsCompanion(isActive: Value(false)));
    await (update(events)..where((e) => e.id.equals(eventId)))
        .write(const EventsCompanion(isActive: Value(true)));
  }
}
