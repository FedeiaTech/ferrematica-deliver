import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/widgets/home_shell_helpers.dart';
import '../../../../core/widgets/section_banner.dart';
import '../../../auth/domain/app_session.dart';
import '../../../auth/presentation/providers.dart' show sessionProvider;
import 'delivery_stats_screen.dart';
import 'orders_list_screen.dart';
import 'products_screen.dart';

const List<String> _sectionTitles = ['Pedidos', 'Estadísticas', 'Productos'];

/// Dueño-facing home shell — three tabs (Pedidos / Estadísticas /
/// Productos) behind a persistent, fixed-size [SectionBanner] (role
/// top-right, section name bottom-left — plus the map button there
/// specifically on the Pedidos tab, moved out of [OrdersListScreen]'s own
/// chrome so it's not duplicated). Each tab keeps its own `Scaffold` for
/// its own content (FAB, filter chips, etc.) — this widget only owns the
/// banner and the bottom navigation switching between them.
///
/// Wrapped in a [PopScope] so the Android back button never closes the app
/// from any of these three root tabs without confirmation first (see
/// `confirmExit`).
class DuenoHomeScreen extends ConsumerStatefulWidget {
  const DuenoHomeScreen({super.key});

  @override
  ConsumerState<DuenoHomeScreen> createState() => _DuenoHomeScreenState();
}

class _DuenoHomeScreenState extends ConsumerState<DuenoHomeScreen> {
  int _tabIndex = 0;

  static const _tabs = [
    OrdersListScreen(),
    DeliveryStatsScreen(),
    ProductsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionProvider).value?.rol ?? UserRole.dueno;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (await confirmExit(context)) {
          if (context.mounted) SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            SectionBanner(
              roleLabel: role.label,
              sectionTitle: _sectionTitles[_tabIndex],
              onRoleTap: () => showAccountMenu(context, ref),
              trailingSectionAction: _tabIndex == 0
                  ? IconButton(
                      onPressed: () => context.push('/orders/map'),
                      icon: const Icon(Icons.map_outlined, color: Colors.white),
                      tooltip: 'Mapa de pedidos',
                    )
                  : null,
            ),
            Expanded(
              child: IndexedStack(index: _tabIndex, children: _tabs),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (index) => setState(() => _tabIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Pedidos'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), label: 'Estadísticas'),
            NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Productos'),
          ],
        ),
      ),
    );
  }
}
