// lib/feature/restaurant_panel/ui/screens/menu_screen.dart
//
// Wave A placeholder (Task 11): renders until Task 12's
// `registerMenuModule()` replaces the `menu` hub entry (same id) with
// `PanelMenuScreen`. Never delete — it is the pre-module fallback.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('menu'.tr())),
      body: EmptyStateView(
        icon: Iconsax.menu_board,
        title: 'hub_empty'.tr(),
      ),
    );
  }
}
