import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:sqlcipher_flutter_libs/sqlcipher_flutter_libs.dart';

import 'tables.dart';
import 'daos/events_dao.dart';
import 'daos/enrollees_dao.dart';
import 'daos/checkins_dao.dart';
import 'daos/sync_dao.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [Events, Enrollees, Checkins, SyncMeta, SyncQueue],
  daos: [EventsDao, EnrolleesDao, CheckinsDao, SyncDao],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
      );
}

// ── Database opener ───────────────────────────────────────────────────────────

const _keyStorageKey = 'coc_db_encryption_key';

Future<AppDatabase> openAppDatabase() async {
  await applyWorkaroundToOpenSqlCipherOnOldAndroidVersions();

  final storage = const FlutterSecureStorage();
  String? key = await storage.read(key: _keyStorageKey);
  if (key == null) {
    // Generate a random 32-byte hex key on first run
    final bytes = List<int>.generate(
      32,
      (_) => DateTime.now().microsecondsSinceEpoch & 0xFF,
    );
    key = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    await storage.write(key: _keyStorageKey, value: key);
  }

  final dbFolder = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dbFolder.path, 'coc_checkin.db'));

  return AppDatabase(
    NativeDatabase.createInBackground(
      dbFile,
      setup: (db) {
        db.execute("PRAGMA key = '$key'");
        db.execute("PRAGMA cipher_compatibility = 4");
      },
    ),
  );
}
