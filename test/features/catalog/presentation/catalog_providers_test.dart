import 'package:ferrematica_express/features/catalog/data/providers.dart';
import 'package:ferrematica_express/features/catalog/domain/product.dart'
    show kDefaultCategoryLabel;
import 'package:ferrematica_express/features/catalog/presentation/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_catalog_remote.dart';

void main() {
  group('buildCategoryOptions / categoryOptionsProvider', () {
    test(
      'case/whitespace variants collapse into one option, first-seen label wins',
      () async {
        final remote = FakeCatalogRemote(
          seed: [
            buildTestProduct(id: 'p1', category: 'Tornillería '),
            buildTestProduct(id: 'p2', category: 'tornillería'),
            buildTestProduct(id: 'p3', category: 'TORNILLERÍA'),
          ],
        );
        final container = ProviderContainer(
          overrides: [catalogRemoteProvider.overrideWithValue(remote)],
        );
        addTearDown(container.dispose);

        await container.read(catalogProvider.future);
        final options = container.read(categoryOptionsProvider);

        expect(options, hasLength(1));
        expect(options.single.label, 'Tornillería ');
      },
    );

    test(
      'General-bucket variants (already normalized upstream) group as one',
      () async {
        // The data layer (SupabaseCatalogRemote._categoryLabelFromRow) is what
        // maps null/blank category rows to `kDefaultCategoryLabel` before a
        // [Product] is ever constructed — see supabase_catalog_remote_test.dart.
        // Here we only verify that two products already carrying that
        // fallback label group under a single chip, same as any other
        // case/whitespace variant.
        final remote = FakeCatalogRemote(
          seed: [
            buildTestProduct(id: 'p1', category: kDefaultCategoryLabel),
            buildTestProduct(
              id: 'p2',
              category: kDefaultCategoryLabel.toUpperCase(),
            ),
          ],
        );
        final container = ProviderContainer(
          overrides: [catalogRemoteProvider.overrideWithValue(remote)],
        );
        addTearDown(container.dispose);

        await container.read(catalogProvider.future);
        final options = container.read(categoryOptionsProvider);

        expect(options, hasLength(1));
        expect(options.single.label, kDefaultCategoryLabel);
      },
    );

    test(
      'chips render alphabetically by label regardless of fetch order',
      () async {
        final remote = FakeCatalogRemote(
          seed: [
            buildTestProduct(id: 'p1', category: 'Zapatos'),
            buildTestProduct(id: 'p2', category: 'Accesorios'),
            buildTestProduct(id: 'p3', category: 'Medias'),
          ],
        );
        final container = ProviderContainer(
          overrides: [catalogRemoteProvider.overrideWithValue(remote)],
        );
        addTearDown(container.dispose);

        await container.read(catalogProvider.future);
        final options = container.read(categoryOptionsProvider);

        expect(options.map((o) => o.label), [
          'Accesorios',
          'Medias',
          'Zapatos',
        ]);
      },
    );
  });

  group('visibleProductsProvider', () {
    test('chip filtering narrows the list', () async {
      final remote = FakeCatalogRemote(
        seed: [
          buildTestProduct(id: 'p1', category: 'Tornillos'),
          buildTestProduct(id: 'p2', category: 'Clavos'),
        ],
      );
      final container = ProviderContainer(
        overrides: [catalogRemoteProvider.overrideWithValue(remote)],
      );
      addTearDown(container.dispose);

      await container.read(catalogProvider.future);
      container.read(selectedCategoryKeyProvider.notifier).state = 'tornillos';

      final visible = container.read(visibleProductsProvider);
      expect(visible.value!.map((p) => p.id), ['p1']);
    });

    test(
      'stale selection falls back to Todos when the category vanishes on refresh',
      () async {
        final remote = FakeCatalogRemote(
          seed: [
            buildTestProduct(id: 'p1', category: 'Tornillos'),
            buildTestProduct(id: 'p2', category: 'Clavos'),
          ],
        );
        final container = ProviderContainer(
          overrides: [catalogRemoteProvider.overrideWithValue(remote)],
        );
        addTearDown(container.dispose);

        await container.read(catalogProvider.future);
        container.read(selectedCategoryKeyProvider.notifier).state =
            'tornillos';
        expect(container.read(visibleProductsProvider).value!, hasLength(1));

        // Simulate a refresh whose new result no longer has 'tornillos'.
        final remote2 = FakeCatalogRemote(
          seed: [buildTestProduct(id: 'p2', category: 'Clavos')],
        );
        final container2 = ProviderContainer(
          overrides: [catalogRemoteProvider.overrideWithValue(remote2)],
        );
        addTearDown(container2.dispose);
        await container2.read(catalogProvider.future);
        container2.read(selectedCategoryKeyProvider.notifier).state =
            'tornillos';

        final visible = container2.read(visibleProductsProvider);
        expect(visible.value!.map((p) => p.id), ['p2']);
        expect(container2.read(effectiveSelectedCategoryKeyProvider), isNull);
      },
    );
  });
}
