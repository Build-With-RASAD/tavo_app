// lib/feature/restaurant_panel/ui/screens/orders_screen.dart
//
// Staff panel orders: the live board, a status filter row, per-row status
// actions, and two sheets (details, destructive cancel).
//
// Visual language is the panel's website kit (`core/ui/tavo_web`) — the same
// gold, hairlines and pill geometry as Tables, Menu and Feedback. Behaviour is
// unchanged: the cubit owns every read/write, the list pages as you scroll,
// and a failed action never removes a row.

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/panel_invoice/ui/screens/panel_invoice_screen.dart';
import 'package:tavo/feature/kitchen/ui/screens/kitchen_screen.dart';
import 'package:tavo/feature/restaurant_panel/data/model/panel_order.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_state.dart';
import 'package:tavo/feature/restaurant_panel/ui/widgets/order_card.dart';

/// Staff panel orders.
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
  static const List<String> _filters = <String>[
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
    final String? filter = widget.statusFilter;
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
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.actionError!),
                  backgroundColor: TavoColors.destructiveSolid,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TavoRadii.lg),
                  ),
                  margin: const EdgeInsets.all(TavoSpace.lg),
                ),
              );
          }
        },
        builder: (context, state) {
          final OrdersCubit cubit = context.read<OrdersCubit>();
          final String? filter = state is OrdersLoaded ? state.filter : null;

          return Scaffold(
            backgroundColor: TavoColors.background,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _Header(
                    filter: filter,
                    onOpenKitchen: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            KitchenScreen(restaurantId: widget.restaurantId),
                      ),
                    ),
                  ),
                  _FilterRow(
                    active: filter,
                    onSelected: (String? next) {
                      cubit.setFilter(next);
                      // The owner of the screen keeps its own filter in sync.
                      widget.onStatusFilterChanged?.call(next);
                    },
                  ),
                  Expanded(child: _buildBody(context, cubit, state)),
                ],
              ),
            ),
          );
        },
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
        onAction: (PanelOrder order, String target) =>
            _handleAction(context, order, target),
        onOpenDetails: (PanelOrder order) => _openDetails(context, order),
      );
    }
    // OrdersInitial / OrdersLoading.
    return const ListSkeleton();
  }

  /// Runs one row action. Non-destructive targets go straight to the cubit;
  /// `cancelled` first confirms through [CancelOrderSheet] (destructive
  /// actions always confirm).
  Future<void> _handleAction(
    BuildContext context,
    PanelOrder order,
    String target,
  ) async {
    if (target == 'cancelled') {
      final bool confirmed =
          await TavoSheet.show<bool>(
            context,
            title: 'cancel_order_title'.tr(),
            child: CancelOrderSheet(order: order),
          ) ??
          false;
      if (!confirmed) return;
    }
    if (!context.mounted) return;
    context.read<OrdersCubit>().updateStatus(order.id, target);
  }

  void _openDetails(BuildContext context, PanelOrder order) {
    TavoSheet.show<void>(
      context,
      title: 'order_details'.tr(),
      child: OrderDetailsSheet(
        order: order,
        restaurantId: widget.restaurantId,
      ),
    );
  }
}

// ------------------------------------------------------------------- header

class _Header extends StatelessWidget {
  const _Header({required this.filter, required this.onOpenKitchen});

