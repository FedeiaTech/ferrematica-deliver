import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../../auth/domain/app_session.dart';
import '../../../auth/domain/cadete_directory.dart';
import '../../../auth/presentation/providers.dart' show cadeteListProvider, sessionProvider;
import '../../../delivery/presentation/providers.dart' show cadeteOrdersProvider;
import '../../domain/order.dart';
import '../providers.dart' show ordersStreamProvider;

enum _StatsPeriod { hoy, semana, mes }

final StateProvider<_StatsPeriod> _statsPeriodProvider = StateProvider<_StatsPeriod>(
  (ref) => _StatsPeriod.hoy,
);

/// Delivery stats, role-aware: a cadete sees only their own numbers (for
/// settling their pay), the dueño sees a per-cadete breakdown — including
/// their own self-deliveries, labeled "Base" — for Entregados / Cancelados
/// / Cobrado / Pendientes de cobrar (+ monto adeudado) over the selected
/// period, a Hoy/Semana/Mes delivered-count bar chart, and a running
/// "Problemas reportados este mes" list (always calendar-month,
/// independent of the period selector) so the dueño can spot patterns
/// like a cadete with repeated "inconveniente con el vehículo" reports.
class DeliveryStatsScreen extends ConsumerWidget {
  const DeliveryStatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider).value;
    final isDueno = session?.rol == UserRole.dueno;
    final ordersAsync = isDueno
        ? ref.watch(ordersStreamProvider)
        : ref.watch(cadeteOrdersProvider);
    final cadetesAsync = ref.watch(cadeteListProvider);
    final period = ref.watch(_statsPeriodProvider);

    return Scaffold(
      body: session == null
          ? const SizedBox.shrink()
          : ordersAsync.when(
              data: (orders) => _StatsBody(
                orders: orders,
                isDueno: isDueno,
                ownUserId: session.userId,
                cadetesAsync: cadetesAsync,
                period: period,
              ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  Center(child: Text('Error al cargar estadísticas: $error')),
            ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({
    required this.orders,
    required this.isDueno,
    required this.ownUserId,
    required this.cadetesAsync,
    required this.period,
  });

  final List<Order> orders;
  final bool isDueno;
  final String ownUserId;
  final AsyncValue<List<CadeteProfile>> cadetesAsync;
  final _StatsPeriod period;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final periodStart = _periodStart(period, now);
    final monthStart = DateTime(now.year, now.month, 1);

    final byAssignee = <String, _AssigneeStats>{};
    // Chart buckets depend on the selected period's granularity: hour of
    // day for Hoy, weekday for Semana, week-of-month for Mes — see
    // [_chartBucket]'s doc for exactly how each is computed.
    final chartByAssignee = <String, Map<int, int>>{};
    for (final order in orders) {
      final assignee = order.assignedCadeteId;
      if (assignee == null) continue;
      final stats = byAssignee.putIfAbsent(assignee, _AssigneeStats.new);

      if (order.status == OrderStatus.entregado && order.deliveredAt != null) {
        final deliveredAt = order.deliveredAt!;

        if (!deliveredAt.isBefore(periodStart)) {
          stats.delivered++;
          if (order.paymentStatus == PaymentStatus.cobrado) {
            // DA5: a `cobrado` order can still carry a non-null
            // `pendingBalance` (a partial collection) — crediting the full
            // `amountToCharge` here would silently misreport it as fully
            // collected. Credit only what was actually collected, and
            // surface the still-owed portion the same way a `pendiente`
            // order does below.
            final pending = order.pendingBalance;
            if (order.amountToCharge != null) {
              stats.amountCollected += order.amountToCharge! - (pending ?? 0);
            }
            if (pending != null) {
              stats.pendingPaymentCount++;
              stats.pendingPaymentAmount += pending;
            }
          } else {
            stats.pendingPaymentCount++;
            if (order.amountToCharge != null) stats.pendingPaymentAmount += order.amountToCharge!;
          }

          final bucket = _chartBucket(period, deliveredAt, monthStart);
          final buckets = chartByAssignee.putIfAbsent(assignee, () => <int, int>{});
          buckets[bucket] = (buckets[bucket] ?? 0) + 1;
        }
      } else if (order.status == OrderStatus.cancelado) {
        // No dedicated `cancelledAt` field — `updatedAt` is the closest
        // proxy for "when this landed in cancelado", good enough for a
        // period bucket.
        if (!order.updatedAt.isBefore(periodStart)) stats.cancelledOrProblem++;
      }
    }

    final problemsByAssignee = <String, Map<String, int>>{};
    for (final order in orders) {
      final assignee = order.assignedCadeteId;
      final problem = order.deliveryProblem;
      if (assignee == null || problem == null) continue;
      if (order.updatedAt.isBefore(monthStart)) continue;
      final reasons = problemsByAssignee.putIfAbsent(assignee, () => <String, int>{});
      reasons[problem] = (reasons[problem] ?? 0) + 1;
    }

    String nameFor(String id) {
      if (id == ownUserId) return isDueno ? 'Base (vos)' : 'Vos';
      return cadetesAsync.maybeWhen(
        data: (cadetes) {
          for (final cadete in cadetes) {
            if (cadete.id == id) return cadete.displayName;
          }
          return id;
        },
        orElse: () => id,
      );
    }

    if (!isDueno) {
      final stats = byAssignee[ownUserId] ?? _AssigneeStats();
      final problems = problemsByAssignee[ownUserId] ?? const <String, int>{};
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _PeriodSelector(period: period),
          const SizedBox(height: 16),
          _StatsCard(title: 'Vos', stats: stats),
          const SizedBox(height: 16),
          _DeliveredBarChart(
            period: period,
            buckets: chartByAssignee[ownUserId] ?? const <int, int>{},
            monthStart: monthStart,
          ),
          if (problems.isNotEmpty) ...[
            const SizedBox(height: 24),
            _ProblemsList(title: 'Problemas reportados este mes', reasons: problems),
          ],
        ],
      );
    }

    final assigneeIds = byAssignee.keys.toSet()..addAll(problemsByAssignee.keys);
    final sortedIds = assigneeIds.toList()..sort((a, b) => nameFor(a).compareTo(nameFor(b)));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _PeriodSelector(period: period),
        const SizedBox(height: 16),
        if (sortedIds.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('Todavía no hay entregas registradas en este período.'),
          ),
        for (final id in sortedIds) ...[
          _StatsCard(title: nameFor(id), stats: byAssignee[id] ?? _AssigneeStats()),
          const SizedBox(height: 8),
          _DeliveredBarChart(
            period: period,
            buckets: chartByAssignee[id] ?? const <int, int>{},
            monthStart: monthStart,
          ),
          if ((problemsByAssignee[id] ?? const <String, int>{}).isNotEmpty) ...[
            const SizedBox(height: 8),
            _ProblemsList(
              title: 'Problemas de ${nameFor(id)} este mes',
              reasons: problemsByAssignee[id]!,
            ),
          ],
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _AssigneeStats {
  // Selected-period metrics (driven by `_statsPeriodProvider`).
  int delivered = 0;
  int cancelledOrProblem = 0;
  double amountCollected = 0;
  int pendingPaymentCount = 0;
  double pendingPaymentAmount = 0;
}

/// Which chart bucket a delivered order's `deliveredAt` falls into, given
/// the selected period's granularity:
/// - Hoy → hour of day (0-23)
/// - Semana → weekday, Sunday-first (0=Sun..6=Sat — `DateTime.weekday % 7`,
///   since `DateTime.weekday` is 1=Mon..7=Sun)
/// - Mes → week-of-month index (0-based, weeks of 7 days from the 1st)
int _chartBucket(_StatsPeriod period, DateTime deliveredAt, DateTime monthStart) {
  switch (period) {
    case _StatsPeriod.hoy:
      return deliveredAt.hour;
    case _StatsPeriod.semana:
      return deliveredAt.weekday % 7;
    case _StatsPeriod.mes:
      return deliveredAt.difference(monthStart).inDays ~/ 7;
  }
}

DateTime _periodStart(_StatsPeriod period, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  switch (period) {
    case _StatsPeriod.hoy:
      return today;
    case _StatsPeriod.semana:
      // Week starts on Sunday — subtract back to the most recent Sunday
      // (today.weekday % 7 is 0 when today already is Sunday).
      return today.subtract(Duration(days: today.weekday % 7));
    case _StatsPeriod.mes:
      return DateTime(now.year, now.month, 1);
  }
}

String _periodLabel(_StatsPeriod period) => switch (period) {
  _StatsPeriod.hoy => 'Hoy',
  _StatsPeriod.semana => 'Esta semana',
  _StatsPeriod.mes => 'Este mes',
};

class _PeriodSelector extends ConsumerWidget {
  const _PeriodSelector({required this.period});

  final _StatsPeriod period;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 8,
      children: [
        for (final option in _StatsPeriod.values)
          ChoiceChip(
            label: Text(_periodLabel(option)),
            selected: period == option,
            onSelected: (_) => ref.read(_statsPeriodProvider.notifier).state = option,
          ),
      ],
    );
  }
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.title, required this.stats});

  final String title;
  final _AssigneeStats stats;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatValue(label: 'Entregados', value: '${stats.delivered}'),
                _StatValue(label: 'Cancelados', value: '${stats.cancelledOrProblem}'),
                _StatValue(
                  label: 'Cobrado',
                  value: '\$${stats.amountCollected.toStringAsFixed(2)}',
                ),
              ],
            ),
            if (stats.pendingPaymentCount > 0) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _StatValue(
                    label: 'Pendientes de cobrar',
                    value: '${stats.pendingPaymentCount}',
                    color: Theme.of(context).colorScheme.error,
                  ),
                  _StatValue(
                    label: 'Monto adeudado',
                    value: '\$${stats.pendingPaymentAmount.toStringAsFixed(2)}',
                    color: Theme.of(context).colorScheme.error,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatValue extends StatelessWidget {
  const _StatValue({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color ?? Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Basic dark-bar chart of delivered orders, with a granularity that
/// tracks the selected period — Hoy shows one bar per hour, Semana one
/// bar per weekday, Mes one bar per week-of-month (see [_chartBucket]).
/// Every bucket in the period's full range is rendered (even ones with
/// zero deliveries), wrapped in a horizontal scroll view so a 24-bar
/// "Hoy" chart never overflows a narrow phone screen.
class _DeliveredBarChart extends StatelessWidget {
  const _DeliveredBarChart({
    required this.period,
    required this.buckets,
    required this.monthStart,
  });

  final _StatsPeriod period;
  final Map<int, int> buckets;
  final DateTime monthStart;

  static const double _maxBarHeight = 100;

  List<({String label, int bucket})> _bucketRange() {
    switch (period) {
      case _StatsPeriod.hoy:
        return [for (var hour = 0; hour < 24; hour++) (label: '${hour}h', bucket: hour)];
      case _StatsPeriod.semana:
        const weekdayLabels = ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'];
        return [
          for (var bucket = 0; bucket < 7; bucket++)
            (label: weekdayLabels[bucket], bucket: bucket),
        ];
      case _StatsPeriod.mes:
        final daysInMonth = DateTime(monthStart.year, monthStart.month + 1, 0).day;
        final totalWeeks = (daysInMonth / 7).ceil();
        return [
          for (var week = 0; week < totalWeeks; week++) (label: 'Sem ${week + 1}', bucket: week),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final range = _bucketRange();
    final maxCount = buckets.values.fold(0, (a, b) => a > b ? a : b);
    final barColor = Theme.of(context).colorScheme.onSurface;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Entregados — ${_periodLabel(period)}', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 12),
            // Centered when the bars fit the available width, scrollable
            // (left-anchored, same as before) once they don't — the
            // `ConstrainedBox` + `Center` combo lets a `SingleChildScrollView`
            // do both without measuring the content itself.
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Center(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final entry in range)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 6),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${buckets[entry.bucket] ?? 0}',
                                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Container(
                                    width: 20,
                                    height: maxCount == 0
                                        ? 4
                                        : (_maxBarHeight * (buckets[entry.bucket] ?? 0) / maxCount)
                                            .clamp(4, _maxBarHeight),
                                    decoration: BoxDecoration(
                                      color: barColor,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(3),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    entry.label,
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProblemsList extends StatelessWidget {
  const _ProblemsList({required this.title, required this.reasons});

  final String title;
  final Map<String, int> reasons;

  @override
  Widget build(BuildContext context) {
    final entries = reasons.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in entries)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  '${entry.value}x  ${entry.key}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
