import 'package:isar_community/isar.dart';

part 'sync_cursor.g.dart';

/// Singleton row storing the last successful pull timestamp for the orders
/// sync service. `isarId` is a fixed constant — exactly one row ever
/// exists. Chosen over `SharedPreferences` for a single `DateTime` so the
/// pull cursor lives alongside the rest of the sync state without adding a
/// new dependency (see design's open question, resolved: Isar).
@collection
class SyncCursorModel {
  Id get isarId => 1;

  DateTime? lastPulledAt;
}
