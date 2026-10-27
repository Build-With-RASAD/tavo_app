// lib/feature/panel_settings/ui/widgets/settings_sections.dart
//
// The settings screen's sections: venue strip, jump rail, working hours,
// booking rules, occasion packages and the next-seven-days preview.
//
// Every figure on this screen is derived from what the API returned or from
// what is typed on the screen right now — the preview says so in its own
// subtitle so nobody mistakes it for live availability.
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_settings/data/model/settings_models.dart';
import 'package:tavo/feature/panel_settings/ui/logic/settings_form_state.dart';
import 'package:tavo/feature/panel_settings/ui/widgets/settings_controls.dart';

/// Section anchors the jump rail scrolls to.
enum SettingsSection { hours, rules, occasions, preview }

const Map<SettingsSection, String> kSettingsSectionKeys = <SettingsSection, String>{
  SettingsSection.hours: 'settings_jump_hours',
  SettingsSection.rules: 'settings_jump_rules',
  SettingsSection.occasions: 'settings_jump_occasions',
  SettingsSection.preview: 'settings_jump_preview',
};

const Map<SettingsSection, IconData> kSettingsSectionIcons = <SettingsSection, IconData>{
  SettingsSection.hours: Iconsax.clock,
  SettingsSection.rules: Iconsax.calendar_1,
  SettingsSection.occasions: Iconsax.cake,
  SettingsSection.preview: Iconsax.eye,
};

/// Who this venue is, at a glance — name, role and status only. The figures
/// live in the preview section, where they read as an outcome.
class SettingsVenueStrip extends StatelessWidget {
  const SettingsVenueStrip({
    super.key,
    required this.venue,
    required this.viewOnly,
    required this.unsaved,
  });

