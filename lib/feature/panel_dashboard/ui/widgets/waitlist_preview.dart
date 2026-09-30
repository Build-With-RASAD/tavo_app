// lib/feature/panel_dashboard/ui/widgets/waitlist_preview.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_waitlist/data/model/waitlist_models.dart';

/// First waitlist page (limit 5) with the endpoint total in the header.
/// "View all" hands off to the waitlist shell tab via [onOpenWaitlist] —
/// the tab switch itself is controller-owned (reported diff, not built here).
class WaitlistPreview extends StatelessWidget {
  const WaitlistPreview({
    super.key,
    required this.entries,
    required this.total,
    this.onOpenWaitlist,
  });

  final List<PanelWaitlistEntry> entries;
  final int total;
  final VoidCallback? onOpenWaitlist;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${'dash_waitlist_title'.tr()} · $total',
                style: TextStyles.font16Black500Weight(context),
              ),
            ),
            TextButton(
              key: const ValueKey('dash_open_waitlist'),
              onPressed: onOpenWaitlist,
              child: Text('dash_view_all'.tr()),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        if (entries.isEmpty)
          Text(
            'no_data'.tr(),
            style: TextStyles.font14DarkGray400Weight(context),
          )
        else
          for (final entry in entries) ...[
            Container(
              key: ValueKey('dash_wait_${entry.id}'),
              margin: EdgeInsets.only(bottom: 8.h),
              padding: EdgeInsets.all(12.r),
              decoration: BoxDecoration(
                color: ColorsManager.white,
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: ColorsManager.grey100),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.customerName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyles.font14Black400Weight(context),
                    ),
                  ),
                  Text(
                    '${entry.ticketCode} · ${entry.guestsCount}',
                    style: TextStyles.font12DarkGray400Weight(context),
                  ),
                ],
              ),
            ),
          ],
      ],
    );
  }
}
