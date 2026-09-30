// lib/feature/restaurant_panel/ui/screens/staff_screen.dart
//
// Wave A placeholder (Task 11): renders until the staff module's
// `registerStaffModule()` replaces the `staff` hub entry (same id) with
// `PanelStaffScreen`. Never delete — it is the pre-module fallback.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

class StaffScreen extends StatelessWidget {
  const StaffScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('staff'.tr())),
      body: EmptyStateView(
        icon: Icons.badge_outlined,
        title: 'hub_empty'.tr(),
      ),
    );
  }
}
