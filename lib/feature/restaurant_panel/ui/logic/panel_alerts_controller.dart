// lib/feature/restaurant_panel/ui/logic/panel_alerts_controller.dart
//
// Attention counters for the staff shell: orders waiting to be accepted and
// unread guest feedback. The shell shows them as numeric badges; when the
// pending-order count rises, the phone also rings and buzzes once.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tavo/core/network/api_constants.dart';
import 'package:tavo/core/network/api_service.dart';

class PanelAlertCounts {
  const PanelAlertCounts({this.pendingOrders = 0, this.newFeedback = 0});

  final int pendingOrders;
  final int newFeedback;
}

typedef PanelAlertsFetcher = Future<PanelAlertCounts> Function();

/// Polls two cheap `limit=1` queries and exposes their totals as notifiers.
/// Stops on [dispose]; a failed poll keeps the last counts on screen.
class PanelAlertsController {
  PanelAlertsController({
    required this.restaurantId,
    PanelAlertsFetcher? fetch,
    this.onNewOrders,
    this.pollInterval = const Duration(seconds: 20),
  }) : _fetch = fetch ?? (() => _fetchCounts(restaurantId));

  final String restaurantId;
  final PanelAlertsFetcher _fetch;

  /// Called once per poll that observed more pending orders than the last one.
  final VoidCallback? onNewOrders;
  final Duration pollInterval;

  final ValueNotifier<int> pendingOrders = ValueNotifier<int>(0);
  final ValueNotifier<int> newFeedback = ValueNotifier<int>(0);

  Timer? _timer;
  bool _baselineTaken = false;
  int _lastPending = 0;
  bool _disposed = false;

  void start() {
    refresh();
    _timer ??= Timer.periodic(pollInterval, (_) => refresh());
  }

  Future<void> refresh() async {
    if (_disposed) return;
    try {
      final counts = await _fetch();
      if (_disposed) return;

      final increased =
          _baselineTaken && counts.pendingOrders > _lastPending;
      _baselineTaken = true;
      _lastPending = counts.pendingOrders;

      pendingOrders.value = counts.pendingOrders;
      newFeedback.value = counts.newFeedback;

      if (increased) {
        // No asset and no notification permission: the OS alert tone plus a
        // haptic is the zero-friction signal that a new order landed.
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.mediumImpact();
        onNewOrders?.call();
      }
    } catch (_) {
      // Transient: keep the last badges rather than flashing them to zero.
    }
  }

  void dispose() {
    _disposed = true;
    _timer?.cancel();
    _timer = null;
    pendingOrders.dispose();
    newFeedback.dispose();
  }

  static Future<PanelAlertCounts> _fetchCounts(String restaurantId) async {
    final api = ApiService();
    final results = await Future.wait<int>([
      _total(api, ApiConstants.panelOrders, restaurantId, {'status': 'pending'}),
      _total(
        api,
        '/${ApiConstants.panelBase}/experience-ratings',
        restaurantId,
        {'status': 'new'},
      ),
    ]);
    return PanelAlertCounts(
      pendingOrders: results.first,
      newFeedback: results.last,
    );
  }

  static Future<int> _total(
    ApiService api,
    String path,
    String restaurantId,
    Map<String, String> extra,
  ) async {
    final response = await api.get(
      path,
      queryParameters: {
        'restaurantId': restaurantId,
        'limit': 1,
        ...extra,
      },
    );
    final body = response.data;
    if (body is! Map) return 0;
    final data = body['data'];
    final pagination = data is Map ? data['pagination'] : null;
    if (pagination is Map && pagination['total'] is num) {
      return (pagination['total'] as num).toInt();
    }
    if (data is Map && data['total'] is num) {
      return (data['total'] as num).toInt();
    }
    return 0;
  }
}
