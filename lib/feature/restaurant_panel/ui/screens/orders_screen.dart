// lib/feature/restaurant_panel/ui/screens/orders_screen.dart

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_state.dart';
import 'package:tavo/feature/restaurant_panel/ui/widgets/order_card.dart';
import 'package:tavo/feature/panel_invoice/ui/screens/panel_invoice_screen.dart';
import 'package:tavo/feature/kitchen/ui/screens/kitchen_screen.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// Staff panel orders: a status-filter chip row over the live list, with
/// per-row status actions, a details sheet and an action sheet guarding the
/// destructive cancel.
///
/// Builds its own [OrdersCubit] through get_it (the shell only supplies the
/// restaurant id) and drives the three async states with [ListSkeleton] /
/// [ErrorStateView] / [EmptyStateView] / content, mirroring
/// `DashboardScreen`'s wiring. Action failures surface as a SnackBar while
/// every row stays on screen (`OrdersLoaded.actionError`).
///
/// [statusFilter] is the status the screen opens with — the dashboard hands
/// the status of the pipeline stage that was tapped, so a number in the
/// dashboard really does land on the list it names. The active filter is
/// ALWAYS visible (the chip row selects it and the header names it): a
/// silent filter is never acceptable.
class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.restaurantId,
    this.statusFilter,
    this.onStatusFilterChanged,
  });

  final String restaurantId;

  /// The status the list opens with (`null` = every status).
  final String? statusFilter;

  /// Reports a filter the user picked in the chip row, so the owner of the
  /// screen can keep its own state in sync.
  final void Function(String? status)? onStatusFilterChanged;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrdersCubit _cubit;

  /// The filter row: `all` plus every status the backend accepts
  /// (`GET /orders?status=`).
  static const List<String> _filters = [
    'all',
    'pending',
    'confirmed',
    'preparing',
    'ready',
    'served',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _cubit = getIt<OrdersCubit>(param1: widget.restaurantId);
    final filter = widget.statusFilter;
    // One request: `setFilter` sets the filter and loads page 1 itself.
    if (filter == null) {
      _cubit.load();
    } else {
      _cubit.setFilter(filter);
    }
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The owner changed the filter (the dashboard's pipeline stage): apply
    // it to the list that is already on screen.
    if (widget.statusFilter != oldWidget.statusFilter) {
      _cubit.setFilter(widget.statusFilter);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: BlocConsumer<OrdersCubit, OrdersState>(
        listener: (context, state) {
          if (state is OrdersLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                margin: EdgeInsets.all(16.w),
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<OrdersCubit>();
          final filter = state is OrdersLoaded ? state.filter : null;

          return Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                  _buildHeader(context, filter),
                  _buildFilters(context, cubit, filter),
                  Expanded(child: _buildBody(context, cubit, state)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String? filter) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          Text('orders'.tr(), style: TextStyles.font20Black500Weight(context)),
          if (filter != null) ...[
            SizedBox(width: 8.w),
            // The active filter is named in the header — the list is never
            // silently narrowed.
            Container(
              key: const ValueKey('orders_active_filter'),
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: ColorsManager.primary100.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Iconsax.filter,
                    size: 14.r,
                    color: ColorsManager.primary500,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    orderStatusLabelKey(filter).tr(),
                    style: TextStyles.font12Primary400400Weight(context),
                  ),
                ],
              ),
            ),
          ],
          const Spacer(),
          IconButton(
            key: const ValueKey('orders_open_kitchen'),
            tooltip: 'kitchen_display'.tr(),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    KitchenScreen(restaurantId: widget.restaurantId),
              ),
            ),
            icon: const Icon(Iconsax.cup),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(
    BuildContext context,
    OrdersCubit cubit,
    String? filter,
  ) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            for (final status in _filters)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: ChoiceChip(
                  // Ruling: chips are addressed by key — labels collide with
                  // the status badges of matching rows.
                  key: ValueKey('orders_filter_$status'),
                  label: Text(
                    status == 'all'
                        ? 'all'.tr()
                        : orderStatusLabelKey(status).tr(),
                  ),
                  selected: (filter ?? 'all') == status,
                  onSelected: (_) {
                    final next = status == 'all' ? null : status;
                    cubit.setFilter(next);
                    // The owner of the screen keeps its own filter in sync.
                    widget.onStatusFilterChanged?.call(next);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    OrdersCubit cubit,
    OrdersState state,
  ) {
    if (state is OrdersError) {
      return ErrorStateView(message: state.message, onRetry: cubit.load);
    }
    if (state is OrdersLoaded) {
      if (state.orders.isEmpty) {
        return EmptyStateView(
          icon: Iconsax.receipt_2,
          title: 'no_orders'.tr(),
          onRetry: cubit.load,
        );
      }
      return _PaginatedOrdersList(
        cubit: cubit,
        state: state,
        onAction: (order, target) => _handleAction(context, order, target),
        onOpenDetails: (order) => _openDetails(context, order),
      );
    }
    // OrdersInitial / OrdersLoading.
    return const ListSkeleton();
  }

  /// Runs one row action. Non-destructive targets go straight to the cubit;
  /// `cancelled` first confirms through the [CancelOrderSheet] action sheet
  /// (spec UI bar: destructive actions always confirm).
  Future<void> _handleAction(
    BuildContext context,
    PanelOrder order,
    String target,
  ) async {
    if (target == 'cancelled') {
      final confirmed = await showModalBottomSheet<bool>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => CancelOrderSheet(order: order),
      );
      if (confirmed != true) return;
    }
    if (!context.mounted) return;
    context.read<OrdersCubit>().updateStatus(order.id, target);
  }

  void _openDetails(BuildContext context, PanelOrder order) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) =>
          OrderDetailsSheet(order: order, restaurantId: widget.restaurantId),
    );
  }
}

