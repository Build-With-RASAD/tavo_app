// lib/feature/panel_settings/data/model/settings_models.dart
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
}

class ReservationSettings {
  const ReservationSettings({
    this.slotDurationMinutes = 60,
    this.specialMenuAvailable = false,
    this.needsAdvanceNotice = true,
    this.minAdvanceNoticeDays = 3,
  });

  final int slotDurationMinutes;
  final bool specialMenuAvailable;
  final bool needsAdvanceNotice;
  final int minAdvanceNoticeDays;

  factory ReservationSettings.fromJson(Map<String, dynamic> json) =>
      ReservationSettings(
        slotDurationMinutes:
            (json['slotDurationMinutes'] as num?)?.toInt() ?? 60,
        specialMenuAvailable: json['specialMenuAvailable'] as bool? ?? false,
        needsAdvanceNotice: json['needsAdvanceNotice'] as bool? ?? true,
        minAdvanceNoticeDays:
            (json['minAdvanceNoticeDays'] as num?)?.toInt() ?? 3,
      );

  Map<String, dynamic> toJson() => {
        'slotDurationMinutes': slotDurationMinutes,
        'specialMenuAvailable': specialMenuAvailable,
        'needsAdvanceNotice': needsAdvanceNotice,
        'minAdvanceNoticeDays': minAdvanceNoticeDays,
      };
}
