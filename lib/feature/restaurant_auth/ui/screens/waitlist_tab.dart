// lib/feature/restaurant_auth/ui/screens/waitlist_tab.dart
//
// Wave A placeholder: Task 17 replaces the body with the real queue
// (skeleton → list, filters, action rows, badge publication).
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

class WaitlistTab extends StatelessWidget {
  const WaitlistTab({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: EmptyStateView(
        icon: Icons.queue_music_outlined,
        title: 'waitlist_empty'.tr(),
      ),
    );
  }
}
