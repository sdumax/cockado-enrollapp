import 'package:drift/drift.dart';

// ── Events ────────────────────────────────────────────────────────────────────
class Events extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get date => dateTime()();
  BoolColumn get isActive => boolean().withDefault(const Constant(false))();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Enrollees ─────────────────────────────────────────────────────────────────
class Enrollees extends Table {
  TextColumn get id => text()();
  TextColumn get fullName => text()();
  TextColumn get email => text().nullable()();
  TextColumn get phone => text().nullable()();
  // 'M' | 'F'
  TextColumn get gender => text().nullable()();
  // 'SINGLE' | 'MARRIED' | 'DIVORCED' | 'WIDOWED'
  TextColumn get maritalStatus => text().nullable()();
  DateTimeColumn get dob => dateTime().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get city => text().nullable()();
  TextColumn get zone => text().nullable()();
  DateTimeColumn get baptismDate => dateTime().nullable()();
  TextColumn get tallyNumber => text().nullable()();
  // Encrypted 512-float face embedding stored as raw bytes
  BlobColumn get faceEmbedding => blob().nullable()();
  // Encrypted fingerprint template bytes
  BlobColumn get fingerprintTemplate => blob().nullable()();
  TextColumn get photoPath => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get syncedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ── Check-ins ─────────────────────────────────────────────────────────────────
class Checkins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get enrolleeId => text().references(Enrollees, #id)();
  TextColumn get eventId => text().references(Events, #id)();
  // 'TICKET' | 'FACE' | 'TOUCH'
  TextColumn get method => text()();
  TextColumn get deviceId => text()();
  DateTimeColumn get timestamp => dateTime()();
  // 'PENDING' | 'SYNCED' | 'CONFLICT'
  TextColumn get syncStatus =>
      text().withDefault(const Constant('PENDING'))();
}

// ── Sync meta ─────────────────────────────────────────────────────────────────
class SyncMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

// ── Sync queue ────────────────────────────────────────────────────────────────
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();
  // 'enrollee' | 'checkin'
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  // 'CREATE' | 'UPDATE'
  TextColumn get operation => text()();
  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
}
