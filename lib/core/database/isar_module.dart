import 'package:isar_community/isar.dart';

part 'isar_module.g.dart';

/// Bootstrap-only placeholder collection. `isar_community` requires at
/// least one collection to open an instance — this placeholder exists
/// purely to satisfy that constraint until the first real feature adds its
/// own `@collection`. It is never queried by app code and should be removed
/// once a real collection exists.
@collection
class BootstrapPlaceholder {
  Id id = Isar.autoIncrement;
}

/// Isar collection schemas registered by this app. Currently only
/// [BootstrapPlaceholderSchema] (see above) — features append their own
/// schema here as they're implemented.
const List<CollectionSchema<dynamic>> isarSchemas = <CollectionSchema<dynamic>>[
  BootstrapPlaceholderSchema,
];

/// Opens the app's single Isar instance backed by [isarSchemas] at
/// [directory]. Callers (bootstrap, tests) are responsible for catching and
/// surfacing failures — this function does not swallow errors.
Future<Isar> openIsar({required String directory}) {
  return Isar.open(isarSchemas, directory: directory);
}
