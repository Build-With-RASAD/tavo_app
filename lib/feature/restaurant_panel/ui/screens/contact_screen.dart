// lib/feature/restaurant_panel/ui/screens/contact_screen.dart
//
// Wave A placeholder (Task 11): renders until the contact module's
// `registerContactModule()` replaces the `contact` hub entry (same id) with
// `PanelContactScreen`. Never delete — it is the pre-module fallback.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('contact_qr'.tr())),
      body: EmptyStateView(
        icon: Iconsax.scan,
        title: 'hub_empty'.tr(),
      ),
    );
  }
}
