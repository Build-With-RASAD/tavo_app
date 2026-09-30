// lib/feature/restaurant_panel/ui/screens/customers_screen.dart
//
// Wave A placeholder (Task 11): renders until the customers module's
// `registerCustomersModule()` replaces the `customers` hub entry (same id)
// with `PanelCustomersScreen`. Never delete — it is the pre-module fallback.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

class CustomersScreen extends StatelessWidget {
  const CustomersScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('customers'.tr())),
      body: EmptyStateView(
        icon: Icons.people_outline,
        title: 'hub_empty'.tr(),
      ),
    );
  }
}
