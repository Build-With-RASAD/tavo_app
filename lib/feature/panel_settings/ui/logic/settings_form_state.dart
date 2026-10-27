// lib/feature/panel_settings/ui/logic/settings_form_state.dart
//
// Editing state for the settings screen's two forms.
//
// Both forms are view-local: they own text controllers, expose a `value` that
// is exactly what the cubit should save, and report one [SettingsIssue] when
// something is wrong. A Cubit would be the wrong tool here — there is no
// async work, no shared state and nothing to react to; the screen renders the
// form and the Cubit owns the network.
import 'package:flutter/widgets.dart';

import '../../data/model/settings_models.dart';

/// What is wrong with a form, mapped to a message by the screen so the
/// strings stay in the widget layer.
enum SettingsIssue {
  /// A time field is not `HH:mm`.
  hoursFormat,

  /// Closing time is not after opening time.
  hoursOrder,

  /// A number is missing, unparsable or out of range.
  numbers,

  /// Minimum party size exceeds the maximum.
  partyRange,

  /// A deposit is required but no amount is set.
  depositAmount,
}

/// The seven working-hour rows, with controller-backed time fields.
class WorkingHoursForm {
  WorkingHoursForm(List<WorkingDayEntry> initial) {
    final byDay = {for (final entry in initial) entry.day: entry};
    for (final day in kWeekDays) {
      // The backend may omit days; seed defaults so all seven rows render.
      _days[day] = byDay[day] ?? WorkingDayEntry(day: day);
      _open[day] = TextEditingController(text: _days[day]!.openTime);
      _close[day] = TextEditingController(text: _days[day]!.closeTime);
    }
  }

  final Map<String, WorkingDayEntry> _days = <String, WorkingDayEntry>{};
  final Map<String, TextEditingController> _open =
      <String, TextEditingController>{};
  final Map<String, TextEditingController> _close =
      <String, TextEditingController>{};

  TextEditingController openController(String day) => _open[day]!;
  TextEditingController closeController(String day) => _close[day]!;

  bool isClosed(String day) => _days[day]!.isClosed;

  WorkingDayEntry entry(String day) => _days[day]!.copyWith(
        openTime: _open[day]!.text.trim(),
        closeTime: _close[day]!.text.trim(),
      );

  /// Every day in week order, with the values currently on screen.
  List<WorkingDayEntry> get days =>
      <WorkingDayEntry>[for (final day in kWeekDays) entry(day)];

  int get openCount => kWeekDays.where((day) => !isClosed(day)).length;
  int get closedCount => kWeekDays.length - openCount;

  void setClosed(String day, bool value) {
    _days[day] = _days[day]!.copyWith(isClosed: value);
  }

  void setClosedAll(bool value) {
    for (final day in kWeekDays) {
      setClosed(day, value);
    }
  }

  void setTime(String day, {required bool open, required String value}) {
    final controller = (open ? _open[day] : _close[day])!;
    controller.text = value;
  }

  /// Copies the first open day's window onto every open day — the "we open at
  /// the same time all week" shortcut.
  void applyFirstOpenToAll() {
    WorkingDayEntry? source;
    for (final day in kWeekDays) {
      if (isClosed(day)) continue;
      source = entry(day);
      break;
    }
    if (source == null) return;
    for (final day in kWeekDays) {
      if (isClosed(day)) continue;
      setTime(day, open: true, value: source.openTime);
      setTime(day, open: false, value: source.closeTime);
    }
  }

  SettingsIssue? validate() {
    for (final day in kWeekDays) {
      if (isClosed(day)) continue;
      final row = entry(day);
      final open = WorkingDayEntry.minutesOf(row.openTime);
      final close = WorkingDayEntry.minutesOf(row.closeTime);
      if (open == null || close == null) return SettingsIssue.hoursFormat;
      if (close == open) return SettingsIssue.hoursOrder;
    }
    return null;
  }

  void dispose() {
    for (final controller in <TextEditingController>[
      ..._open.values,
      ..._close.values,
    ]) {
      controller.dispose();
    }
  }
}

/// The booking-rules form: reservation settings plus the celebration
/// packages, edited together because they are saved together.
class BookingRulesForm {
  BookingRulesForm(ReservationSettings initial)
      : _saved = initial,
        requireDeposit = initial.requireDeposit,
        birthday = initial.offersBirthdayPackage,
        anniversary = initial.offersAnniversaryPackage,
        specialMenu = initial.specialMenuAvailable,
        wantsAdvanceNotice = initial.needsAdvanceNotice,
        waitlist = initial.allowWaitlist,
        _slot = _int(initial.slotDurationMinutes),
        _maxDays = _int(initial.maxDaysInAdvance),
        _buffer = _int(initial.bufferTimeMinutes),
        _minParty = _int(initial.minPartySize),
        _maxParty = _int(initial.maxPartySize),
        _cancelWindow = _int(initial.cancellationWindowMinutes),
        _depositAmount = _money(initial.depositAmount),
        _depositThreshold = _int(initial.depositPartyThreshold),
        _noticeDays = _int(initial.minAdvanceNoticeDays);

  static TextEditingController _int(int value) =>
      TextEditingController(text: '$value');

  static TextEditingController _money(double value) => TextEditingController(
        text: value == value.roundToDouble()
            ? value.toInt().toString()
            : value.toString(),
      );

  final ReservationSettings _saved;

  final TextEditingController _slot;
  final TextEditingController _maxDays;
  final TextEditingController _buffer;
  final TextEditingController _minParty;
  final TextEditingController _maxParty;
  final TextEditingController _cancelWindow;
  final TextEditingController _depositAmount;
  final TextEditingController _depositThreshold;
  final TextEditingController _noticeDays;