/// The order list with infinite scroll (I-1): a [ScrollController] fires
/// `cubit.loadMore` when the viewport comes within ~200px of the list end,
/// guarded by the state's `hasNext` and a local in-flight flag so a burst
/// of scroll events can only ever start one page request. While the next
/// page is appending, a spinner footer is built as the last row; the cubit
/// keeps every row of the visible list on screen throughout.
class _PaginatedOrdersList extends StatefulWidget {
  const _PaginatedOrdersList({
    required this.cubit,
    required this.state,
    required this.onAction,
    required this.onOpenDetails,
  });

  final OrdersCubit cubit;
  final OrdersLoaded state;
  final void Function(PanelOrder order, String target) onAction;
  final ValueChanged<PanelOrder> onOpenDetails;

  @override
  State<_PaginatedOrdersList> createState() => _PaginatedOrdersListState();
}

class _PaginatedOrdersListState extends State<_PaginatedOrdersList> {
  final ScrollController _controller = ScrollController();

  /// Local in-flight flag — `OrdersState` carries no `loadingMore`, so the
  /// footer is driven here while the cubit's own `_loadingMore` guard is
  /// the backstop for anything that slips through.
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Infinite-scroll trigger: fires within ~200px of the bottom, and only
  /// when no page append is already running.
  void _onScroll() {
    if (_loadingMore) return;
    final position = _controller.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    final current = widget.cubit.state;
    if (current is! OrdersLoaded || !current.hasNext || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      await widget.cubit.loadMore();
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orders = widget.state.orders;

    return RefreshIndicator(
      onRefresh: () => widget.cubit.load(),
      child: ListView.builder(
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        itemCount: orders.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= orders.length) {
            // Footer: the next page is appending right now.
            return Padding(
              key: const ValueKey('orders_load_more_footer'),
              padding: EdgeInsets.only(top: 4.h),
              child: const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final order = orders[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: OrderCard(
              key: ValueKey('order_card_${order.id}'),
              order: order,
              acting: widget.state.actingId == order.id,
              onAction: (target) => widget.onAction(order, target),
              onTap: () => widget.onOpenDetails(order),
            ),
          );
        },
      ),
    );
  }
}

/// Full breakdown of one order: header + status badge, line items
/// (name, `qty × unitPrice`, line total), subtotal / tax / total rows, the
/// payment pill and a close button.
class OrderDetailsSheet extends StatelessWidget {
  const OrderDetailsSheet({super.key, required this.order, this.restaurantId});

