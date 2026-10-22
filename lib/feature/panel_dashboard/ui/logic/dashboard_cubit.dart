// lib/feature/panel_dashboard/ui/logic/dashboard_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/feature/panel_dashboard/data/repo/analytics_panel_repo.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_state.dart';

export 'dashboard_state.dart';

/// The dashboard's single source of truth.
///
/// Two reads, two cadences (spec decision 2):
///
///   * [load] / [setRange] / [refresh] read the HEAVY `/analytics`
///     endpoint. It runs on a range change and on pull-to-refresh.
///   * [startLivePolling] polls the CHEAP `/analytics/live` endpoint every
///     20 seconds. **The poll merges the `live` object into the current
///     state — it never replaces it** — so the page never flashes empty
///     between two ticks, and the charts (bound to the analytics payload)
///     never re-animate from zero.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit(
    this._repo, {
    required this.restaurantId,
  }) : super(const DashboardInitial());

  final AnalyticsPanelRepo _repo;
  final String restaurantId;

  AnalyticsRange _range = AnalyticsRange.last30Days;
  DateTime? _customFrom;
  DateTime? _customTo;
  Timer? _pollTimer;

  // The two payloads are held apart so a merge never drops one of them.
  DashboardAnalytics? _analytics;
  LiveSnapshot? _live;
  String? _analyticsError;
  String? _liveError;

  /// How many reads are in flight — the screen shows a quiet spinner while
  /// this is above zero.
  int _pendingReads = 0;

  /// The window the business zone reports on.
  AnalyticsRange get range => _range;

  /// The custom window's bounds (only for [AnalyticsRange.custom]).
  DateTime? get customFrom => _customFrom;
  DateTime? get customTo => _customTo;

  /// First read: the heavy payload and the live snapshot in parallel.
  Future<void> load() async {
    if (isClosed) return;
    emit(const DashboardLoading());
    _analyticsError = null;
    _liveError = null;
    await Future.wait([_loadAnalytics(), _loadLive()]);
  }

  /// Switches the window and refetches the heavy payload. The content stays
  /// on screen while the new window loads.
  Future<void> setRange(
    AnalyticsRange range, {
    DateTime? from,
    DateTime? to,
  }) async {
    if (isClosed) return;
    _range = range;
    if (range == AnalyticsRange.custom) {
      _customFrom = from ?? _customFrom;
      _customTo = to ?? _customTo;
    }
    _emit(refreshing: true);
    await _loadAnalytics();
  }

  /// Pull-to-refresh: both endpoints, the heavy one first.
  Future<void> refresh() async {
    if (isClosed) return;
    _emit(refreshing: true);
    await Future.wait([_loadAnalytics(), _loadLive()]);
  }

  /// Polls the cheap endpoint. Only [AnalyticsPanelRepo.getLiveSnapshot]
  /// runs here — the heavy endpoint is never touched by the poll.
  void startLivePolling(Duration interval) {
    if (isClosed) return;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) => refreshLive());
  }

  /// Stops the poll. Called by the screen on dispose and by [close].
  void stopLivePolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// One live tick — the merge point. Exposed so the live section's retry
  /// button can re-read the snapshot without touching the heavy payload.
  Future<void> refreshLive() async {
    if (isClosed) return;
    await _loadLive();
  }

  /// The brief's `dispose()` entry point: stops the poll. [close] calls it
  /// on the bloc lifecycle, so the timer never outlives the screen.
  void dispose() => stopLivePolling();

  @override
  Future<void> close() {
    stopLivePolling();
    return super.close();
  }

  // ===================== the two reads =====================

  Future<void> _loadAnalytics() async {
    _pendingReads++;
    var failed = false;
    try {
      final analytics = await _repo.getAnalytics(
        restaurantId: restaurantId,
        from: _from,
        to: _to,
      );
      if (isClosed) return;
      _analytics = analytics;
      _analyticsError = null;
      // The heavy payload carries its own `live` object — keep the freshest.
      _live = analytics.live;
      _liveError = null;
    } catch (e) {
      if (isClosed) return;
      _analyticsError = _message(e);
      failed = true;
    } finally {
      _pendingReads--;
    }
    // Stay silent while the live band can still render the page: the
    // business zone shows the failure inline instead of the whole screen
    // collapsing (spec decision 14).
    if (failed && _live == null) return;
    _emit();
  }

  Future<void> _loadLive() async {
    _pendingReads++;
    var failed = false;
    try {
      final live = await _repo.getLiveSnapshot(restaurantId);
      if (isClosed) return;
      _live = live;
      _liveError = null;
    } catch (e) {
      if (isClosed) return;
      _liveError = _message(e);
      failed = true;
    } finally {
      _pendingReads--;
    }
    // Nothing at all could be read — that IS a page-level error.
    if (failed && _analytics == null && _analyticsError == null) return;
    _emit();
  }

  /// Emits the steady state. The two payloads are merged, never replaced:
  /// a poll tick keeps the analytics payload (and with it the charts) alive.
  void _emit({bool refreshing = false}) {
    if (isClosed) return;
    // A page that never rendered anything AND has no live band at all can
    // only show one thing: the error.
    if (_analytics == null && _live == null && _analyticsError != null) {
      emit(DashboardError(_analyticsError!));
      return;
    }
    emit(DashboardLoaded(
      range: _range,
      analytics: _analytics,
      live: _live,
      analyticsError: _analyticsError,
      liveError: _liveError,
      customFrom: _customFrom,
      customTo: _customTo,
      refreshing: refreshing || _pendingReads > 0,
    ));
  }

  DateTime get _from {
    if (_range == AnalyticsRange.custom && _customFrom != null) {
      return _customFrom!;
    }
    return _range.from();
  }

  DateTime get _to {
    if (_range == AnalyticsRange.custom && _customTo != null) {
      return _customTo!;
    }
    return _range.to();
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
