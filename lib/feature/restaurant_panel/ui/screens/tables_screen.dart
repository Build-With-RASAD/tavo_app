// lib/feature/restaurant_panel/ui/screens/tables_screen.dart
//
// Wave A placeholder (Task 11): renders until the tables module's
// `registerTablesModule()` replaces the `tables` hub entry (same id) with
// `PanelTablesScreen`. Never delete — it is the pre-module fallback.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

class TablesScreen extends StatelessWidget {
  const TablesScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('tables'.tr())),
      body: EmptyStateView(
        icon: Icons.table_chart_outlined,
        title: 'hub_empty'.tr(),
      ),
    );
  }
}
