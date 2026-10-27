// lib/feature/panel_settings/ui/screens/panel_settings_screen.dart
//
// Staff panel settings: the control room for how this venue runs — working
// hours, booking rules, occasion packages, and a preview of what the current
// values produce.
//
// Visual language is the panel's website kit (`core/ui/tavo_web`): the same
// gold, hairlines and pill geometry as Tables, Menu, Orders and Feedback.
//
// Behaviour notes that matter:
//   * Booking rules span TWO backend sub-documents — `reservationSettings`
//     (ten fields) and `celebrationFeatures` (five). The screen edits them as
//     one form and the repo emits both halves in one request, because
//     `PUT /settings` replaces the reservation object wholesale.
//   * Every field is optional at the API, but this screen always sends the
//     full object, so a save can never silently reset a field it did not show.
//   * [canManage] gates editing; view-only staff see the same values with no
//     save bar and no writable fields.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_settings/data/model/settings_models.dart';
import 'package:tavo/feature/panel_settings/data/repo/settings_panel_repo.dart';
import 'package:tavo/feature/panel_settings/ui/logic/settings_form_state.dart';
import 'package:tavo/feature/panel_settings/ui/logic/settings_panel_cubit.dart';
import 'package:tavo/feature/panel_settings/ui/widgets/settings_sections.dart';

