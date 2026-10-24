// lib/feature/kitchen/ui/screens/kitchen_screen.dart
//
// The kitchen display: three stations (incoming, preparing, ready), one tap to
// move an order forward, and a waiting time that turns red before the guest
// starts asking.
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/core/network/api_service.dart';

import '../../../restaurant_panel/data/model/panel_order.dart';
import '../../../restaurant_panel/data/repo/restaurant_panel_repo.dart';
import '../logic/kitchen_cubit.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class KitchenScreen extends StatefulWidget {
  const KitchenScreen({super.key, required this.restaurantId, this.cubit});

  final String restaurantId;

  /// Injected by tests; when null the screen owns a real cubit.
  final KitchenCubit? cubit;

  @override
  State<KitchenScreen> createState() => _KitchenScreenState();
}

class _KitchenScreenState extends State<KitchenScreen> {
  late final KitchenCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit =
        widget.cubit ??
        KitchenCubit(
          RestaurantPanelRepo(ApiService()),
          restaurantId: widget.restaurantId,
        );
    if (widget.cubit == null) _cubit.start();
  }

  @override
  void dispose() {
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  String _l(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<KitchenCubit, KitchenState>(
      bloc: _cubit,
      listenWhen: (previous, next) =>
          next is KitchenBoard &&
          next.actionError != null &&
          (previous is! KitchenBoard ||
              previous.actionError != next.actionError),
      listener: (context, state) {
        if (state is! KitchenBoard) return;
        final error = state.actionError;
        if (error == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        _cubit.clearError();
      },
      builder: (context, state) => switch (state) {
        KitchenLoading() => Scaffold(
          appBar: AppBar(title: Text(_l('شاشة المطبخ', 'Kitchen display'))),
          body: const Center(child: CircularProgressIndicator()),
        ),
        KitchenFailure(:final message) => Scaffold(
          appBar: AppBar(title: Text(_l('شاشة المطبخ', 'Kitchen display'))),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _cubit.load,
                  icon: const Icon(Iconsax.refresh),
                  label: Text(_l('إعادة المحاولة', 'Try again')),
                ),
              ],
            ),
          ),
        ),
        KitchenBoard() => _board(state),
      },
    );
  }

  Widget _board(KitchenBoard state) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_l('شاشة المطبخ', 'Kitchen display')),
          actions: [
            IconButton(
              tooltip: _l('تحديث', 'Refresh'),
              onPressed: _cubit.load,
              icon: const Icon(Iconsax.refresh),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: '${_l('جديد', 'Incoming')} (${state.incoming.length})'),
              Tab(
                text: '${_l('قيد التحضير', 'Preparing')} (${state.preparing.length})',
              ),
              Tab(text: '${_l('جاهز', 'Ready')} (${state.ready.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _station(state.incoming, state),
            _station(state.preparing, state),
            _station(state.ready, state),
          ],
        ),
      ),
    );
  }

  Widget _station(List<PanelOrder> orders, KitchenBoard state) {
    if (orders.isEmpty) {
      return Center(
        child: Text(
          _l('لا توجد طلبات هنا', 'Nothing here'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _cubit.load(silent: true),
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: orders.length,
        itemBuilder: (context, index) => _orderCard(orders[index], state),
      ),
    );
  }

  Widget _orderCard(PanelOrder order, KitchenBoard state) {
    final theme = Theme.of(context);
    final waiting = order.minutesWaiting();
    final busy = state.updatingId == order.id;
    final accent = waiting >= 20
        ? Colors.red.shade600
        : waiting >= 10
        ? Colors.orange.shade800
        : Colors.green.shade600;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order.tableCode.isNotEmpty
                        ? '${_l('طاولة', 'Table')} ${order.tableCode}'
                        : order.customerName.isNotEmpty
                        ? order.customerName
                        : '#${order.orderNumber}',
                    style: theme.textTheme.labelLarge,
                  ),
                ),
                const SizedBox(width: 8),
                if (order.sessionCode.isNotEmpty)
                  Text(order.sessionCode, style: theme.textTheme.bodySmall),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    _l('$waiting د', '$waiting min'),
                    style: TextStyle(
                      color: accent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final line in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Text(
                      '${line.quantity}×',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('#${order.orderNumber}', style: theme.textTheme.bodySmall),
                const Spacer(),
                FilledButton.icon(
                  onPressed: busy ? null : () => _cubit.advance(order),
                  icon: busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Iconsax.arrow_right_2, size: 18),
                  label: Text(_nextLabel(order.orderStatus)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _nextLabel(String status) => switch (status) {
    'pending' || 'confirmed' => _l('ابدأ التحضير', 'Start'),
    'preparing' => _l('جاهز', 'Ready'),
    'ready' => _l('قدّم', 'Serve'),
    _ => _l('تم', 'Done'),
  };
}
