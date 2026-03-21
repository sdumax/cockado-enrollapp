import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Provided by ProviderScope override in main.dart after async DB open.
final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in ProviderScope');
});
