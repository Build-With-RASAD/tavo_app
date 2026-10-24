// lib/feature/qr_table/ui/screens/table_session_screen.dart
//
// The guest's table. Scanning the printed QR opens this screen: it resolves the
// table, joins (or resumes) the shared session, lists the menu, sends orders to
// the kitchen, shows their live status and collects the five-area rating.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/restaurant/data/model/menu_item_model.dart';
import 'package:tavo/feature/restaurant/data/repo/menu_repo.dart';

import '../../data/model/table_session_models.dart';
import '../../data/repo/qr_table_repo.dart';
import '../logic/table_session_cubit.dart';
import '../widgets/rating_sheet.dart';

class TableSessionScreen extends StatefulWidget {
  const TableSessionScreen({
    super.key,
    required this.qrToken,
    this.cubit,
    this.menuRepo,
  });

  /// The token printed on the table's QR code.
  final String qrToken;

  /// Injected by tests; when null the screen owns a real cubit.
  final TableSessionCubit? cubit;

  /// Injected by tests; when null the screen owns a real menu repository.
  final MenuRepo? menuRepo;

  @override
  State<TableSessionScreen> createState() => _TableSessionScreenState();
}

class _TableSessionScreenState extends State<TableSessionScreen> {
  late final TableSessionCubit _cubit;
  late final MenuRepo _menuRepo;
  StreamSubscription<TableSessionState>? _states;
  Timer? _poll;

  List<MenuItemModel> _menu = const [];
  bool _menuLoading = false;
  bool _menuLoaded = false;
  String? _menuError;

