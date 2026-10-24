// lib/feature/qr_table/ui/widgets/rating_sheet.dart
//
// The post-meal form the client asked for: five areas, an optional comment and
// a private message for the waiter. The same sheet files a complaint or a
// suggestion, because a guest should not have to hunt for a second form.
import 'package:flutter/material.dart';

import '../../data/model/table_session_models.dart';

String _t(BuildContext context, {required String ar, required String en}) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

Future<RatingDraft?> showTableRatingSheet(
  BuildContext context, {
  required String tableCode,
}) {
  return showModalBottomSheet<RatingDraft>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _RatingSheet(tableCode: tableCode),
  );
}

class _RatingSheet extends StatefulWidget {
  const _RatingSheet({required this.tableCode});

  final String tableCode;

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  static const List<_Area> _areas = [
    _Area('restaurant', ar: 'المطعم', en: 'Restaurant'),
    _Area('waiter', ar: 'النادل', en: 'Waiter'),
    _Area('food', ar: 'جودة الطعام', en: 'Food quality'),
    _Area('speed', ar: 'سرعة الخدمة', en: 'Speed of service'),
    _Area('cleanliness', ar: 'النظافة', en: 'Cleanliness'),
  ];

  String _type = 'review';
  final Map<String, int> _scores = {};
  final TextEditingController _comment = TextEditingController();
  final TextEditingController _waiterMessage = TextEditingController();

  @override
  void dispose() {
    _comment.dispose();
    _waiterMessage.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_type == 'review') {
      return _areas.every((area) => (_scores[area.key] ?? 0) > 0);
    }
    return _comment.text.trim().isNotEmpty;
  }

  void _submit() {
    Navigator.of(context).pop(
      RatingDraft(
        type: _type,
        scores: _type == 'review' ? Map<String, int>.from(_scores) : const {},
        comment: _comment.text,
        waiterMessage: _type == 'review' ? _waiterMessage.text : '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _t(context, ar: 'كيف كانت تجربتك؟', en: 'How was your visit?'),
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              _t(
                context,
                ar: 'طاولة ${widget.tableCode}',
                en: 'Table ${widget.tableCode}',
              ),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'review',
                  label: Text(_t(context, ar: 'تقييم', en: 'Rating')),
                ),
                ButtonSegment(
                  value: 'complaint',
                  label: Text(_t(context, ar: 'شكوى', en: 'Complaint')),
                ),
                ButtonSegment(
                  value: 'suggestion',
                  label: Text(_t(context, ar: 'اقتراح', en: 'Suggestion')),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (value) => setState(() => _type = value.first),
            ),
            const SizedBox(height: 16),
            if (_type == 'review') ...[
              for (final area in _areas)
                _StarRow(
                  label: _t(context, ar: area.ar, en: area.en),
                  value: _scores[area.key] ?? 0,
                  onChanged: (value) =>
                      setState(() => _scores[area.key] = value),
                ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _comment,
              maxLines: 3,
              maxLength: 1000,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _type == 'review'
                    ? _t(context, ar: 'تعليق (اختياري)', en: 'Comment (optional)')
                    : _t(context, ar: 'اكتب التفاصيل', en: 'Tell us what happened'),
                border: const OutlineInputBorder(),
              ),
            ),
            if (_type == 'review')
              TextField(
                controller: _waiterMessage,
                maxLines: 2,
                maxLength: 500,
                decoration: InputDecoration(
                  labelText: _t(
                    context,
                    ar: 'رسالة للنادل (اختياري)',
                    en: 'Message for the waiter (optional)',
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSubmit ? _submit : null,
                child: Text(_t(context, ar: 'إرسال', en: 'Send')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Area {
  const _Area(this.key, {required this.ar, required this.en});

  final String key;
  final String ar;
  final String en;
}

class _StarRow extends StatelessWidget {
  const _StarRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          for (var star = 1; star <= 5; star += 1)
            IconButton(
              key: ValueKey('rating_${label}_$star'),
              visualDensity: VisualDensity.compact,
              onPressed: () => onChanged(star),
              icon: Icon(
                star <= value ? Icons.star_rounded : Icons.star_outline_rounded,
                color: star <= value
                    ? Colors.amber.shade600
                    : Theme.of(context).disabledColor,
              ),
            ),
        ],
      ),
    );
  }
}