  bool requireDeposit;
  bool birthday;
  bool anniversary;
  bool specialMenu;
  bool wantsAdvanceNotice;
  bool waitlist;

  TextEditingController get slot => _slot;
  TextEditingController get maxDays => _maxDays;
  TextEditingController get buffer => _buffer;
  TextEditingController get minParty => _minParty;
  TextEditingController get maxParty => _maxParty;
  TextEditingController get cancelWindow => _cancelWindow;
  TextEditingController get depositAmount => _depositAmount;
  TextEditingController get depositThreshold => _depositThreshold;
  TextEditingController get noticeDays => _noticeDays;

  bool get hasUnsavedChanges => value != _saved;

  /// What this screen would save. Unparsable numbers fall back to the saved
  /// value so a broken edit can never silently become a zero on the wire.
  ReservationSettings get value {
    final parsed = _parsed();
    return _saved.copyWith(
      slotDurationMinutes: parsed.slot ?? _saved.slotDurationMinutes,
      maxDaysInAdvance: parsed.maxDays ?? _saved.maxDaysInAdvance,
      bufferTimeMinutes: parsed.buffer ?? _saved.bufferTimeMinutes,
      minPartySize: parsed.minParty ?? _saved.minPartySize,
      maxPartySize: parsed.maxParty ?? _saved.maxPartySize,
      requireDeposit: requireDeposit,
      depositAmount: parsed.depositAmount ?? _saved.depositAmount,
      depositPartyThreshold:
          parsed.depositThreshold ?? _saved.depositPartyThreshold,
      allowWaitlist: waitlist,
      cancellationWindowMinutes:
          parsed.cancelWindow ?? _saved.cancellationWindowMinutes,
      offersBirthdayPackage: birthday,
      offersAnniversaryPackage: anniversary,
      specialMenuAvailable: specialMenu,
      needsAdvanceNotice: wantsAdvanceNotice,
      minAdvanceNoticeDays: parsed.noticeDays ?? _saved.minAdvanceNoticeDays,
    );
  }

  _ParsedRules _parsed() => _ParsedRules(
        slot: int.tryParse(_slot.text.trim()),
        maxDays: int.tryParse(_maxDays.text.trim()),
        buffer: int.tryParse(_buffer.text.trim()),
        minParty: int.tryParse(_minParty.text.trim()),
        maxParty: int.tryParse(_maxParty.text.trim()),
        cancelWindow: int.tryParse(_cancelWindow.text.trim()),
        depositAmount: double.tryParse(_depositAmount.text.trim()),
        depositThreshold: int.tryParse(_depositThreshold.text.trim()),
        noticeDays: int.tryParse(_noticeDays.text.trim()),
      );

  SettingsIssue? validate() {
    final rules = _parsed();
    final slot = rules.slot;
    if (slot == null ||
        slot < SettingsLimits.slotMinMinutes ||
        slot > SettingsLimits.slotMaxMinutes) {
      return SettingsIssue.numbers;
    }
    final maxDays = rules.maxDays;
    if (maxDays == null ||
        maxDays < SettingsLimits.maxDaysMin ||
        maxDays > SettingsLimits.maxDaysMax) {
      return SettingsIssue.numbers;
    }
    final buffer = rules.buffer;
    if (buffer == null ||
        buffer < 0 ||
        buffer > SettingsLimits.bufferMaxMinutes) {
      return SettingsIssue.numbers;
    }
    final minParty = rules.minParty;
    final maxParty = rules.maxParty;
    if (minParty == null ||
        maxParty == null ||
        minParty < SettingsLimits.partyMin ||
        maxParty > SettingsLimits.partyMax) {
      return SettingsIssue.numbers;
    }
    if (minParty > maxParty) return SettingsIssue.partyRange;
    final cancelWindow = rules.cancelWindow;
    if (cancelWindow == null ||
        cancelWindow < 0 ||
        cancelWindow > SettingsLimits.cancelMaxMinutes) {
      return SettingsIssue.numbers;
    }
    if (requireDeposit) {
      final amount = rules.depositAmount;
      final threshold = rules.depositThreshold;
      if (amount == null ||
          amount <= 0 ||
          amount > SettingsLimits.depositMax ||
          threshold == null ||
          threshold < SettingsLimits.partyMin ||
          threshold > SettingsLimits.partyMax) {
        return SettingsIssue.depositAmount;
      }
    }
    if (wantsAdvanceNotice) {
      final notice = rules.noticeDays;
      if (notice == null ||
          notice < 0 ||
          notice > SettingsLimits.noticeMaxDays) {
        return SettingsIssue.numbers;
      }
    }
    return null;
  }

  void dispose() {
    for (final controller in <TextEditingController>[
      _slot,
      _maxDays,
      _buffer,
      _minParty,
      _maxParty,
      _cancelWindow,
      _depositAmount,
      _depositThreshold,
      _noticeDays,
    ]) {
      controller.dispose();
    }
  }
}

class _ParsedRules {
  const _ParsedRules({
    this.slot,
    this.maxDays,
    this.buffer,
    this.minParty,
    this.maxParty,
    this.cancelWindow,
    this.depositAmount,
    this.depositThreshold,
    this.noticeDays,
  });

  final int? slot;
  final int? maxDays;
  final int? buffer;
  final int? minParty;
  final int? maxParty;
  final int? cancelWindow;
  final double? depositAmount;
  final int? depositThreshold;
  final int? noticeDays;
}