  final String? filter;
  final VoidCallback onOpenKitchen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TavoSpace.lg,
        TavoSpace.lg,
        TavoSpace.lg,
        TavoSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('orders'.tr(), style: TavoType.h2),
                if (filter != null) ...<Widget>[
                  const SizedBox(height: TavoSpace.xs),
                  // The active filter is named in the header — the list is
                  // never silently narrowed.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TavoStatusPill(
                      key: const ValueKey<String>('orders_active_filter'),
                      label: orderStatusLabelKey(filter!).tr(),
                      tone: orderStatusTone(filter!),
                      size: TavoPillSize.small,
                      leading: const Icon(Iconsax.filter, size: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: TavoSpace.sm),
          TavoButton.ghost(
            key: const ValueKey<String>('orders_open_kitchen'),
            label: 'kitchen_display'.tr(),
            size: TavoButtonSize.compact,
            leading: const Icon(Iconsax.cup, size: 15),
            onPressed: onOpenKitchen,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ filters

class _FilterRow extends StatelessWidget {
  const _FilterRow({required this.active, required this.onSelected});

  final String? active;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TavoSpace.lg,
        ),
        itemCount: _OrdersScreenState._filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: TavoSpace.xs),
        itemBuilder: (BuildContext context, int index) {
          final String status = _OrdersScreenState._filters[index];
          final bool selected = (active ?? 'all') == status;
          return ChoiceChip(
            // Chips are addressed by key — labels collide with the status
            // badges of matching rows.
            key: ValueKey<String>('orders_filter_$status'),
            label: Text(
              status == 'all'
                  ? 'all'.tr()
                  : orderStatusLabelKey(status).tr(),
            ),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onSelected(status == 'all' ? null : status),
            backgroundColor: TavoColors.muted,
            selectedColor: TavoColors.foreground,
            side: BorderSide(
              color: selected ? TavoColors.foreground : TavoColors.border,
            ),
            shape: const StadiumBorder(),
            labelStyle: TavoType.label.copyWith(
              color: selected ? TavoColors.background : TavoColors.foreground,
            ),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TavoSpace.md,
              vertical: TavoSpace.sm,
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          );
        },
      ),
    );
  }
}

// --------------------------------------------------------------------- list

