// lib/feature/restaurant_auth/ui/screens/staff_shell_screen.dart

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/cache/cache_helper.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/navigation/app_navigator.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_registry.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/more_hub_screen.dart';
import 'package:tavo/feature/restaurant_auth/ui/more/shell_defaults.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/reservations_tab.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/waitlist_tab.dart';
import 'package:tavo/feature/restaurant_auth/ui/screens/restaurant_login_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/panel_alerts_controller.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/dashboard_screen.dart';
import 'package:tavo/feature/restaurant_panel/ui/screens/orders_screen.dart';

/// Staff landing after OTP / cold start: one app bar over five tabs
/// (dashboard / orders / reservations / waitlist / more) for the active venue.
///
/// Owns the active venue: it starts from `CacheHelper.getActiveRestaurant()`
/// when that id is still in [restaurants], otherwise from the first venue,
/// and persists every switch through `CacheHelper.setActiveRestaurant` so a
/// cold start lands on the same place. Each tab builds its own cubit through
/// get_it (the shell only hands over the restaurant id / venue), and the
/// whole tab subtree is keyed by the active id so switching venues
/// re-creates the cubits instead of showing the previous venue's data.
class StaffShellScreen extends StatefulWidget {
  const StaffShellScreen({super.key, required this.restaurants});

  final List<StaffRestaurant> restaurants;

  @override
  State<StaffShellScreen> createState() => _StaffShellScreenState();
}

class _StaffShellScreenState extends State<StaffShellScreen> {
  late String _activeId;
  int _tabIndex = 0;

  /// The status the Orders tab shows (`null` = every order).
  ///
  /// Owned here, not by `OrdersScreen`, because the dashboard and the More
  /// hub both deep-link into the tab with a status while the tab is already
  /// mounted — the shell is the only thing that sees both requests.
  String? _ordersFilter;

  /// Badge counts and the new-order chime. Rebuilt per active venue.
  PanelAlertsController? _alerts;

  @override
  void initState() {
    super.initState();
    registerShellDefaults(); // idempotent placeholder hub tiles
    // The More hub builds its screens at DI time, before the shell exists,
    // so the shell publishes its route to the Orders tab here. A hub screen
    // (the tables screen) reads it when it is built — see the declaration
    // in `more_hub_registry.dart`.
    staffOpenOrders = _openOrdersTab;
    final cached = CacheHelper.getActiveRestaurant();
    final ids = widget.restaurants.map((r) => r.restaurantId);
    if (cached != null && ids.contains(cached)) {
      _activeId = cached;
    } else {
      _activeId = widget.restaurants.isNotEmpty
          ? widget.restaurants.first.restaurantId
          : '';
    }
    _startAlerts();
  }

  @override
  void dispose() {
    staffOpenOrders = null;
    _alerts?.dispose();
    super.dispose();
  }

  void _startAlerts() {
    _alerts?.dispose();
    _alerts = null;
    if (_activeId.isEmpty) return;
    _alerts = PanelAlertsController(
      restaurantId: _activeId,
      onNewOrders: _announceNewOrders,
    )..start();
  }

