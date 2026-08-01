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

    test('opens successfully with no real feature collections registered', () async {
      isar = await openTestIsar();

      expect(isar.isOpen, isTrue);
      // Only the bootstrap placeholder is registered — no real feature
      // collection exists yet (see isar_module.dart doc comment).
      expect(isarSchemas, hasLength(1));
    });
  });
}