  final StaffRestaurant venue;
  final bool viewOnly;
  final bool unsaved;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final name = venue.displayName(locale);
    return TavoCard(
      variant: TavoCardVariant.warm,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const TavoIconTile(icon: Icon(Iconsax.setting_2, size: 22), size: 44),
          const SizedBox(width: TavoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  name.isEmpty ? 'settings'.tr() : name,
                  style: TavoType.title.copyWith(color: TavoColors.foreground),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'settings_subtitle'.tr(),
                  style: TavoType.caption
                      .copyWith(color: TavoColors.mutedForeground),
                  maxLines: 2,
                ),
                const SizedBox(height: TavoSpace.sm),
                Wrap(
                  spacing: TavoSpace.xs,
                  runSpacing: TavoSpace.xs,
                  children: <Widget>[
                    if (venue.role.isNotEmpty)
                      TavoStatusPill(
                        label: _roleLabel(venue.role),
                        tone: TavoTone.info,
                        size: TavoPillSize.small,
                      ),
                    if (venue.status.isNotEmpty)
                      TavoStatusPill(
                        label: venue.status == 'active'
                            ? 'active'.tr()
                            : 'inactive'.tr(),
                        tone: venue.status == 'active'
                            ? TavoTone.success
                            : TavoTone.neutral,
                        size: TavoPillSize.small,
                      ),
                    // The state pill is about this screen's work, not the
                    // venue: read-only when the user cannot save at all.
                    TavoStatusPill(
                      label: viewOnly
                          ? 'settings_view_only'.tr()
                          : (unsaved
                                  ? 'settings_unsaved'
                                  : 'settings_saved_now')
                              .tr(),
                      tone: viewOnly
                          ? TavoTone.neutral
                          : (unsaved ? TavoTone.warning : TavoTone.success),
                      size: TavoPillSize.small,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _roleLabel(String role) => switch (role) {
        'owner' => '${'manager'.tr()} · ${'active'.tr()}',
        'manager' => 'manager'.tr(),
        _ => 'staff'.tr(),
      };
}

/// Chips that scroll the page to a section.
class SettingsJumpRail extends StatelessWidget {
  const SettingsJumpRail({super.key, required this.onJump});

  final void Function(SettingsSection section) onJump;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TavoSpace.sm,
      runSpacing: TavoSpace.sm,
      children: <Widget>[
        for (final section in SettingsSection.values)
          TavoChip(
            key: Key('jump_${section.name}'),
            label: kSettingsSectionKeys[section]!.tr(),
            leading: Icon(kSettingsSectionIcons[section], size: 16),
            onTap: () => onJump(section),
          ),
      ],
    );
  }
}

/// Working hours: one row per day, closed days off, plus bulk shortcuts.
class WorkingHoursSection extends StatelessWidget {
  const WorkingHoursSection({
    super.key,
    required this.form,
    required this.enabled,
    required this.dirty,
    required this.issue,
    required this.onChanged,
  });

  final WorkingHoursForm form;
  final bool enabled;
  final bool dirty;
  final SettingsIssue? issue;
  final VoidCallback onChanged;

  String get _summary => '${form.openCount} ${'open'.tr()} · '
      '${form.closedCount} ${'closed'.tr()}';

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'working_hours'.tr(),
      subtitle: 'settings_hours_subtitle'.tr(),
      dirty: dirty,
      action: Text(
        _summary,
        style: TavoType.caption.copyWith(color: TavoColors.mutedForeground),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _bulkActions(),
          const SizedBox(height: TavoSpace.sm),
          for (final day in kWeekDays) ...<Widget>[
            _DayRow(
              day: day,
              form: form,
              enabled: enabled,
              onChanged: onChanged,
            ),
            if (day != kWeekDays.last)
              const Divider(height: 1, color: TavoColors.border),
          ],
          if (issue != null)
            SettingsInlineError(message: _issueMessage(issue!)),
        ],
      ),
    );
  }

  Widget _bulkActions() {
    if (!enabled) return const SizedBox.shrink();
    return Wrap(
      spacing: TavoSpace.sm,
      runSpacing: TavoSpace.sm,
      children: <Widget>[
        TavoButton.secondary(
          key: const Key('hours_copy_all'),
          label: 'settings_copy_to_all'.tr(),
          size: TavoButtonSize.compact,
          leading: const Icon(Iconsax.copy, size: 14),
          onPressed: () {
            form.applyFirstOpenToAll();
            onChanged();
          },
        ),
        TavoButton.ghost(
          key: const Key('hours_open_all'),
          label: 'settings_open_all'.tr(),
          size: TavoButtonSize.compact,
          onPressed: () {
            form.setClosedAll(false);
            onChanged();
          },
        ),
        TavoButton.ghost(
          key: const Key('hours_close_all'),
          label: 'settings_close_all'.tr(),
          size: TavoButtonSize.compact,
          onPressed: () {
            form.setClosedAll(true);
            onChanged();
          },
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.form,
    required this.enabled,
    required this.onChanged,
  });

  final String day;
  final WorkingHoursForm form;
  final bool enabled;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final closed = form.isClosed(day);
    final fieldsEnabled = enabled && !closed;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TavoSpace.sm),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'settings_day_$day'.tr(),
                  style: TavoType.body.copyWith(color: TavoColors.foreground),
                ),
                const SizedBox(height: 2),
                Text(
                  closed ? 'closed'.tr() : 'open'.tr(),
                  style: TavoType.caption
                      .copyWith(color: TavoColors.mutedForeground),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 78,
            child: SettingsTimeField(
              key: Key('wh_open_$day'),
              controller: form.openController(day),
              label: 'open'.tr(),
              enabled: fieldsEnabled,
              onChanged: onChanged,
              pickSemanticLabel: 'settings_pick_time'.tr(),
              onPick: () => _pick(context, open: true),
            ),
          ),
          const SizedBox(width: TavoSpace.sm),
          SizedBox(
            width: 78,
            child: SettingsTimeField(
              key: Key('wh_close_$day'),
              controller: form.closeController(day),
              label: 'closed'.tr(),
              enabled: fieldsEnabled,
              onChanged: onChanged,
              pickSemanticLabel: 'settings_pick_time'.tr(),
              onPick: () => _pick(context, open: false),
            ),
          ),
          const SizedBox(width: TavoSpace.sm),
          _ClosedToggle(
            key: Key('wh_closed_$day'),
            value: closed,
            enabled: enabled,
            semanticLabel: closed
                ? '${'settings_day_$day'.tr()} · ${'closed'.tr()}'
                : '${'settings_day_$day'.tr()} · ${'open'.tr()}',
            onChanged: (value) {
              form.setClosed(day, value);
              onChanged();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _pick(BuildContext context, {required bool open}) async {
    final controller =
        open ? form.openController(day) : form.closeController(day);
    final current = WorkingDayEntry.minutesOf(controller.text) ?? 9 * 60;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
      // The field is 24-hour, so the dialog is forced to match instead of
      // following the device's 12/24-hour setting.
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked == null) return;
    form.setTime(
      day,
      open: open,
      value: '${picked.hour.toString().padLeft(2, '0')}:'
          '${picked.minute.toString().padLeft(2, '0')}',
    );
    onChanged();
  }
}