  void _announceNewOrders() {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('new_order_alert'.tr()),
        action: SnackBarAction(
          label: 'orders'.tr(),
          onPressed: () => _openOrdersTab('pending'),
        ),
      ),
    );
  }

  /// Wraps [icon] in a numeric badge while [count] is positive.
  Widget _badged(ValueListenable<int>? count, Widget icon) {
    if (count == null) return icon;
    return ValueListenableBuilder<int>(
      valueListenable: count,
      builder: (_, value, child) =>
          value > 0 ? Badge(label: Text('$value'), child: child!) : child!,
      child: icon,
    );
  }

  /// Closes a screen pushed from the More hub and shows the Orders tab.
  ///
  /// [status] narrows the list to one status; the dashboard's pipeline
  /// stages hand theirs over so a count lands on the list it names.
  void _openOrdersTab([String? status]) {
    if (!mounted) return;
    popIfPossible();
    setState(() {
      _tabIndex = 1;
      _ordersFilter = status;
    });
  }

  /// Opens a More-hub screen by its registry id (`menu`, `staff`,
  /// `branches`, `reviews`, `settings`) and shows the hub tab.
  ///
  /// An unknown id still lands on the hub tab rather than swallowing the tap,
  /// so a shortcut to a module that has not been registered yet never leaves
  /// the user on a dead screen.
  void _openHub(String hubId) {
    if (!mounted) return;
    setState(() => _tabIndex = 4);
    for (final entry in MoreHubRegistry.entries) {
      if (entry.id != hubId) continue;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => entry.builder(_activeId, _venue),
        ),
      );
      return;
    }
  }

  StaffRestaurant get _venue {
    for (final r in widget.restaurants) {
      if (r.restaurantId == _activeId) return r;
    }
    return const StaffRestaurant();
  }

  void _switchTo(String restaurantId) {
    if (restaurantId == _activeId) return;
    setState(() {
      _activeId = restaurantId;
      // A filter belongs to the venue the user picked it in.
      _ordersFilter = null;
    });
    _startAlerts();
    // Fire-and-forget: SharedPreferences updates its cache synchronously, so
    // a cold start right after the tap still reads the new venue.
    CacheHelper.setActiveRestaurant(restaurantId);
  }

  Future<void> _onLogout() async {
    await getIt<RestaurantAuthRepo>().logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const RestaurantLoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final title = widget.restaurants.isNotEmpty
        ? _venue.displayName(locale)
        : 'my_reservations'.tr();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          if (widget.restaurants.length > 1)
            PopupMenuButton<String>(
              key: const ValueKey('switch_restaurant_button'),
              tooltip: 'switch_restaurant'.tr(),
              onSelected: _switchTo,
              itemBuilder: (context) => [
                // Header naming the menu (ruling: `switch_restaurant` key).
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text('switch_restaurant'.tr()),
                ),
                for (final r in widget.restaurants)
                  PopupMenuItem<String>(
                    value: r.restaurantId,
                    child: Text(r.displayName(locale)),
                  ),
              ],
            ),
          IconButton(
            tooltip: 'logout'.tr(),
            icon: const Icon(Iconsax.logout),
            onPressed: _onLogout,
          ),
        ],
      ),
      body: _activeId.isEmpty
          ? Center(child: Text('no_data'.tr()))
          : KeyedSubtree(
              key: ValueKey(_activeId),
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  DashboardScreen(
                    restaurantId: _activeId,
                    venue: _venue,
                    // Wave 2: every dashboard number is a link into the tab
                    // that acts on it. The order create-flow UI lands as its
                    // own task — until then the shortcut opens the orders
                    // tab (T23 endpoint behind it).
                    onNewOrder: () => setState(() {
                      _tabIndex = 1;
                      _ordersFilter = null;
                    }),
                    onOpenOrders: (status) => setState(() {
                      _tabIndex = 1;
                      _ordersFilter = status;
                    }),
                    onOpenWaitlist: () => setState(() => _tabIndex = 3),
                    onOpenReservations: () => setState(() => _tabIndex = 2),
                    // The More hub lives on the last tab; a shortcut opens
                    // the hub screen itself.
                    onOpenHub: _openHub,
                  ),
                  OrdersScreen(
                    restaurantId: _activeId,
                    statusFilter: _ordersFilter,
                    // The chip row is the user's own choice — the shell keeps
                    // it, so switching tabs and back does not resurrect a
                    // filter the user cleared.
                    onStatusFilterChanged: (status) =>
                        setState(() => _ordersFilter = status),
                  ),
                  ReservationsTab(restaurantId: _activeId),
                  WaitlistTab(restaurantId: _activeId, venue: _venue),
                  MoreHubScreen(restaurantId: _activeId, venue: _venue),
                ],
              ),
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) => setState(() => _tabIndex = index),
        destinations: [
          NavigationDestination(
            icon: const Icon(Iconsax.category),
            selectedIcon: const Icon(Iconsax.category_2),
            label: 'dashboard'.tr(),
          ),
          NavigationDestination(
            icon: _badged(
              _alerts?.pendingOrders,
              const Icon(Iconsax.receipt_2),
            ),
            selectedIcon: _badged(
              _alerts?.pendingOrders,
              const Icon(Iconsax.receipt_text),
            ),
            label: 'orders'.tr(),
          ),
          NavigationDestination(
            icon: const Icon(Iconsax.calendar_1),
            selectedIcon: const Icon(Iconsax.calendar_tick),
            label: 'my_reservations'.tr(),
          ),
          NavigationDestination(
            icon: ValueListenableBuilder<int>(
              valueListenable: waitlistBadgeCount,
              builder: (_, count, child) => count > 0
                  ? Badge(label: Text('$count'), child: child!)
                  : child!,
              child: const Icon(Iconsax.clock),
            ),
            selectedIcon: ValueListenableBuilder<int>(
              valueListenable: waitlistBadgeCount,
              builder: (_, count, child) => count > 0
                  ? Badge(label: Text('$count'), child: child!)
                  : child!,
              child: const Icon(Iconsax.clock),
            ),
            label: 'waitlist'.tr(),
          ),
          NavigationDestination(
            icon: _badged(
              _alerts?.newFeedback,
              const Icon(Iconsax.element_3),
            ),
            selectedIcon: _badged(
              _alerts?.newFeedback,
              const Icon(Iconsax.element_4),
            ),
            label: 'more'.tr(),
          ),
        ],
      ),
    );
  }
}