/// The order list with infinite scroll (I-1): a [ScrollController] fires
/// `cubit.loadMore` when the viewport comes within ~200px of the list end,
/// guarded by the state's `hasNext` and a local in-flight flag so a burst
/// of scroll events can only ever start one page request.
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
    final ScrollPosition position = _controller.position;
    if (position.pixels < position.maxScrollExtent - 200) return;
    _loadNextPage();
  }

  Future<void> _loadNextPage() async {
    final OrdersState current = widget.cubit.state;
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
    final List<PanelOrder> orders = widget.state.orders;

    return RefreshIndicator(
      onRefresh: () => widget.cubit.load(),
      child: ListView.builder(
        key: const ValueKey<String>('orders_list'),
        controller: _controller,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          TavoSpace.lg,
          TavoSpace.sm,
          TavoSpace.lg,
          TavoSpace.xl,
        ),
        itemCount: orders.length + (_loadingMore ? 1 : 0),
        itemBuilder: (BuildContext context, int index) {
          if (index >= orders.length) {
            // Footer: the next page is appending right now.
            return const Padding(
              key: ValueKey<String>('orders_load_more_footer'),
              padding: EdgeInsetsDirectional.only(top: TavoSpace.xs),
              child: Center(
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }
          final PanelOrder order = orders[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: TavoSpace.sm),
            child: OrderCard(
              key: ValueKey<String>('order_card_${order.id}'),
              order: order,
              acting: widget.state.actingId == order.id,
              onAction: (String target) => widget.onAction(order, target),
              onTap: () => widget.onOpenDetails(order),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------ details

/// Full breakdown of one order: line items (`qty × unit price` → line total),
/// subtotal / tax / total, the payment pill and the invoice entry.
///
/// Rendered inside [TavoSheet]; the sheet owns the title, this owns the body.
class OrderDetailsSheet extends StatelessWidget {
  const OrderDetailsSheet({super.key, required this.order, this.restaurantId});

  final PanelOrder order;

  /// Venue id for the invoice entry. Optional so existing call sites keep
  /// compiling; the Invoice button only shows when it is non-empty.
  final String? restaurantId;

  @override
  Widget build(BuildContext context) {
    final String? paymentKey = paymentStatusLabelKey(order.paymentStatus);
    final String customer = <String>[
      if (order.customerName.isNotEmpty) order.customerName,
      if (order.customerPhone.isNotEmpty) order.customerPhone,
    ].join(' • ');

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                order.orderNumber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TavoType.title.copyWith(
                  fontFeatures: TavoType.tabular,
                ),
              ),
            ),
            const SizedBox(width: TavoSpace.sm),
            TavoStatusPill(
              label: order.orderStatus.tr(),
              tone: orderStatusTone(order.orderStatus),
              size: TavoPillSize.small,
            ),
          ],
        ),
        if (customer.isNotEmpty) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            customer,
            style: TavoType.micro.copyWith(color: TavoColors.mutedForeground),
          ),
        ],
        const SizedBox(height: TavoSpace.lg),
        for (final OrderLine line in order.items) _LineRow(line: line),
        const Divider(height: TavoSpace.xl),
        _AmountRow(labelKey: 'subtotal', value: order.subtotal),
        _AmountRow(labelKey: 'tax', value: order.tax),
        _AmountRow(
          labelKey: 'total',
          value: order.totalPrice,
          emphasize: true,
        ),
        if (paymentKey != null) ...<Widget>[
          const SizedBox(height: TavoSpace.md),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TavoStatusPill(
              label: paymentKey.tr(),
              tone: orderStatusTone(order.paymentStatus),
              size: TavoPillSize.small,
            ),
          ),
        ],
        const SizedBox(height: TavoSpace.xl),
        // Per-order invoice entry: pushes the ZATCA invoice screen. Hidden
        // when the venue id is unknown so it can never open a venue-less
        // invoice.
        if ((restaurantId ?? '').isNotEmpty) ...<Widget>[
          TavoButton.secondary(
            key: ValueKey<String>('order_invoice_${order.id}'),
            label: 'inv_title'.tr(),
            expand: true,
            leading: const Icon(Iconsax.receipt_2, size: 16),
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
          ),
          const SizedBox(height: TavoSpace.sm),
        ],
        TavoButton.ghost(
          label: 'close'.tr(),
          expand: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

/// Body of the destructive cancel sheet: names the order and only sends
/// `true` back when the confirmation button is tapped.
class CancelOrderSheet extends StatelessWidget {
  const CancelOrderSheet({super.key, required this.order});

  final PanelOrder order;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          order.customerName.isEmpty
              ? order.orderNumber
              : '${order.orderNumber} • ${order.customerName}',
          style: TavoType.bodySmall.copyWith(
            color: TavoColors.mutedForeground,
          ),
        ),
        const SizedBox(height: TavoSpace.lg),
        Row(
          children: <Widget>[
            Expanded(
              child: TavoButton.ghost(
                label: 'close'.tr(),
                expand: true,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: TavoSpace.sm),
            Expanded(
              child: TavoButton.destructive(
                key: const ValueKey<String>('cancel_order_confirm'),
                label: 'cancel'.tr(),
                expand: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// One line item row: name + `qty × unitPrice` on the leading side, the line
/// total on the trailing side.
class _LineRow extends StatelessWidget {
  const _LineRow({required this.line});

  final OrderLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: TavoSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: TavoColors.muted,
              borderRadius: BorderRadius.circular(TavoRadii.sm),
            ),
            child: Text(
              '${line.quantity}',
              style: TavoType.micro.copyWith(
                fontWeight: FontWeight.w700,
                fontFeatures: TavoType.tabular,
              ),
            ),
          ),
          const SizedBox(width: TavoSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(line.name, style: TavoType.bodySmall),
                const SizedBox(height: 2),
                Text(
                  '${line.quantity} × ${formatOrderAmount(line.unitPrice)}',
                  style: TavoType.micro.copyWith(
                    color: TavoColors.mutedForeground,
                  ),
                ),
                if (line.note.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      line.note,
                      style: TavoType.micro.copyWith(
                        color: TavoColors.brand800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: TavoSpace.md),
          Text(
            formatOrderAmount(line.lineTotal),
            style: TavoType.label.copyWith(
              fontFeatures: TavoType.tabular,
            ),
          ),
        ],
      ),
    );
  }
}

/// One `label … amount` row (subtotal / tax / total).
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
    final TextStyle style = emphasize
        ? TavoType.title.copyWith(fontFeatures: TavoType.tabular)
        : TavoType.bodySmall.copyWith(color: TavoColors.mutedForeground);

    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: TavoSpace.xs),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(labelKey.tr(), style: style)),
          Text(formatOrderAmount(value), style: style),
        ],
      ),
    );
  }
}
