import 'dart:io';

import 'package:ferrematica_express/core/database/isar_module.dart';
import 'package:isar_community/isar.dart';

bool _coreInitialized = false;

/// Downloads/loads the native Isar core binary once per test process. Isar
/// unit tests (outside a running Flutter app) don't get the binary for
/// free — see https://github.com/isar-community/isar#unit-tests. Run
/// `flutter test -j 1` when using this helper: parallel test isolates can
/// race the download.
Future<void> _ensureIsarCoreInitialized() async {
  if (_coreInitialized) return;
  await Isar.initializeIsarCore(download: true);
  _coreInitialized = true;
}

/// Opens a throwaway [Isar] instance backed by [isarSchemas] in a fresh
/// temp directory. Callers MUST call [closeTestIsar] in a `tearDown` to
/// close the instance and delete the temp directory.
Future<Isar> openTestIsar() async {
  await _ensureIsarCoreInitialized();
  final tempDir = await Directory.systemTemp.createTemp('ferrematica_isar_test_');
  return openIsar(directory: tempDir.path);
}

/// Closes [isar] and deletes its backing temp directory.
Future<void> closeTestIsar(Isar isar) async {
  final directoryPath = isar.directory;
  await isar.close(deleteFromDisk: true);
  if (directoryPath != null) {
    final directory = Directory(directoryPath);
    if (directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}
