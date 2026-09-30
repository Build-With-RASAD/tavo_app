// lib/feature/restaurant_panel/ui/screens/reviews_screen.dart
//
// Wave A placeholder (Task 11): renders until the reviews module's
// `registerReviewsModule()` replaces the `reviews` hub entry (same id) with
// `PanelReviewsScreen`. Never delete — it is the pre-module fallback.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('reviews'.tr())),
      body: EmptyStateView(
        icon: Icons.star_border,
        title: 'hub_empty'.tr(),
      ),
    );
  }
}