  final PanelOrder order;

  /// Venue id for the invoice entry. Optional so existing call sites keep
  /// compiling; the Invoice button only shows when it is non-empty.
  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final paymentKey = paymentStatusLabelKey(order.paymentStatus);

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'order_details'.tr(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                StatusBadge(status: order.orderStatus),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              order.orderNumber,
              style: TextStyles.font12DarkGray400Weight(context),
            ),
            if (order.customerName.isNotEmpty) ...[
              SizedBox(height: 2.h),
              Text(
                order.customerName,
                style: TextStyles.font12DarkGray400Weight(context),
              ),
            ],
            SizedBox(height: 16.h),
            for (final line in order.items) _LineRow(line: line),
            const Divider(height: 24),
            _AmountRow(labelKey: 'subtotal', value: order.subtotal),
            _AmountRow(labelKey: 'tax', value: order.tax),
            _AmountRow(
              labelKey: 'total',
              value: order.totalPrice,
              emphasize: true,
            ),
            if (paymentKey != null) ...[
              SizedBox(height: 12.h),
              StatusBadge(status: order.paymentStatus, label: paymentKey.tr()),
            ],
            SizedBox(height: 20.h),
            // Task 27 invoice entry: per-order button pushing the ZATCA
            // invoice screen (print + share). Hidden when the venue id is
            // unknown so the sheet never navigates to a venue-less invoice.
            if ((restaurantId ?? '').isNotEmpty) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: ValueKey('order_invoice_${order.id}'),
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PanelInvoiceScreen(
                          orderId: order.id,
                          restaurantId: restaurantId!,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Iconsax.receipt_2),
                  label: Text('inv_title'.tr()),
                ),
              ),
              SizedBox(height: 8.h),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('close'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Action sheet for the destructive cancel: names the order and only sends
/// `true` back when the confirmation button is tapped.
class CancelOrderSheet extends StatelessWidget {
  const CancelOrderSheet({super.key, required this.order});

  final PanelOrder order;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'cancel'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Text(
            '${order.orderNumber} • ${order.customerName}',
            style: TextStyles.font12DarkGray400Weight(context),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('close'.tr()),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  key: const ValueKey('cancel_order_confirm'),
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorsManager.redButton,
                    foregroundColor: ColorsManager.white,
                  ),
                  child: Text('cancel'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One line item row of the details sheet: name + `qty × unitPrice` on the
/// left, the line total on the right.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.name,
                  style: TextStyles.font14Black400Weight(context),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${line.quantity} × ${formatOrderAmount(line.unitPrice)}',
                  style: TextStyles.font12DarkGray400Weight(context),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            formatOrderAmount(line.lineTotal),
            style: TextStyles.font14Black500Weight(context),
          ),
        ],
      ),
    );
  }
}

/// One `label … amount` row (subtotal / tax / total) of the details sheet.
class _AmountRow extends StatelessWidget {
  const _AmountRow({
    required this.labelKey,
    required this.value,
    this.emphasize = false,
  });

  final String labelKey;
  final double value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? TextStyles.font16Black500Weight(context)
        : TextStyles.font14DarkGray400Weight(context);

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          Expanded(child: Text(labelKey.tr(), style: style)),
          Text(formatOrderAmount(value), style: style),
        ],
      ),
    );
  }
}
