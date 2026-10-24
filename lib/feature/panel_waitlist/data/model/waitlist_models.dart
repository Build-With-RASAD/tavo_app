// lib/feature/panel_waitlist/data/model/waitlist_models.dart
class PanelWaitlistEntry {
  const PanelWaitlistEntry({
    required this.id,
    required this.ticketCode,
    required this.guestsCount,
    required this.customerName,
    required this.customerPhone,
    required this.status,
    required this.createdAt,
    this.customerEmail,
    this.specialRequests,
    this.notes,
    this.notifiedAt,
    this.markedAt,
  });

  final String id;
  final String ticketCode;
  final int guestsCount;
  final String customerName;
  final String customerPhone;
  final String status;
  final String createdAt;
  final String? customerEmail;
  final String? specialRequests;
  final String? notes;
  final String? notifiedAt;
  final String? markedAt;

  /// Minutes since creation (0 when unparsable — never throws in build).
  int get waitedMinutes {
    final at = DateTime.tryParse(createdAt);
    if (at == null) return 0;
    return DateTime.now().difference(at).inMinutes.clamp(0, 1 << 31);
  }

  factory PanelWaitlistEntry.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'];
    return PanelWaitlistEntry(
      id: json['_id'] as String? ?? '',
      ticketCode: json['ticketCode'] as String? ?? '',
      guestsCount: (json['guestsCount'] as num?)?.toInt() ?? 1,
      customerName:
          customer is Map ? customer['name'] as String? ?? '' : '',
      customerPhone:
          customer is Map ? customer['phone'] as String? ?? '' : '',
      customerEmail:
          customer is Map ? customer['email'] as String? : null,
      status: json['status'] as String? ?? 'waiting',
      specialRequests: json['specialRequests'] as String?,
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] as String? ?? '',
      notifiedAt: json['notifiedAt'] as String?,
      markedAt: json['markedAt'] as String?,
    );
  }
}

/// Legal panel actions per status (mirrors admin-waitlist.services.js via Task 5).
List<String> nextWaitlistActions(String status) => switch (status) {
      'waiting' => ['notify', 'confirm', 'no-show', 'cancel'],
      'notified' => ['confirm', 'no-show', 'cancel'],
      _ => [],
    };

/// 1-based queue position per entry id, oldest first.
///
/// Only `waiting`/`notified` entries occupy a position: once a party is
/// seated, cancelled or marked no-show it must not shift the line behind it.
/// Sorting by `createdAt` (not by the client's clock-derived wait) keeps the
/// order stable between rebuilds.
Map<String, int> waitlistQueuePositions(List<PanelWaitlistEntry> entries) {
  final active = entries
      .where((entry) => entry.status == 'waiting' || entry.status == 'notified')
      .toList()
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  return {
    for (var index = 0; index < active.length; index++)
      active[index].id: index + 1,
  };
}
