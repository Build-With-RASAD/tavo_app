// lib/feature/restaurant_panel/ui/screens/branches_screen.dart
//
// Wave A placeholder (Task 11): renders until the branches module's
// `registerBranchesModule()` replaces the `branches` hub entry (same id)
// with `PanelBranchesScreen`. Never delete — it is the pre-module fallback.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

class BranchesScreen extends StatelessWidget {
  const BranchesScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('branches'.tr())),
      body: EmptyStateView(
        icon: Icons.storefront_outlined,
        title: 'hub_empty'.tr(),
      ),
    );
  }
}
