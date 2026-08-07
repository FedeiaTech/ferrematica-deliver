import 'package:ferrematica_express/features/catalog/data/providers.dart';
import 'package:ferrematica_express/features/catalog/presentation/providers.dart';
import 'package:ferrematica_express/features/catalog/presentation/screens/catalog_screen.dart';
import 'package:ferrematica_express/features/catalog/presentation/widgets/product_card.dart';
import 'package:ferrematica_express/features/catalog/presentation/widgets/product_thumbnail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/pump_app.dart';
import 'fake_catalog_remote.dart';

void main() {
  testWidgets('shows a loading indicator, then the product grid', (
    tester,
  ) async {
    final fake = FakeCatalogRemote(seed: [buildTestProduct(id: 'p1')]);

    await pumpApp(
      tester,
      const MaterialApp(home: CatalogScreen()),
      overrides: [catalogRemoteProvider.overrideWithValue(fake)],
    );

    await tester.pump();
    expect(find.byType(GridView), findsOneWidget);
    expect(find.byType(ProductCard), findsOneWidget);
  });

  testWidgets('shows an error state with a retry affordance', (tester) async {
    final fake = FakeCatalogRemote(error: Exception('boom'));

    await pumpApp(
      tester,
      const MaterialApp(home: CatalogScreen()),
      overrides: [catalogRemoteProvider.overrideWithValue(fake)],
    );
    await tester.pumpAndSettle();

    expect(find.text('Reintentar'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('shows the all-empty state when there are no products', (
    tester,
  ) async {
    final fake = FakeCatalogRemote(seed: const []);

    await pumpApp(
      tester,
      const MaterialApp(home: CatalogScreen()),
      overrides: [catalogRemoteProvider.overrideWithValue(fake)],
    );
    await tester.pump();

    expect(find.text('Todavía no hay productos cargados.'), findsOneWidget);
    expect(find.text('Ver todos'), findsNothing);
  });

  testWidgets(
    'shows the category-filtered-empty state with a "Ver todos" action',
    (tester) async {
      // The screen's own derivation logic (effectiveSelectedCategoryKeyProvider)
      // guarantees a selected chip always matches >=1 product, so this
      // branch can't be reached by tapping a real chip — it's a defensive
      // rendering path required by the spec regardless. Force it directly
      // by overriding the two providers the screen reads for this branch.
      final fake = FakeCatalogRemote(
        seed: [buildTestProduct(id: 'p1', category: 'Tornillos')],
      );

      await pumpApp(
        tester,
        const MaterialApp(home: CatalogScreen()),
        overrides: [
          catalogRemoteProvider.overrideWithValue(fake),
          effectiveSelectedCategoryKeyProvider.overrideWithValue('tornillos'),
          visibleProductsProvider.overrideWithValue(const AsyncValue.data([])),
        ],
      );
      await tester.pump();

      expect(find.text('No hay productos en esta categoría.'), findsOneWidget);
      expect(find.text('Ver todos'), findsOneWidget);
    },
  );

  testWidgets('chip tap narrows the grid', (tester) async {
    final fake = FakeCatalogRemote(
      seed: [
        buildTestProduct(id: 'p1', category: 'Tornillos'),
        buildTestProduct(id: 'p2', category: 'Clavos'),
      ],
    );

    await pumpApp(
      tester,
      const MaterialApp(home: CatalogScreen()),
      overrides: [catalogRemoteProvider.overrideWithValue(fake)],
    );
    await tester.pump();

    expect(find.byType(ProductCard), findsNWidgets(2));

    await tester.tap(find.widgetWithText(FilterChip, 'Tornillos'));
    await tester.pump();

    expect(find.byType(ProductCard), findsOneWidget);
  });

  testWidgets('placeholder icon renders when imageUrl is null', (tester) async {
    final fake = FakeCatalogRemote(
      seed: [buildTestProduct(id: 'p1', imageUrl: null)],
    );

    await pumpApp(
      tester,
      const MaterialApp(home: CatalogScreen()),
      overrides: [catalogRemoteProvider.overrideWithValue(fake)],
    );
    await tester.pump();

    expect(find.byType(ProductThumbnail), findsOneWidget);
    expect(find.byIcon(Icons.inventory_2_outlined), findsOneWidget);
  });
}
