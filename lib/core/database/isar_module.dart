import 'package:isar_community/isar.dart';

import '../../features/orders/data/order_model.dart';
import '../../features/orders/data/sync_cursor.dart';

/// Isar collection schemas registered by this app. Features append their
/// own schema here as they're implemented.
const List<CollectionSchema<dynamic>> isarSchemas = <CollectionSchema<dynamic>>[
  OrderModelSchema,
  SyncCursorModelSchema,
];

/// Opens the app's single Isar instance backed by [isarSchemas] at
/// [directory]. Callers (bootstrap, tests) are responsible for catching and
/// surfacing failures — this function does not swallow errors.
Future<Isar> openIsar({required String directory}) {
  return Isar.open(isarSchemas, directory: directory);
}
