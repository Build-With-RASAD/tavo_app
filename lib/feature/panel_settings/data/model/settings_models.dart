// lib/feature/panel_settings/data/model/settings_models.dart
//
// The settings screen's data. Two shapes live here:
//
//   * `WorkingDayEntry` — one row of `restaurant.workingHours`.
//   * `ReservationSettings` — the whole *booking rules* form.
//
// The backend splits booking rules across two sub-documents:
// `reservation.reservationSettings` (ten fields) and
// `restaurant.celebrationFeatures` (five fields). `PUT /settings` REPLACES
// the reservation object wholesale, so the form must always send all ten —
// a partial body silently resets the rest to their schema defaults. Keeping
// both halves in one model is what makes that hard to get wrong: the repo
// takes this object and emits both JSON halves together.

/// Day order mirrors updateSettingsValidation (sunday..saturday).
const kWeekDays = <String>[
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

/// Accepted ranges for the booking-rules fields. The form validates against
/// these before saving, so a typo is caught next to the field that caused it
/// instead of coming back as a server error.
abstract final class SettingsLimits {
  static const int slotMinMinutes = 15;
  static const int slotMaxMinutes = 240;
  static const int maxDaysMin = 1;
  static const int maxDaysMax = 90;
  static const int bufferMaxMinutes = 120;
  static const int partyMin = 1;
  static const int partyMax = 50;
  static const int cancelMaxMinutes = 1440;
  static const double depositMax = 100000;
  static const int noticeMaxDays = 60;
}

class WorkingDayEntry {
  const WorkingDayEntry(
      {required this.day,
      this.openTime = '09:00',
      this.closeTime = '23:00',
      this.isClosed = false});

  final String day;
  final String openTime;
  final String closeTime;
  final bool isClosed;

  factory WorkingDayEntry.fromJson(Map<String, dynamic> json) =>
      WorkingDayEntry(
        day: json['day'] as String? ?? 'sunday',
        openTime: json['openTime'] as String? ?? '09:00',
        closeTime: json['closeTime'] as String? ?? '23:00',
        isClosed: json['isClosed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'day': day,
        'openTime': openTime,
        'closeTime': closeTime,
        'isClosed': isClosed,
      };

  WorkingDayEntry copyWith({String? openTime, String? closeTime, bool? isClosed}) =>
      WorkingDayEntry(
        day: day,
        openTime: openTime ?? this.openTime,
        closeTime: closeTime ?? this.closeTime,
        isClosed: isClosed ?? this.isClosed,
      );

  /// Minutes since midnight for [openTime] / [closeTime]; `null` when the
  /// text is not a 24-hour `HH:mm` value. A close time past midnight
  /// (`22:00` → `02:00`) is reported as-is and handled by the caller.
  static int? minutesOf(String raw) {
    final match = RegExp(r'^([01][0-9]|2[0-3]):([0-5][0-9])$').firstMatch(
      raw.trim(),
    );
    if (match == null) return null;
    return int.parse(match.group(1)!) * 60 + int.parse(match.group(2)!);
  }

  /// Length of the opening window in minutes, or `null` when unknown/closed.
  int? get openMinutes {
    if (isClosed) return 0;
    final open = minutesOf(openTime);
    final close = minutesOf(closeTime);
    if (open == null || close == null) return null;
    return close >= open ? close - open : (24 * 60 - open) + close;
  }

  @override
  bool operator ==(Object other) =>
      other is WorkingDayEntry &&
      other.day == day &&
      other.openTime == openTime &&
      other.closeTime == closeTime &&
      other.isClosed == isClosed;

  @override
  int get hashCode => Object.hash(day, openTime, closeTime, isClosed);
}

class ReservationSettings {
  const ReservationSettings({
    this.slotDurationMinutes = 60,
    this.maxDaysInAdvance = 14,
    this.bufferTimeMinutes = 15,
    this.minPartySize = 1,
    this.maxPartySize = 20,
    this.requireDeposit = false,
    this.depositAmount = 0,
    this.depositPartyThreshold = 8,
    this.allowWaitlist = true,
    this.cancellationWindowMinutes = 120,
    this.offersBirthdayPackage = false,
    this.offersAnniversaryPackage = false,
    this.specialMenuAvailable = false,
    this.needsAdvanceNotice = true,
    this.minAdvanceNoticeDays = 3,
  });

  // --- reservation.reservationSettings -----------------------------------
  final int slotDurationMinutes;
  final int maxDaysInAdvance;
  final int bufferTimeMinutes;
  final int minPartySize;
  final int maxPartySize;
  final bool requireDeposit;
  final double depositAmount;
  final int depositPartyThreshold;
  final bool allowWaitlist;
  final int cancellationWindowMinutes;

  // --- restaurant.celebrationFeatures ------------------------------------
  final bool offersBirthdayPackage;
  final bool offersAnniversaryPackage;
  final bool specialMenuAvailable;
  final bool needsAdvanceNotice;
  final int minAdvanceNoticeDays;

  /// Reservation half only — `celebrationFeatures` arrives as its own object
  /// and is folded in with [withCelebration].
  factory ReservationSettings.fromJson(Map<String, dynamic> json) =>
      ReservationSettings(
        slotDurationMinutes:
            (json['slotDurationMinutes'] as num?)?.toInt() ?? 60,
        maxDaysInAdvance: (json['maxDaysInAdvance'] as num?)?.toInt() ?? 14,
        bufferTimeMinutes: (json['bufferTimeMinutes'] as num?)?.toInt() ?? 15,
        minPartySize: (json['minPartySize'] as num?)?.toInt() ?? 1,
        maxPartySize: (json['maxPartySize'] as num?)?.toInt() ?? 20,
        requireDeposit: json['requireDeposit'] as bool? ?? false,
        depositAmount: (json['depositAmount'] as num?)?.toDouble() ?? 0,
        depositPartyThreshold:
            (json['depositPartyThreshold'] as num?)?.toInt() ?? 8,
        allowWaitlist: json['allowWaitlist'] as bool? ?? true,
        cancellationWindowMinutes:
            (json['cancellationWindowMinutes'] as num?)?.toInt() ?? 120,
      );

  /// Folds the `celebrationFeatures` object into this value. Unknown or
  /// missing keys keep the current value, so a venue that has never opened
  /// the occasions section still shows the schema defaults.
  ReservationSettings withCelebration(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return this;
    return copyWith(
      offersBirthdayPackage:
          json['offersBirthdayPackage'] as bool? ?? offersBirthdayPackage,
      offersAnniversaryPackage:
          json['offersAnniversaryPackage'] as bool? ?? offersAnniversaryPackage,
      specialMenuAvailable:
          json['specialMenuAvailable'] as bool? ?? specialMenuAvailable,
      needsAdvanceNotice:
          json['needsAdvanceNotice'] as bool? ?? needsAdvanceNotice,
      minAdvanceNoticeDays:
          (json['minAdvanceNoticeDays'] as num?)?.toInt() ??
              minAdvanceNoticeDays,
    );
  }

  /// The ten keys `PUT /settings` expects under `reservationSettings`.
  Map<String, dynamic> toReservationJson() => {
        'slotDurationMinutes': slotDurationMinutes,
        'maxDaysInAdvance': maxDaysInAdvance,
        'bufferTimeMinutes': bufferTimeMinutes,
        'minPartySize': minPartySize,
        'maxPartySize': maxPartySize,
        'requireDeposit': requireDeposit,
        'depositAmount': depositAmount,
        'depositPartyThreshold': depositPartyThreshold,
        'allowWaitlist': allowWaitlist,
        'cancellationWindowMinutes': cancellationWindowMinutes,
      };

  /// The five keys that belong under `celebrationFeatures`.
  Map<String, dynamic> toCelebrationJson() => {
        'offersBirthdayPackage': offersBirthdayPackage,
        'offersAnniversaryPackage': offersAnniversaryPackage,
        'specialMenuAvailable': specialMenuAvailable,
        'needsAdvanceNotice': needsAdvanceNotice,
        'minAdvanceNoticeDays': minAdvanceNoticeDays,
      };

  /// Kept for callers that only need the reservation half.
  Map<String, dynamic> toJson() => toReservationJson();

  bool get hasOccasionPackages =>
      offersBirthdayPackage || offersAnniversaryPackage || specialMenuAvailable;

  ReservationSettings copyWith({
    int? slotDurationMinutes,
    int? maxDaysInAdvance,
    int? bufferTimeMinutes,
    int? minPartySize,
    int? maxPartySize,
    bool? requireDeposit,
    double? depositAmount,
    int? depositPartyThreshold,
    bool? allowWaitlist,
    int? cancellationWindowMinutes,
    bool? offersBirthdayPackage,
    bool? offersAnniversaryPackage,
    bool? specialMenuAvailable,
    bool? needsAdvanceNotice,
    int? minAdvanceNoticeDays,
  }) =>
      ReservationSettings(
        slotDurationMinutes: slotDurationMinutes ?? this.slotDurationMinutes,
        maxDaysInAdvance: maxDaysInAdvance ?? this.maxDaysInAdvance,
        bufferTimeMinutes: bufferTimeMinutes ?? this.bufferTimeMinutes,
        minPartySize: minPartySize ?? this.minPartySize,
        maxPartySize: maxPartySize ?? this.maxPartySize,
        requireDeposit: requireDeposit ?? this.requireDeposit,
        depositAmount: depositAmount ?? this.depositAmount,
        depositPartyThreshold:
            depositPartyThreshold ?? this.depositPartyThreshold,
        allowWaitlist: allowWaitlist ?? this.allowWaitlist,
        cancellationWindowMinutes:
            cancellationWindowMinutes ?? this.cancellationWindowMinutes,
        offersBirthdayPackage:
            offersBirthdayPackage ?? this.offersBirthdayPackage,
        offersAnniversaryPackage:
            offersAnniversaryPackage ?? this.offersAnniversaryPackage,
        specialMenuAvailable: specialMenuAvailable ?? this.specialMenuAvailable,
        needsAdvanceNotice: needsAdvanceNotice ?? this.needsAdvanceNotice,
        minAdvanceNoticeDays:
            minAdvanceNoticeDays ?? this.minAdvanceNoticeDays,
      );

  @override
  bool operator ==(Object other) =>
      other is ReservationSettings &&
      other.slotDurationMinutes == slotDurationMinutes &&
      other.maxDaysInAdvance == maxDaysInAdvance &&
      other.bufferTimeMinutes == bufferTimeMinutes &&
      other.minPartySize == minPartySize &&
      other.maxPartySize == maxPartySize &&
      other.requireDeposit == requireDeposit &&
      other.depositAmount == depositAmount &&
      other.depositPartyThreshold == depositPartyThreshold &&
      other.allowWaitlist == allowWaitlist &&
      other.cancellationWindowMinutes == cancellationWindowMinutes &&
      other.offersBirthdayPackage == offersBirthdayPackage &&
      other.offersAnniversaryPackage == offersAnniversaryPackage &&
      other.specialMenuAvailable == specialMenuAvailable &&
      other.needsAdvanceNotice == needsAdvanceNotice &&
      other.minAdvanceNoticeDays == minAdvanceNoticeDays;

  @override
  int get hashCode => Object.hashAll(<Object>[
        slotDurationMinutes,
        maxDaysInAdvance,
        bufferTimeMinutes,
        minPartySize,
        maxPartySize,
        requireDeposit,
        depositAmount,
        depositPartyThreshold,
        allowWaitlist,
        cancellationWindowMinutes,
        offersBirthdayPackage,
        offersAnniversaryPackage,
        specialMenuAvailable,
        needsAdvanceNotice,
        minAdvanceNoticeDays,
      ]);
}
