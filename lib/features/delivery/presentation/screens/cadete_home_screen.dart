import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/home_shell_helpers.dart';
import '../../../../core/widgets/section_banner.dart';
import '../../../auth/domain/app_session.dart';
import '../../../auth/presentation/providers.dart' show sessionProvider;
import '../../../orders/presentation/screens/delivery_stats_screen.dart';
import 'cadete_orders_screen.dart';

const List<String> _sectionTitles = ['Pedidos', 'Estadísticas'];

/// Cadete-facing home shell — two tabs (Pedidos / Estadísticas) behind a
/// persistent, fixed-size [SectionBanner] (role top-right, section name
/// bottom-left), mirroring [DuenoHomeScreen]'s shape minus the dueño-only
/// "Productos" tab and the map button (cadete's Pedidos tab has no map
/// action).
///
/// Wrapped in a [PopScope] so the Android back button never closes the app
/// from either root tab without confirmation first (see `confirmExit`).
class CadeteHomeScreen extends ConsumerStatefulWidget {
  const CadeteHomeScreen({super.key});

  @override
  ConsumerState<CadeteHomeScreen> createState() => _CadeteHomeScreenState();
}

class _CadeteHomeScreenState extends ConsumerState<CadeteHomeScreen> {
  int _tabIndex = 0;

  static const _tabs = [CadeteOrdersScreen(), DeliveryStatsScreen()];

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(sessionProvider).value?.rol ?? UserRole.cadete;

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
              onRoleTap: () => showAccountMenu(context, ref, role: role),
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
          ],
        ),
      ),
    );
  }
}