  @override
  void initState() {
    super.initState();

    _cubit =
        widget.cubit ??
        TableSessionCubit(
          QrTableRepo(ApiService()),
          PrefsTableGuestStore(),
          qrToken: widget.qrToken,
        );
    _menuRepo = widget.menuRepo ?? MenuRepo(ApiService());

    _states = _cubit.stream.listen(_onState);
    if (widget.cubit == null) {
      _cubit.open();
    }
    _onState(_cubit.state);

    _poll = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _cubit.refresh(),
    );
  }

  @override
  void dispose() {
    _poll?.cancel();
    _states?.cancel();
    // Only close what we created; an injected cubit belongs to the caller.
    if (widget.cubit == null) _cubit.close();
    super.dispose();
  }

  void _onState(TableSessionState state) {
    if (state is! TableSessionReady) return;
    if (_menuLoaded || _menuLoading) return;
    _loadMenu(state.context.restaurantId);
  }

  Future<void> _loadMenu(String restaurantId) async {
    setState(() {
      _menuLoading = true;
      _menuError = null;
    });
    try {
      final response = await _menuRepo.getMenu(
        restaurantId: restaurantId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _menu = response.data?.items ?? const [];
        _menuLoading = false;
        _menuLoaded = true;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _menuError = '$error';
        _menuLoading = false;
      });
    }
  }

  String _l(String ar, String en) =>
      Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

  String _itemTitle(MenuItemModel item) {
    final primary = _l(item.titleAr, item.titleEn);
    if (primary.isNotEmpty) return primary;
    return item.titleAr.isNotEmpty ? item.titleAr : item.titleEn;
  }

  String _money(double value) =>
      '${value.toStringAsFixed(2)} ${_l('ر.س', 'SAR')}';

  Future<void> _placeOrder() async {
    final sent = await _cubit.placeOrder();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? _l('تم إرسال الطلب إلى المطبخ', 'Order sent to the kitchen')
              : _l('تعذر إرسال الطلب', 'Could not send the order'),
        ),
      ),
    );
  }

  Future<void> _rate(TableSessionReady state) async {
    final draft = await showTableRatingSheet(
      context,
      tableCode: state.context.tableCode,
    );
    if (draft == null || !mounted) return;

    final sent = await _cubit.submitRating(draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          sent
              ? _l('شكراً لتقييمك', 'Thank you for your feedback')
              : _l('تعذر إرسال التقييم', 'Could not send your feedback'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TableSessionCubit, TableSessionState>(
      bloc: _cubit,
      listenWhen: (previous, next) =>
          next is TableSessionReady &&
          next.actionError != null &&
          (previous is! TableSessionReady ||
              previous.actionError != next.actionError),
      listener: (context, state) {
        if (state is! TableSessionReady) return;
        final error = state.actionError;
        if (error == null) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
        _cubit.clearError();
      },
      builder: (context, state) => switch (state) {
        TableSessionLoading() => _shell(
          title: _l('طاولة', 'Table'),
          body: const Center(child: CircularProgressIndicator()),
        ),
        TableSessionFailure(:final message) => _shell(
          title: _l('طاولة', 'Table'),
          body: _failure(message),
        ),
        TableSessionReady() => _ready(state),
      },
    );
  }

  Widget _shell({required String title, required Widget body}) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: body,
  );

  Widget _failure(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_scanner_rounded,
            size: 56,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _cubit.open,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(_l('إعادة المحاولة', 'Try again')),
          ),
        ],
      ),
    ),
  );

  Widget _ready(TableSessionReady state) {
    final snapshot = state.snapshot;

    return Scaffold(
      appBar: AppBar(
        title: Text('${_l('طاولة', 'Table')} ${state.context.tableCode}'),
        actions: [
          IconButton(
            tooltip: snapshot.hasRated
                ? _l('تم التقييم', 'Already rated')
                : _l('قيّم التجربة', 'Rate the visit'),
            onPressed: snapshot.hasRated || state.rating
                ? null
                : () => _rate(state),
            icon: Icon(
              snapshot.hasRated
                  ? Icons.verified_rounded
                  : Icons.rate_review_outlined,
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cubit.refresh,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _header(state),
            if (snapshot.guests.isNotEmpty) _party(snapshot),
            if (state.activeOrders.isNotEmpty) _orders(state.activeOrders),
            if (state.pastOrders.isNotEmpty) _orders(state.pastOrders),
            _menuSection(state),
          ],
        ),
      ),
      bottomNavigationBar: state.isCartEmpty ? null : _cartBar(state),
    );
  }

  Widget _header(TableSessionReady state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final contextInfo = state.context;
    final name = _l(contextInfo.restaurantNameAr, contextInfo.restaurantName);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [scheme.primary, scheme.primary.withValues(alpha: 0.72)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.table_restaurant_rounded, color: scheme.onPrimary),
              const SizedBox(width: 8),
              Text(
                '${_l('طاولة', 'Table')} ${contextInfo.tableCode}',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              name,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onPrimary.withValues(alpha: 0.85),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(
                Icons.group_rounded,
                _l(
                  '${state.snapshot.guestCount} ضيوف',
                  '${state.snapshot.guestCount} guests',
                ),
              ),
              if (contextInfo.zone.isNotEmpty)
                _pill(Icons.place_rounded, contextInfo.zone),
              if (state.snapshot.code.isNotEmpty)
                _pill(Icons.receipt_long_rounded, state.snapshot.code),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onPrimary),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: scheme.onPrimary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _party(TableSnapshot snapshot) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
    child: Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final guest in snapshot.guests)
          Chip(
            avatar: const Icon(Icons.person_rounded, size: 16),
            label: Text(
              guest,
              style: TextStyle(
                fontWeight: guest == snapshot.myLabel
                    ? FontWeight.w700
                    : FontWeight.w400,
              ),
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    ),
  );

  Widget _orders(List<TableOrder> orders) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _l('طلبات الطاولة', 'Table orders'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        for (final order in orders) _orderCard(order),
      ],
    ),
  );

  Widget _orderCard(TableOrder order) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '#${order.orderNumber}',
                  style: theme.textTheme.labelLarge,
                ),
                if (order.addedByMe) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _l('طلبي', 'mine'),
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                ],
                const Spacer(),
                _statusChip(order.status),
              ],
            ),
            const SizedBox(height: 6),
            for (final line in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  children: [
                    Text('${line.quantity}×'),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        line.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(_money(line.lineTotal)),
                  ],
                ),
              ),
            if (order.notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  order.notes,
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    final (label, color) = switch (status) {
      'pending' => (_l('بانتظار المطبخ', 'Pending'), Colors.amber.shade700),
      'confirmed' => (_l('مؤكد', 'Confirmed'), Colors.blue.shade600),
      'preparing' => (_l('قيد التحضير', 'Preparing'), Colors.orange.shade800),
      'ready' => (_l('جاهز', 'Ready'), Colors.green.shade600),
      'served' => (_l('تم التقديم', 'Served'), Colors.grey.shade600),
      'cancelled' => (_l('ملغي', 'Cancelled'), Colors.red.shade600),
      _ => (status, Colors.grey.shade600),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _menuSection(TableSessionReady state) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(_l('القائمة', 'Menu'), style: theme.textTheme.titleMedium),
              const Spacer(),
              if (!state.snapshot.canOrder)
                Text(
                  _l('الطلبات مغلقة', 'Ordering closed'),
                  style: theme.textTheme.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_menuLoading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_menuError != null)
            Column(
              children: [
                Text(_menuError!, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () =>
                      _loadMenu(state.context.restaurantId),
                  child: Text(_l('إعادة المحاولة', 'Try again')),
                ),
              ],
            )
          else if (_menu.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                _l('لا توجد أصناف متاحة', 'No items available'),
                style: theme.textTheme.bodyMedium,
              ),
            )
          else
            for (final item in _menu)
              _menuTile(item, state),
        ],
      ),
    );
  }

  Widget _menuTile(MenuItemModel item, TableSessionReady state) {
    final quantity = state.cart[item.id]?.quantity ?? 0;
    final canOrder = state.snapshot.canOrder && item.isAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _itemTitle(item),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(_money(item.price)),
              ],
            ),
          ),
          if (quantity > 0 && canOrder)
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => _cubit.decrementItem(item.id),
              icon: const Icon(Icons.remove_circle_outline_rounded),
            ),
          if (quantity > 0) Text('$quantity'),
          IconButton.filledTonal(
            onPressed: !canOrder
                ? null
                : () => _cubit.addItem(
                    id: item.id,
                    name: _itemTitle(item),
                    price: item.price,
                  ),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }

  Widget _cartBar(TableSessionReady state) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _l(
                    '${state.cartCount} صنف',
                    '${state.cartCount} items',
                  ),
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  _money(state.cartTotal),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: state.placing ? null : _placeOrder,
              icon: state.placing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(_l('إرسال الطلب', 'Send order')),
            ),
          ],
        ),
      ),
    );
  }
}