class _ClosedToggle extends StatelessWidget {
  const _ClosedToggle({
    super.key,
    required this.value,
    required this.enabled,
    required this.semanticLabel,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final String semanticLabel;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      toggled: value,
      enabled: enabled,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 52,
          height: TavoSpace.minTouchTarget,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? () => onChanged(!value) : null,
            child: Center(
              child: AnimatedContainer(
                duration: TavoMotion.fast,
                curve: TavoMotion.out,
                width: 46,
                height: 26,
                padding: const EdgeInsets.all(3),
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                decoration: BoxDecoration(
                  color: value ? TavoColors.grayBgLight : TavoColors.primary,
                  borderRadius: BorderRadius.circular(TavoRadii.pill),
                  border: Border.all(
                    color: value ? TavoColors.border : TavoColors.primary,
                  ),
                ),
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: TavoColors.background,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Booking rules: the ten reservation fields, in a responsive grid.
class ReservationRulesSection extends StatelessWidget {
  const ReservationRulesSection({
    super.key,
    required this.form,
    required this.enabled,
    required this.dirty,
    required this.issue,
    required this.onChanged,
  });

  final BookingRulesForm form;
  final bool enabled;
  final bool dirty;
  final SettingsIssue? issue;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'reservation_settings'.tr(),
      subtitle: 'settings_rules_subtitle'.tr(),
      dirty: dirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _grid(
            context,
            <Widget>[
              SettingsNumberField(
                key: const Key('rs_slot'),
                controller: form.slot,
                label: 'slot_minutes'.tr(),
                enabled: enabled,
                onChanged: onChanged,
              ),
              SettingsNumberField(
                key: const Key('rs_max_days'),
                controller: form.maxDays,
                label: 'settings_max_days'.tr(),
                enabled: enabled,
                onChanged: onChanged,
              ),
              SettingsNumberField(
                key: const Key('rs_buffer'),
                controller: form.buffer,
                label: 'settings_buffer'.tr(),
                enabled: enabled,
                onChanged: onChanged,
              ),
              SettingsNumberField(
                key: const Key('rs_min_party'),
                controller: form.minParty,
                label: 'settings_min_party'.tr(),
                enabled: enabled,
                onChanged: onChanged,
              ),
              SettingsNumberField(
                key: const Key('rs_max_party'),
                controller: form.maxParty,
                label: 'settings_max_party'.tr(),
                enabled: enabled,
                onChanged: onChanged,
              ),
              SettingsNumberField(
                key: const Key('rs_cancel_window'),
                controller: form.cancelWindow,
                label: 'settings_cancel_window'.tr(),
                enabled: enabled,
                onChanged: onChanged,
              ),
            ],
          ),
          const SizedBox(height: TavoSpace.md),
          const Divider(height: 1, color: TavoColors.border),
          SettingsToggleRow(
            key: const Key('rs_require_deposit'),
            label: 'settings_require_deposit'.tr(),
            subtitle: 'settings_deposit_hint'.tr(),
            icon: Iconsax.card,
            value: form.requireDeposit,
            onChanged: enabled
                ? (value) {
                    form.requireDeposit = value;
                    onChanged();
                  }
                : null,
          ),
          TavoAnimatedSwitcher(
            child: form.requireDeposit
                ? _grid(
                    context,
                    <Widget>[
                      SettingsNumberField(
                        key: const Key('rs_deposit_amount'),
                        controller: form.depositAmount,
                        label: 'settings_deposit_amount'.tr(),
                        enabled: enabled,
                        decimal: true,
                        onChanged: onChanged,
                      ),
                      SettingsNumberField(
                        key: const Key('rs_deposit_threshold'),
                        controller: form.depositThreshold,
                        label: 'settings_deposit_threshold'.tr(),
                        enabled: enabled,
                        onChanged: onChanged,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          const Divider(height: 1, color: TavoColors.border),
          SettingsToggleRow(
            key: const Key('rs_waitlist'),
            label: 'settings_waitlist'.tr(),
            icon: Iconsax.people,
            value: form.waitlist,
            onChanged: enabled
                ? (value) {
                    form.waitlist = value;
                    onChanged();
                  }
                : null,
          ),
          if (issue != null)
            SettingsInlineError(message: _issueMessage(issue!)),
        ],
      ),
    );
  }
}

/// Occasion packages — the half of the booking rules that used to be edited
/// on screen but never left it.
class OccasionsSection extends StatelessWidget {
  const OccasionsSection({
    super.key,
    required this.form,
    required this.enabled,
    required this.dirty,
    required this.onChanged,
  });

  final BookingRulesForm form;
  final bool enabled;
  final bool dirty;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsSectionCard(
      title: 'settings_jump_occasions'.tr(),
      subtitle: 'settings_occasions_subtitle'.tr(),
      dirty: dirty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SettingsToggleRow(
            key: const Key('cf_birthday'),
            label: 'settings_birthday'.tr(),
            icon: Iconsax.cake,
            value: form.birthday,
            onChanged: enabled
                ? (value) {
                    form.birthday = value;
                    onChanged();
                  }
                : null,
          ),
          SettingsToggleRow(
            key: const Key('cf_anniversary'),
            label: 'settings_anniversary'.tr(),
            icon: Iconsax.gift,
            value: form.anniversary,
            onChanged: enabled
                ? (value) {
                    form.anniversary = value;
                    onChanged();
                  }
                : null,
          ),
          SettingsToggleRow(
            key: const Key('rs_special'),
            label: 'special_menu'.tr(),
            icon: Iconsax.menu_board,
            value: form.specialMenu,
            onChanged: enabled
                ? (value) {
                    form.specialMenu = value;
                    onChanged();
                  }
                : null,
          ),
          const Divider(height: 1, color: TavoColors.border),
          SettingsToggleRow(
            key: const Key('rs_notice'),
            label: 'advance_notice'.tr(),
            icon: Iconsax.timer_1,
            value: form.wantsAdvanceNotice,
            onChanged: enabled
                ? (value) {
                    form.wantsAdvanceNotice = value;
                    onChanged();
                  }
                : null,
          ),
          TavoAnimatedSwitcher(
            child: form.wantsAdvanceNotice
                ? _grid(
                    context,
                    <Widget>[
                      SettingsNumberField(
                        key: const Key('rs_advance'),
                        controller: form.noticeDays,
                        label: 'advance_days'.tr(),
                        enabled: enabled,
                        onChanged: onChanged,
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

/// What the current values produce: three figures and the next seven days.
class AvailabilityPreviewSection extends StatelessWidget {
  const AvailabilityPreviewSection({
    super.key,
    required this.form,
    required this.rules,
    required this.today,
  });

  final WorkingHoursForm form;
  final BookingRulesForm rules;

  /// Anchor for "today": the preview always starts on the day the screen
  /// loaded, so it does not drift while the user edits.
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final settings = rules.value;
    return SettingsSectionCard(
      title: 'settings_jump_preview'.tr(),
      subtitle: 'settings_preview_subtitle'.tr(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TavoStatTile(
                  label: 'settings_kpi_days_open'.tr(),
                  value: form.openCount,
                  suffix: '/${kWeekDays.length}',
                ),
              ),
              const SizedBox(width: TavoSpace.sm),
              Expanded(
                child: TavoStatTile(
                  label: 'settings_kpi_slot'.tr(),
                  value: settings.slotDurationMinutes,
                  suffix: 'm',
                ),
              ),
              const SizedBox(width: TavoSpace.sm),
              Expanded(
                child: TavoStatTile(
                  label: 'settings_kpi_max_party'.tr(),
                  value: settings.maxPartySize,
                ),
              ),
            ],
          ),
          const SizedBox(height: TavoSpace.md),
          Wrap(
            spacing: TavoSpace.xs,
            runSpacing: TavoSpace.xs,
            children: <Widget>[
              TavoStatusPill(
                label: 'settings_pill_deposit'.tr(),
                tone: settings.requireDeposit
                    ? TavoTone.brand
                    : TavoTone.neutral,
                size: TavoPillSize.small,
              ),
              TavoStatusPill(
                label:
                    '${'settings_pill_waitlist'.tr()} · ${(settings.allowWaitlist ? 'settings_on' : 'settings_off').tr()}',
                tone: settings.allowWaitlist
                    ? TavoTone.success
                    : TavoTone.neutral,
                size: TavoPillSize.small,
              ),
              TavoStatusPill(
                label:
                    '${'settings_pill_occasions'.tr()} · ${(settings.hasOccasionPackages ? 'settings_on' : 'settings_off').tr()}',
                tone: settings.hasOccasionPackages
                    ? TavoTone.brand
                    : TavoTone.neutral,
                size: TavoPillSize.small,
              ),
            ],
          ),
          const SizedBox(height: TavoSpace.md),
          for (final row in _nextSevenDays(settings)) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: TavoSpace.xs),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'settings_day_${row.day}'.tr(),
                      style: TavoType.bodySmall
                          .copyWith(color: TavoColors.foreground),
                    ),
                  ),
                  Text(
                    row.closed
                        ? 'closed'.tr()
                        : '${row.slots} ${'settings_preview_slots'.tr()}',
                    style: TavoType.caption.copyWith(
                      color: row.closed
                          ? TavoColors.mutedForeground
                          : TavoColors.foreground,
                      fontFeatures: TavoType.tabular,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Today plus the next six days, each mapped to a weekday row of the form.
  List<({String day, bool closed, int slots})> _nextSevenDays(
    ReservationSettings settings,
  ) {
    final week = form.days;
    final anchor = DateTime(today.year, today.month, today.day);
    return <({String day, bool closed, int slots})>[
      for (var offset = 0; offset < 7; offset += 1)
        () {
          // DateTime.weekday is 1 = Monday; kWeekDays starts at Sunday.
          final weekday = anchor.add(Duration(days: offset)).weekday % 7;
          final entry = week[weekday];
          final openMinutes = entry.openMinutes;
          final slot = settings.slotDurationMinutes;
          final slots = (openMinutes == null || slot <= 0)
              ? 0
              : (openMinutes / slot).floor();
          return (
            day: entry.day,
            closed: entry.isClosed || slots == 0,
            slots: slots,
          );
        }(),
    ];
  }
}

/// Lays fields out in 1, 2 or 3 columns depending on the width available.
Widget _grid(BuildContext context, List<Widget> children) {
  return LayoutBuilder(
    builder: (context, constraints) {
      final columns = constraints.maxWidth >= 520
          ? 3
          : (constraints.maxWidth >= 340 ? 2 : 1);
      final gap = TavoSpace.md;
      final width =
          (constraints.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: <Widget>[
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

String _issueMessage(SettingsIssue issue) => switch (issue) {
      SettingsIssue.hoursFormat => 'settings_hours_invalid'.tr(),
      SettingsIssue.hoursOrder => 'settings_hours_order_invalid'.tr(),
      SettingsIssue.numbers => 'settings_numbers_invalid'.tr(),
      SettingsIssue.partyRange => 'settings_party_range_invalid'.tr(),
      SettingsIssue.depositAmount => 'settings_deposit_amount_invalid'.tr(),
    };
