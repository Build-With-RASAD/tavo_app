// lib/feature/restaurant_auth/ui/more/more_hub_registry.dart
import 'package:flutter/material.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';

/// Builds a hub destination for the active venue.
typedef MoreHubBuilder = Widget Function(String restaurantId, StaffRestaurant venue);

class MoreHubEntry {
  const MoreHubEntry({
    required this.id,
    required this.labelKey,
    required this.icon,
    required this.builder,
  });

  /// Stable id (`menu`, `tables`, `customers`, …) — registration is idempotent on it.
  final String id;
  /// i18n key resolved with `.tr()` when the tile renders.
  final String labelKey;
  final IconData icon;
  final MoreHubBuilder builder;
}

/// App-start registry: every module's `register<Name>Module()` adds its tile,
/// so `service_locator.dart` never carries hub markup and parallel module
/// tasks never share an editable file.
class MoreHubRegistry {
  MoreHubRegistry._();

  static final List<MoreHubEntry> _entries = [];

  static List<MoreHubEntry> get entries => List.unmodifiable(_entries);

  static void register(MoreHubEntry entry) {
    _entries.removeWhere((e) => e.id == entry.id);
    _entries.add(entry);
  }

  /// Shell defaults only: registers [entry] when NO entry with that id
  /// exists yet, so a module's `register<Name>Module()` wins no matter
  /// whether it ran before or after `registerShellDefaults()`.
  static void registerDefault(MoreHubEntry entry) {
    if (_entries.any((e) => e.id == entry.id)) return;
    _entries.add(entry);
  }

  @visibleForTesting
  static void reset() => _entries.clear();
}

/// Published by Task 17's queue screen; the shell renders it as the
/// Waitlist tab badge. Start at 0 (no badge).
final ValueNotifier<int> waitlistBadgeCount = ValueNotifier(0);

/// The staff shell's route back to its Orders tab.
///
/// The More hub builds its screens at DI time, long before the shell exists,
/// so a hub screen cannot receive a shell callback through its constructor —
/// the same constraint [waitlistBadgeCount] already works around. The shell
/// registers its route here in `initState` and clears it on dispose; a hub
/// screen that needs it (the tables screen, for an OCCUPIED table) reads it
/// when it is built.
///
/// Null until the shell has mounted, and null again after it is disposed.
VoidCallback? staffOpenOrders;
