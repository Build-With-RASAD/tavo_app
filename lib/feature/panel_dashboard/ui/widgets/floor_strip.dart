// lib/feature/panel_dashboard/ui/widgets/floor_strip.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';

/// Horizontal floor strip: one card per physical table with a status dot.
///
/// Colors pin the binding occupied rule — red reserved, green available,
/// orange occupied (open order on the table), grey inactive. Occupancy wins
/// over the physical status; the physical `status` itself is never rewritten.
/// Tap opens the table sheet (owned by the caller via [onTableTap]).
class FloorStrip extends StatelessWidget {
  const FloorStrip({
    super.key,
    required this.tables,
    required this.occupiedIds,
    this.onTableTap,
  });

  final List<PanelPhysicalTable> tables;
  final Set<String> occupiedIds;
  final void Function(PanelPhysicalTable table)? onTableTap;

  /// Priority: inactive > occupied (computed) > reserved > available.
  static Color colorFor(PanelPhysicalTable table, Set<String> occupiedIds) {
    if (table.status == 'inactive') return Colors.grey;
    if (occupiedIds.contains(table.id)) return Colors.orange;
    if (table.status == 'reserved') return Colors.red;
    return Colors.green;
  }

  static String statusKey(PanelPhysicalTable table, Set<String> occupiedIds) {
    if (table.status == 'inactive') return 'floor_inactive';
    if (occupiedIds.contains(table.id)) return 'floor_occupied';
    if (table.status == 'reserved') return 'floor_reserved';
    return 'floor_available';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'floor_title'.tr(),
          style: TextStyles.font16Black500Weight(context),
        ),
        SizedBox(height: 8.h),
        SizedBox(
          height: 96.h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tables.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, i) {
              final table = tables[i];
              final color = colorFor(table, occupiedIds);
              return GestureDetector(
                key: ValueKey('floor_table_${table.id}'),
                onTap:
                    onTableTap == null ? null : () => onTableTap!(table),
                child: Container(
                  width: 120.w,
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: ColorsManager.white,
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: ColorsManager.grey100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            key: ValueKey('floor_dot_${table.id}'),
                            width: 10.r,
                            height: 10.r,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 6.w),
                          Expanded(
                            child: Text(
                              table.code,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyles.font14Black400Weight(context),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        statusKey(table, occupiedIds).tr(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            TextStyles.font12DarkGray400Weight(context),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
