import 'package:ferrematica_express/core/database/isar_module.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar_community/isar.dart';

import '../../helpers/test_isar.dart';

void main() {
  group('openIsar', () {
    late Isar isar;

    tearDown(() async {
      await closeTestIsar(isar);
    });

    test('opens successfully with registered feature collections', () async {
      isar = await openTestIsar();

      expect(isar.isOpen, isTrue);
      // OrderModelSchema + SyncCursorModelSchema + RouteCacheModelSchema
      // (PR7 — offline route cache) are currently the registered
      // collections — update this count as more feature schemas are added.
      expect(isarSchemas, hasLength(3));
    });
  });
}
