// lib/feature/panel_settings/ui/screens/panel_settings_screen.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_settings/data/model/settings_models.dart';
import 'package:tavo/feature/panel_settings/data/repo/settings_panel_repo.dart';
import 'package:tavo/feature/panel_settings/ui/logic/settings_panel_cubit.dart';

/// Staff panel settings: working-hours editors, reservation rules and a
/// read-only availability summary.
///
/// Builds its own [SettingsPanelCubit] through get_it (mirroring
/// `PanelMenuScreen`) and drives the three async states with
/// [ListSkeleton] / [ErrorStateView] / content. Save failures keep the
/// form and surface a SnackBar (`SettingsPanelLoaded.actionError`).
///
/// [canManage] defaults to the `manage_settings` gate
/// (owner / manager / full_access / manage_settings); view-only staff get
/// disabled fields and no save buttons.
class PanelSettingsScreen extends StatefulWidget {
  const PanelSettingsScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
    this.canManage,
  });

  final String restaurantId;
  final StaffRestaurant venue;
  final bool Function()? canManage;

  @override
  State<PanelSettingsScreen> createState() => _PanelSettingsScreenState();
}

class _PanelSettingsScreenState extends State<PanelSettingsScreen> {
  final _formKey = GlobalKey<_LoadedFormState>();