/// Staff panel settings.
///
/// Builds its own [SettingsPanelCubit] through get_it (mirroring
/// `PanelMenuScreen`, `OrdersScreen` and the rest of the panel) and drives the
/// three async states with [ListSkeleton] / [ErrorStateView] / content.
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

  /// Mirrored from the form so the pinned save bar (a Scaffold sibling, not a
  /// child of the form) can enable itself. The form stays the one source of
  /// truth; this is only a repaint signal.
  bool _hoursDirty = false;
  bool _settingsDirty = false;

  /// Falls back to the venue's own role/permissions when the shell does not
  /// inject a gate, so the screen is usable from a widget test and from the
  /// hub alike.
  void _setDirty({required bool hours, required bool settings}) {
    if (!mounted) return;
    if (_hoursDirty == hours && _settingsDirty == settings) return;
    setState(() {
      _hoursDirty = hours;
      _settingsDirty = settings;
    });
  }

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
          if (state is SettingsPanelLoading || state is SettingsPanelInitial) {
            _setDirty(hours: false, settings: false);
          }
          if (state is SettingsPanelLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: TavoColors.danger,
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
            // Pinned actions: the form is taller than any phone, so both saves
            // live in a fixed bar instead of at the end of the scroll (widget
            // tests tap them without scrolling, and so does a thumb).
            bottomNavigationBar: (loaded != null && manageable)
                ? _SaveBar(
                    loaded: loaded,
                    onSaveHours: () => _formKey.currentState?.saveHours(),
                    onSaveSettings: () =>
                        _formKey.currentState?.saveSettings(),
                    hoursDirty: _hoursDirty,
                    settingsDirty: _settingsDirty,
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
        children: <Widget>[
          Expanded(
            child: ErrorStateView(message: state.message, onRetry: cubit.load),
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: cubit.load),
          const SizedBox(height: TavoSpace.sm),
        ],
      );
    }
    if (state is SettingsPanelLoaded) {
      return _LoadedForm(
        key: _formKey,
        loaded: state,
        manageable: _manage(),
        venue: widget.venue,
        onSaveHours: cubit.saveWorkingHours,
        onSaveSettings: cubit.saveReservationSettings,
        onDirtyChanged: (hours, settings) =>
            _setDirty(hours: hours, settings: settings),
      );
    }
    // SettingsPanelInitial / SettingsPanelLoading.
    return const ListSkeleton();
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.loaded,
    required this.onSaveHours,
    required this.onSaveSettings,
    required this.hoursDirty,
    required this.settingsDirty,
  });

  final SettingsPanelLoaded loaded;
  final VoidCallback onSaveHours;
  final VoidCallback onSaveSettings;
  final bool hoursDirty;
  final bool settingsDirty;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: TavoColors.background,
        border: Border(top: BorderSide(color: TavoColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            TavoSpace.lg,
            TavoSpace.sm,
            TavoSpace.lg,
            TavoSpace.md,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: TavoButton.secondary(
                  key: const Key('save_hours'),
                  label: 'save_hours'.tr(),
                  isLoading: loaded.saving,
                  expand: true,
                  onPressed: (loaded.saving || !hoursDirty) ? null : onSaveHours,
                ),
              ),
              const SizedBox(width: TavoSpace.md),
              Expanded(
                child: TavoButton.primary(
                  key: const Key('save_settings'),
                  label: 'save_settings'.tr(),
                  isLoading: loaded.saving,
                  expand: true,
                  onPressed:
                      (loaded.saving || !settingsDirty) ? null : onSaveSettings,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadedForm extends StatefulWidget {
  const _LoadedForm({
    super.key,
    required this.loaded,
    required this.manageable,
    required this.venue,
    required this.onSaveHours,
    required this.onSaveSettings,
    required this.onDirtyChanged,
  });

  final SettingsPanelLoaded loaded;
  final bool manageable;
  final StaffRestaurant venue;
  final Future<void> Function(List<WorkingDayEntry> days) onSaveHours;
  final Future<void> Function(ReservationSettings rs) onSaveSettings;

  /// Reports the two dirty flags after every edit, so the save bar and the
  /// venue strip can show the state without owning it.
  final void Function(bool hours, bool settings) onDirtyChanged;

  @override
  State<_LoadedForm> createState() => _LoadedFormState();
}

class _LoadedFormState extends State<_LoadedForm> {
  late final WorkingHoursForm _hours = WorkingHoursForm(widget.loaded.days);
  late final BookingRulesForm _rules =
      BookingRulesForm(widget.loaded.rs);

  final ScrollController _scroll = ScrollController();
  final Map<SettingsSection, GlobalKey> _anchors = <SettingsSection, GlobalKey>{
    for (final section in SettingsSection.values) section: GlobalKey(),
  };

  /// The preview is anchored to the day the screen opened so it does not
  /// drift while the user edits.
  final DateTime _today = DateTime.now();

  SettingsIssue? _hoursIssue;
  SettingsIssue? _rulesIssue;

  bool get hoursDirty => !_sameDays(_hours.days, widget.loaded.days);
  bool get settingsDirty => _rules.hasUnsavedChanges;

  static bool _sameDays(List<WorkingDayEntry> a, List<WorkingDayEntry> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i += 1) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  void dispose() {
    _hours.dispose();
    _rules.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _touch() {
    setState(() {});
    widget.onDirtyChanged(hoursDirty, settingsDirty);
  }

  void _jump(SettingsSection section) {
    final context = _anchors[section]?.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: TavoMotion.slow,
      curve: TavoMotion.out,
      alignment: 0.05,
    );
  }

  void saveHours() {
    final issue = _hours.validate();
    setState(() => _hoursIssue = issue);
    if (issue != null) {
      _jump(SettingsSection.hours);
      return;
    }
    widget.onSaveHours(_hours.days);
  }

  void saveSettings() {
    final issue = _rules.validate();
    setState(() => _rulesIssue = issue);
    if (issue != null) {
      _jump(SettingsSection.rules);
      return;
    }
    widget.onSaveSettings(_rules.value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.manageable;
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final hours = WorkingHoursSection(
          key: _anchors[SettingsSection.hours],
          form: _hours,
          enabled: enabled,
          dirty: hoursDirty,
          issue: _hoursIssue,
          onChanged: _touch,
        );
        final rules = ReservationRulesSection(
          key: _anchors[SettingsSection.rules],
          form: _rules,
          enabled: enabled,
          dirty: settingsDirty,
          issue: _rulesIssue,
          onChanged: _touch,
        );
        final occasions = OccasionsSection(
          key: _anchors[SettingsSection.occasions],
          form: _rules,
          enabled: enabled,
          dirty: settingsDirty,
          onChanged: _touch,
        );
        final preview = AvailabilityPreviewSection(
          key: _anchors[SettingsSection.preview],
          form: _hours,
          rules: _rules,
          today: _today,
        );

        return SingleChildScrollView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(
            TavoSpace.lg,
            TavoSpace.lg,
            TavoSpace.lg,
            TavoSpace.huge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SettingsVenueStrip(
                venue: widget.venue,
                viewOnly: !enabled,
                unsaved: hoursDirty || settingsDirty,
              ),
              const SizedBox(height: TavoSpace.md),
              SettingsJumpRail(onJump: _jump),
              const SizedBox(height: TavoSpace.lg),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      child: Column(children: <Widget>[hours]),
                    ),
                    const SizedBox(width: TavoSpace.lg),
                    Expanded(
                      child: Column(
                        children: <Widget>[
                          rules,
                          const SizedBox(height: TavoSpace.lg),
                          occasions,
                        ],
                      ),
                    ),
                  ],
                )
              else ...<Widget>[
                hours,
                const SizedBox(height: TavoSpace.lg),
                rules,
                const SizedBox(height: TavoSpace.lg),
                occasions,
              ],
              const SizedBox(height: TavoSpace.lg),
              preview,
            ],
          ),
        );
      },
    );
  }
}