  bool _manage() =>
      widget.canManage?.call() ??
      widget.venue.role == 'owner' ||
          widget.venue.role == 'manager' ||
          widget.venue.permissions.contains('full_access') ||
          widget.venue.permissions.contains('manage_settings');

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsPanelCubit(
        getIt<SettingsPanelRepo>(),
        restaurantId: widget.restaurantId,
      )..load(),
      child: BlocConsumer<SettingsPanelCubit, SettingsPanelState>(
        listener: (context, state) {
          if (state is SettingsPanelLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<SettingsPanelCubit>();
          final loaded = state is SettingsPanelLoaded ? state : null;
          final manageable = _manage();
          return Scaffold(
            body: SafeArea(child: _buildBody(context, cubit, state)),
            // Pinned actions: the full form is taller than small screens,
            // so both saves live in a fixed bar instead of inside the
            // scroll (widget tests tap them without scrolling).
            bottomNavigationBar: (loaded != null && manageable)
                ? SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              key: const Key('save_hours'),
                              onPressed: loaded.saving
                                  ? null
                                  : () => _formKey.currentState?.saveHours(),
                              child: loaded.saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text('save_hours'.tr()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              key: const Key('save_settings'),
                              onPressed: loaded.saving
                                  ? null
                                  : () =>
                                      _formKey.currentState?.saveSettings(),
                              child: loaded.saving
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : Text('save_settings'.tr()),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    SettingsPanelCubit cubit,
    SettingsPanelState state,
  ) {
    if (state is SettingsPanelError) {
      return Column(
        children: [
          Expanded(
            child: ErrorStateView(message: state.message, onRetry: cubit.load),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cubit.load,
          ),
          const SizedBox(height: 8),
        ],
      );
    }
    if (state is SettingsPanelLoaded) {
      return _LoadedForm(
        key: _formKey,
        loaded: state,
        manageable: _manage(),
        onSaveHours: cubit.saveWorkingHours,
        onSaveSettings: cubit.saveReservationSettings,
      );
    }
    // SettingsPanelInitial / SettingsPanelLoading.
    return const ListSkeleton();
  }
}

final _timePattern = RegExp(r'^([01][0-9]|2[0-3]):[0-5][0-9]$');

class _LoadedForm extends StatefulWidget {
  const _LoadedForm({
    super.key,
    required this.loaded,
    required this.manageable,
    required this.onSaveHours,
    required this.onSaveSettings,
  });

  final SettingsPanelLoaded loaded;
  final bool manageable;
  final Future<void> Function(List<WorkingDayEntry> days) onSaveHours;
  final Future<void> Function(ReservationSettings rs) onSaveSettings;

  @override
  State<_LoadedForm> createState() => _LoadedFormState();
}

class _LoadedFormState extends State<_LoadedForm> {
  late final Map<String, bool> _closed = {
    for (final d in widget.loaded.days) d.day: d.isClosed,
  };
  late final Map<String, TextEditingController> _open = {
    for (final d in widget.loaded.days)
      d.day: TextEditingController(text: d.openTime),
  };
  late final Map<String, TextEditingController> _close = {
    for (final d in widget.loaded.days)
      d.day: TextEditingController(text: d.closeTime),
  };
  late final TextEditingController _slot = TextEditingController(
      text: '${widget.loaded.rs.slotDurationMinutes}');
  late final TextEditingController _advance = TextEditingController(
      text: '${widget.loaded.rs.minAdvanceNoticeDays}');
  late bool _special = widget.loaded.rs.specialMenuAvailable;
  late bool _notice = widget.loaded.rs.needsAdvanceNotice;
  String? _hoursError;
  String? _rsError;

  @override
  void dispose() {
    for (final c in [..._open.values, ..._close.values, _slot, _advance]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final openDays =
        widget.loaded.availability.where((d) => !d.isClosed).length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'working_hours'.tr(),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final day in widget.loaded.days) _dayRow(day),
          if (_hoursError != null) ...[
            const SizedBox(height: 4),
            Text(
              _hoursError!,
              style: textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFFC62828)),
            ),
          ],
          const SizedBox(height: 8),
          const SizedBox(height: 24),
          Text(
            'reservation_settings'.tr(),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('rs_slot'),
            controller: _slot,
            enabled: widget.manageable,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'slot_minutes'.tr()),
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('rs_advance'),
            controller: _advance,
            enabled: widget.manageable,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'advance_days'.tr()),
          ),
          SwitchListTile(
            key: const Key('rs_special'),
            title: Text('special_menu'.tr()),
            value: _special,
            onChanged: widget.manageable
                ? (v) => setState(() => _special = v)
                : null,
          ),
          SwitchListTile(
            key: const Key('rs_notice'),
            title: Text('advance_notice'.tr()),
            value: _notice,
            onChanged:
                widget.manageable ? (v) => setState(() => _notice = v) : null,
          ),
          if (_rsError != null) ...[
            const SizedBox(height: 4),
            Text(
              _rsError!,
              style: textTheme.bodySmall
                  ?.copyWith(color: const Color(0xFFC62828)),
            ),
          ],
          const SizedBox(height: 8),
          const SizedBox(height: 24),
          Text(
            'availability'.tr(),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                      '${'slot_minutes'.tr()}: ${widget.loaded.rs.slotDurationMinutes}'),
                  const SizedBox(height: 4),
                  Text(
                      '${'advance_days'.tr()}: ${widget.loaded.rs.minAdvanceNoticeDays}'),
                  const SizedBox(height: 4),
                  Text('$openDays/7'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayRow(WorkingDayEntry day) {
    final closed = _closed[day.day] ?? day.isClosed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text('settings_day_${day.day}'.tr())),
          Text(closed ? 'closed'.tr() : 'open'.tr()),
          Switch(
            key: Key('wh_closed_${day.day}'),
            value: closed,
            onChanged: widget.manageable
                ? (v) => setState(() => _closed[day.day] = v)
                : null,
          ),
          SizedBox(
            width: 72,
            child: TextField(
              key: Key('wh_open_${day.day}'),
              controller: _open[day.day],
              enabled: widget.manageable && !closed,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: TextField(
              key: Key('wh_close_${day.day}'),
              controller: _close[day.day],
              enabled: widget.manageable && !closed,
            ),
          ),
        ],
      ),
    );
  }

  void saveHours() {
    for (final day in widget.loaded.days) {
      if (_closed[day.day] ?? day.isClosed) continue;
      final open = _open[day.day]?.text.trim() ?? '';
      final close = _close[day.day]?.text.trim() ?? '';
      if (!_timePattern.hasMatch(open) || !_timePattern.hasMatch(close)) {
        setState(() {
          _hoursError = context.locale.languageCode == 'ar'
              ? 'استخدم صيغة HH:mm (00:00–23:59)'
              : 'Use HH:mm format (00:00–23:59)';
        });
        return;
      }
    }
    setState(() => _hoursError = null);
    widget.onSaveHours([
      for (final day in widget.loaded.days)
        WorkingDayEntry(
          day: day.day,
          openTime: _open[day.day]?.text.trim() ?? day.openTime,
          closeTime: _close[day.day]?.text.trim() ?? day.closeTime,
          isClosed: _closed[day.day] ?? day.isClosed,
        ),
    ]);
  }

  void saveSettings() {
    final slot = int.tryParse(_slot.text.trim());
    final advance = int.tryParse(_advance.text.trim());
    if (slot == null || slot <= 0 || advance == null || advance < 0) {
      setState(() {
        _rsError = context.locale.languageCode == 'ar'
            ? 'أدخل أرقاماً صحيحة'
            : 'Enter valid numbers';
      });
      return;
    }
    setState(() => _rsError = null);
    widget.onSaveSettings(ReservationSettings(
      slotDurationMinutes: slot,
      specialMenuAvailable: _special,
      needsAdvanceNotice: _notice,
      minAdvanceNoticeDays: advance,
    ));
  }
}
