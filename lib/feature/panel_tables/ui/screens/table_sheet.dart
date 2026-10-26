// lib/feature/panel_tables/ui/screens/table_sheet.dart
//
// One table, everything staff need at the host stand: its QR (to reprint or
// rotate), the live party with their asks, the kitchen tickets and their
// notes, the bill, and today's booking. Read-only for roles without
// `manage_tables`; destructive actions always confirm.
import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/floor_models.dart';
import '../../data/model/table_models.dart';
import '../logic/tables_panel_cubit.dart';
import '../widgets/tables_widgets.dart';

/// Opens the table sheet. The cubit is shared (not re-created) so a handled
/// request or a settle immediately refreshes the floor behind the sheet.
Future<void> showTableSheet(
  BuildContext context, {
  required TablesPanelCubit cubit,
  required PanelPhysicalTable table,
  required bool canManage,
  required bool canSeat,
  VoidCallback? onOpenOrders,
  Future<void> Function()? onEdit,
  Future<void> Function()? onDelete,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    builder: (_) => BlocProvider<TablesPanelCubit>.value(
      value: cubit,
      child: TableSheet(
        table: table,
        canManage: canManage,
        canSeat: canSeat,
        onOpenOrders: onOpenOrders,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    ),
  );
}

class TableSheet extends StatefulWidget {
  const TableSheet({
    super.key,
    required this.table,
    required this.canManage,
    required this.canSeat,
    this.onOpenOrders,
    this.onEdit,
    this.onDelete,
  });

  final PanelPhysicalTable table;
  final bool canManage;
  final bool canSeat;
  final VoidCallback? onOpenOrders;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

  @override
  State<TableSheet> createState() => _TableSheetState();
}

class _TableSheetState extends State<TableSheet> {
  bool _askedForQr = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_askedForQr) return;
    _askedForQr = true;
    final cubit = context.read<TablesPanelCubit>();
    final state = cubit.state;
    if (state is TablesPanelLoaded && !state.qr.containsKey(widget.table.id)) {
      unawaited(cubit.loadQr(widget.table.id));
    }
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error ? TableColors.attention : TableColors.ink,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          margin: EdgeInsets.all(16.w),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.55,
      maxChildSize: 0.96,
      expand: false,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: TableColors.canvas,
            borderRadius: BorderRadius.vertical(top: Radius.circular(26.r)),
          ),
          clipBehavior: Clip.antiAlias,
          child: BlocBuilder<TablesPanelCubit, TablesPanelState>(
            builder: (context, state) {
              final loaded = state is TablesPanelLoaded ? state : null;
              final table = loaded?.tableById(widget.table.id) ?? widget.table;
              final busy = loaded?.actionId;
              return Column(
                children: [
                  _grabber(),
                  Expanded(
                    child: ListView(
                      controller: controller,
                      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 28.h),
                      children: [
                        _Header(table: table),
                        SizedBox(height: 14.h),
                        if (table.hasAttention) ...[
                          _RequestsCard(
                            table: table,
                            busy: busy == table.id,
                            onHandle: (request) async {
                              final ok = await context
                                  .read<TablesPanelCubit>()
                                  .handleRequest(table.id, request.id);
                              if (ok) _toast('status_handled'.tr());
                            },
                          ),
                          SizedBox(height: 12.h),
                        ],
                        _QrCard(
                          table: table,
                          qr: loaded?.qr[table.id],
                          loading: loaded?.qrLoadingId == table.id,
                          error: loaded?.qrError,
                          onRetry: () =>
                              context.read<TablesPanelCubit>().loadQr(table.id),
                          onRotate: () => _rotateQr(table),
                          onCopied: () => _toast('link_copied'.tr()),
                        ),
                        SizedBox(height: 12.h),
                        _PartyCard(
                          table: table,
                          onOpenOrders: widget.onOpenOrders,
                        ),
                        SizedBox(height: 12.h),
                        _OrdersCard(table: table),
                        if (table.billTotal > 0) ...[
                          SizedBox(height: 12.h),
                          _BillCard(table: table),
                        ],
                        if (table.reservation != null) ...[
                          SizedBox(height: 12.h),
                          _ReservationCard(
                            reservation: table.reservation!,
                            canSeat: widget.canSeat,
                            busy: busy == table.reservation!.id,
                            onSeat: () => _seat(table.reservation!, true),
                            onNoShow: () => _seat(table.reservation!, false),
                            onCall: () => _call(table.reservation!),
                          ),
                        ],
                        if (widget.canManage) ...[
                          SizedBox(height: 18.h),
                          _ManageBar(
                            table: table,
                            busy: busy == table.id,
                            onEdit: widget.onEdit,
                            onDelete: widget.onDelete,
                          ),
                        ],
                      ],
                    ),
                  ),
                  _settleBar(table, busy),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// The money action never hides below the fold. Collecting a bill is why
  /// staff opened the sheet, and after four tickets and a QR it used to sit a
  /// full scroll away. Pinned above the safe area, it stays one tap from
  /// anywhere in the sheet; the amount itself is not repeated, so the bill
  /// card remains the single place that explains the numbers.
  Widget _settleBar(PanelPhysicalTable table, String? busy) {
    if (table.billRemaining <= 0) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsetsDirectional.fromSTEB(16.w, 10.h, 16.w, 10.h),
      decoration: const BoxDecoration(
        color: TavoColors.background,
        border: Border(top: BorderSide(color: TavoColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: TavoButton.primary(
          key: const Key('settle_table'),
          label: 'settle'.tr(),
          expand: true,
          isLoading: busy == table.id,
          leading: const Icon(Iconsax.wallet_3, size: 18),
          onPressed: () => _settle(table),
        ),
      ),
    );
  }

  /// Same handle as every other panel sheet: 40 × 4 on a 24 px drag strip.
  Widget _grabber() => const SizedBox(
    height: 24,
    child: Center(
      child: SizedBox(
        width: 40,
        height: 4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: TavoColors.handle,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
      ),
    ),
  );

  Future<void> _rotateQr(PanelPhysicalTable table) async {
    final confirmed = await TavoSheet.show<bool>(
      context,
      title: 'rotate_qr'.tr(),
      subtitle: table.code,
      maxHeightFactor: 0.44,
      child: _ConfirmBody(
        message: 'rotate_qr_warning'.tr(),
        confirmKey: const Key('confirm_rotate_qr'),
        confirmLabel: 'rotate'.tr(),
      ),
    );
    if (confirmed != true || !mounted) return;
    final qr = await context.read<TablesPanelCubit>().rotateQr(table.id);
    if (qr != null) _toast('qr_rotated'.tr());
  }

  Future<void> _settle(PanelPhysicalTable table) async {
    final confirmed = await TavoSheet.show<bool>(
      context,
      title: 'settle'.tr(),
      subtitle: table.code,
      maxHeightFactor: 0.44,
      child: _ConfirmBody(
        message: 'settle_confirm'.tr(),
        confirmKey: const Key('confirm_settle'),
        confirmLabel: 'settle'.tr(),
      ),
    );
    if (confirmed != true || !mounted) return;
    final ok = await context.read<TablesPanelCubit>().settleTable(table.id);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      _toast('settle_done'.tr());
    }
  }

  Future<void> _seat(PanelTableReservation reservation, bool seat) async {
    final cubit = context.read<TablesPanelCubit>();
    final ok = seat
        ? await cubit.seatReservation(reservation.id)
        : await cubit.markReservationNoShow(reservation.id);
    if (ok) _toast(seat ? 'reservation_seated'.tr() : 'no_show'.tr());
  }

  Future<void> _call(PanelTableReservation reservation) async {
    final uri = Uri.parse('tel:${reservation.customerPhone}');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.table});

  final PanelPhysicalTable table;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 58.w,
          height: 58.w,
          decoration: BoxDecoration(
            color: TableColors.of(table.floorStatus).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(17.r),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                table.code,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w800,
                  color: TableColors.ink,
                ),
              ),
              Text(
                '${table.seats}',
                style: TextStyle(fontSize: 9.sp, color: TableColors.inkSoft),
              ),
            ],
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      table.code,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.w800,
                        color: TableColors.ink,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  TableStatusPill(status: table.floorStatus),
                ],
              ),
              SizedBox(height: 3.h),
              Text(
                [
                  if (table.typeLabel.isNotEmpty) table.typeLabel,
                  if (table.zone?.isNotEmpty == true) table.zone!,
                  if (table.openSession != null)
                    '${table.guestCount} ${'guests'.tr().toLowerCase()}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11.sp, color: TableColors.inkSoft),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.icon, required this.label, this.trailing});

  final IconData icon;
  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: TableColors.inkSoft),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: TableColors.inkSoft,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    // One card shell for the whole sheet, exactly as the menu and the site
    // use it: `bg-card` on a hairline, 16 px radius, no ripple.
    return TavoCard(
      padding: padding ?? EdgeInsets.all(13.w),
      child: child,
    );
  }
}

class _QrCard extends StatelessWidget {
  const _QrCard({
    required this.table,
    required this.qr,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.onRotate,
    required this.onCopied,
  });

  final PanelPhysicalTable table;
  final PanelTableQr? qr;
  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final VoidCallback onRotate;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Iconsax.scan_barcode,
            label: 'table_qr'.tr(),
            trailing: qr == null
                ? null
                : Text(
                    'v${qr!.version}',
                    style: TextStyle(
                      fontSize: 9.sp,
                      color: TableColors.inkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          SizedBox(height: 10.h),
          if (loading)
            SizedBox(
              height: 150.h,
              child: const Center(child: CircularProgressIndicator()),
            )
          else if (error != null)
            SizedBox(
              height: 120.h,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'qr_issue_failed'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: TableColors.inkSoft,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  TextButton(onPressed: onRetry, child: Text('retry'.tr())),
                ],
              ),
            )
          else if (qr == null)
            SizedBox(
              height: 120.h,
              child: Center(
                child: TextButton(
                  key: const Key('load_table_qr'),
                  onPressed: onRetry,
                  child: Text('table_qr'.tr()),
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: EdgeInsets.all(7.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: TableColors.line),
                  ),
                  child: QrImageView(
                    key: const Key('table_qr_image'),
                    data: qr!.url,
                    size: 118.w,
                    backgroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        qr!.shortPath,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: TableColors.inkSoft,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'qr_hint'.tr(),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: TableColors.inkSoft,
                          height: 1.35,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Wrap(
                        spacing: 6.w,
                        runSpacing: 4.h,
                        children: [
                          _MiniButton(
                            key: const Key('copy_qr_link'),
                            icon: Iconsax.share,
                            label: 'copy_link'.tr(),
                            onTap: () async {
                              await Clipboard.setData(
                                ClipboardData(text: qr!.url),
                              );
                              onCopied();
                            },
                          ),
                          _MiniButton(
                            key: const Key('print_table_qr'),
                            icon: Iconsax.printer,
                            label: 'print'.tr(),
                            onTap: () => _printSingle(context, table, qr!),
                          ),
                          _MiniButton(
                            key: const Key('rotate_table_qr'),
                            icon: Iconsax.refresh,
                            label: 'rotate_qr'.tr(),
                            danger: true,
                            onTap: onRotate,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Widget glyph = Icon(icon, size: 13, color: null);
    return _CompactButton(
      danger: danger,
      onTap: onTap,
      leading: glyph,
      label: label,
    );
  }
}

/// The kit button at row scale. `TavoButton.compact` is 36 px, which is the
/// right target next to a QR code but too tall inside a dense fact row, so the
/// painted height is trimmed while the tap target stays 36.
class _CompactButton extends StatelessWidget {
  const _CompactButton({
    required this.label,
    required this.onTap,
    this.leading,
    this.danger = false,
  });

  final String label;
  final VoidCallback onTap;
  final Widget? leading;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final Color color =
        danger ? TavoColors.destructiveSolid : TavoColors.foreground;
    return TavoPressScale(
      child: Semantics(
        button: true,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: 30),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TavoSpace.sm,
              vertical: TavoSpace.xxs,
            ),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(TavoRadii.sm),
              border: Border.all(color: color.withValues(alpha: 0.14)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (leading != null) ...<Widget>[
                  IconTheme.merge(
                    data: IconThemeData(size: 13, color: color),
                    child: leading!,
                  ),
                  const SizedBox(width: 4),
                ],
                Text(
                  label,
                  style: TavoType.micro.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared destructive-confirmation body: the website's two-button row inside
/// the website's sheet. Every confirm in the panel looks the same.
class _ConfirmBody extends StatelessWidget {
  const _ConfirmBody({
    required this.message,
    required this.confirmKey,
    required this.confirmLabel,
  });

  final String message;
  final Key confirmKey;
  final String confirmLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          message,
          style: TavoType.bodySmall.copyWith(
            color: TavoColors.mutedForeground,
          ),
        ),
        SizedBox(height: TavoSpace.xl),
        Row(
          children: [
            Expanded(
              child: TavoButton.secondary(
                label: 'cancel'.tr(),
                expand: true,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
            SizedBox(width: TavoSpace.md),
            Expanded(
              child: TavoButton.destructive(
                key: confirmKey,
                label: confirmLabel,
                expand: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _RequestsCard extends StatelessWidget {
  const _RequestsCard({
    required this.table,
    required this.busy,
    required this.onHandle,
  });

  final PanelPhysicalTable table;
  final bool busy;
  final void Function(PanelServiceRequestSummary) onHandle;

  @override
  Widget build(BuildContext context) {
    return _Card(
      padding: EdgeInsets.fromLTRB(13.w, 11.h, 8.w, 11.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Iconsax.notification_bing,
            label: 'requests'.tr(),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
              decoration: BoxDecoration(
                color: TableColors.attention.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${table.pendingRequests.length}',
                style: TextStyle(
                  fontSize: 9.sp,
                  fontWeight: FontWeight.w800,
                  color: TableColors.attention,
                ),
              ),
            ),
          ),
          SizedBox(height: 6.h),
          for (final request in table.pendingRequests)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 3.h),
              child: Row(
                children: [
                  Container(
                    width: 30.w,
                    height: 30.w,
                    decoration: BoxDecoration(
                      color: TableColors.attention.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      requestIcon(request.type),
                      size: 15.sp,
                      color: TableColors.attention,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          requestLabel(request.type),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: TableColors.ink,
                          ),
                        ),
                        if (request.guestLabel.isNotEmpty)
                          Text(
                            request.guestLabel,
                            style: TextStyle(
                              fontSize: 9.5.sp,
                              color: TableColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                  ),
                  TextButton(
                    key: Key('handle_${request.id}'),
                    onPressed: busy ? null : () => onHandle(request),
                    child: busy
                        ? SizedBox(
                            width: 13.w,
                            height: 13.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'mark_handled'.tr(),
                            style: TextStyle(
                              fontSize: 10.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _PartyCard extends StatelessWidget {
  const _PartyCard({required this.table, this.onOpenOrders});

  final PanelPhysicalTable table;
  final VoidCallback? onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final session = table.openSession;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Iconsax.people,
            label: 'current_order'.tr(),
            trailing: onOpenOrders == null
                ? null
                : TextButton(
                    key: const Key('open_orders'),
                    onPressed: onOpenOrders,
                    child: Text(
                      'open_orders'.tr(),
                      style: TextStyle(fontSize: 10.sp),
                    ),
                  ),
          ),
          SizedBox(height: 4.h),
          if (session == null)
            Text(
              'no_order'.tr(),
              style: TextStyle(fontSize: 11.sp, color: TableColors.inkSoft),
            )
          else
            Wrap(
              spacing: 6.w,
              runSpacing: 5.h,
              children: [
                _Fact(label: 'session_label'.tr(), value: session.code),
                _Fact(label: 'guests'.tr(), value: '${table.guestCount}'),
                if (table.seatedSince != null)
                  _Fact(
                    label: 'opened_at'.tr(),
                    value: floorClock(table.seatedSince),
                  ),
                _Fact(
                  label: 'item_count'.tr(args: ['${table.openItemCount}']),
                  value: '${formatMoney(table.billTotal)} SAR',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: TableColors.canvas,
        borderRadius: BorderRadius.circular(9.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 8.sp, color: TableColors.inkSoft),
          ),
          SizedBox(height: 1.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
              color: TableColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}

class _OrdersCard extends StatelessWidget {
  const _OrdersCard({required this.table});

  final PanelPhysicalTable table;

  @override
  Widget build(BuildContext context) {
    final arabic = context.locale.languageCode == 'ar';
    if (table.orders.isEmpty) {
      return _Card(
        child: Row(
          children: [
            Icon(Iconsax.receipt_1, size: 15.sp, color: TableColors.inkSoft),
            SizedBox(width: 7.w),
            Text(
              'no_order'.tr(),
              style: TextStyle(fontSize: 11.sp, color: TableColors.inkSoft),
            ),
          ],
        ),
      );
    }
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Iconsax.receipt_1,
            label: 'current_order'.tr(),
            trailing: Text(
              '${table.orders.length}',
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: TableColors.inkSoft,
              ),
            ),
          ),
          for (final order in table.orders) ...[
            SizedBox(height: 10.h),
            Row(
              children: [
                Text(
                  order.orderNumber.isEmpty ? '—' : order.orderNumber,
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w800,
                    color: TableColors.ink,
                  ),
                ),
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 1.h),
                  decoration: BoxDecoration(
                    color: TableColors.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    orderStatusLabel(order.status),
                    style: TextStyle(
                      fontSize: 8.5.sp,
                      fontWeight: FontWeight.w700,
                      color: TableColors.inkSoft,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${formatMoney(order.totalPrice)} SAR',
                  style: TextStyle(
                    fontSize: 10.5.sp,
                    fontWeight: FontWeight.w800,
                    color: TableColors.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            for (final line in order.items)
              Padding(
                padding: EdgeInsets.only(bottom: 3.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${line.quantity}×',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w800,
                        color: TableColors.goldDark,
                      ),
                    ),
                    SizedBox(width: 5.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.displayName(arabic),
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: TableColors.ink,
                              height: 1.3,
                            ),
                          ),
                          if (line.specifications.isNotEmpty)
                            Text(
                              line.specifications.join(' · '),
                              style: TextStyle(
                                fontSize: 9.sp,
                                color: TableColors.inkSoft,
                                height: 1.3,
                              ),
                            ),
                          if (line.note.isNotEmpty)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Iconsax.note_1,
                                  size: 9.sp,
                                  color: TableColors.attention,
                                ),
                                SizedBox(width: 3.w),
                                Expanded(
                                  child: Text(
                                    line.note,
                                    style: TextStyle(
                                      fontSize: 9.sp,
                                      color: TableColors.attention,
                                      fontStyle: FontStyle.italic,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    Text(
                      formatMoney(line.lineTotal),
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            if (order.note.isNotEmpty)
              Container(
                margin: EdgeInsets.only(top: 3.h),
                padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: TableColors.attention.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(7.r),
                ),
                child: Text(
                  '${'order_note'.tr()}: ${order.note}',
                  style: TextStyle(
                    fontSize: 9.sp,
                    color: TableColors.attention,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.table});

  final PanelPhysicalTable table;

  @override
  Widget build(BuildContext context) {
    final session = table.openSession;
    return _Card(
      child: Column(
        children: [
          _SectionTitle(icon: Iconsax.wallet_3, label: 'bill'.tr()),
          SizedBox(height: 8.h),
          if (session != null && session.subtotal > 0) ...[
            _MoneyRow(label: 'subtotal'.tr(), value: session.subtotal),
            if (session.tax > 0) ...[
              SizedBox(height: 4.h),
              _MoneyRow(label: 'tax'.tr(), value: session.tax),
            ],
            SizedBox(height: 6.h),
            Divider(height: 1, color: TableColors.line),
            SizedBox(height: 6.h),
          ],
          _MoneyRow(label: 'total'.tr(), value: table.billTotal, bold: true),
          if (table.billPaid > 0) ...[
            SizedBox(height: 4.h),
            _MoneyRow(label: 'paid'.tr(), value: table.billPaid),
          ],
          if (table.billRemaining > 0) ...[
            SizedBox(height: 4.h),
            _MoneyRow(
              label: 'remaining'.tr(),
              value: table.billRemaining,
              color: TableColors.attention,
            ),
          ],
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.color,
  });

  final String label;
  final double value;
  final bool bold;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: bold ? 12.sp : 10.5.sp,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
            color: color ?? TableColors.inkSoft,
          ),
        ),
        const Spacer(),
        Text(
          '${formatMoney(value)} SAR',
          style: TextStyle(
            fontSize: bold ? 14.sp : 10.5.sp,
            fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
            color: color ?? TableColors.ink,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}

class _ReservationCard extends StatelessWidget {
  const _ReservationCard({
    required this.reservation,
    required this.canSeat,
    required this.busy,
    required this.onSeat,
    required this.onNoShow,
    required this.onCall,
  });

  final PanelTableReservation reservation;
  final bool canSeat;
  final bool busy;
  final VoidCallback onSeat;
  final VoidCallback onNoShow;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Iconsax.calendar_1,
            label: 'reservation'.tr(),
            trailing: TableStatusPill(
              status: reservation.isSeated ? 'occupied' : 'reserved',
              label: reservation.isSeated
                  ? 'reservation_seated'.tr()
                  : 'reservation_expected'.tr(),
              compact: true,
            ),
          ),
          SizedBox(height: 8.h),
          Row(
            children: [
              Text(
                floorClock(reservation.startAt),
                style: TextStyle(
                  fontSize: 17.sp,
                  fontWeight: FontWeight.w800,
                  color: TableColors.ink,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  [
                    reservation.customerName,
                    'party_of'.tr(args: ['${reservation.guestsCount}']),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: TableColors.ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (reservation.customerPhone.isNotEmpty)
                IconButton(
                  key: const Key('call_reservation'),
                  tooltip: 'call_guest'.tr(),
                  onPressed: onCall,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Iconsax.call,
                    size: 16.sp,
                    color: TableColors.inkSoft,
                  ),
                ),
            ],
          ),
          if (canSeat && reservation.isExpected) ...[
            SizedBox(height: 8.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: const Key('seat_reservation'),
                    onPressed: busy ? null : onSeat,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TableColors.available,
                      side: const BorderSide(color: TableColors.available),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                    ),
                    child: Text(
                      'seat_party'.tr(),
                      style: TextStyle(fontSize: 11.sp),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: TextButton(
                    key: const Key('noshow_reservation'),
                    onPressed: busy ? null : onNoShow,
                    child: Text(
                      'no_show'.tr(),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _ManageBar extends StatelessWidget {
  const _ManageBar({
    required this.table,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final PanelPhysicalTable table;
  final bool busy;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onEdit != null)
          Expanded(
            child: TavoButton.secondary(
              key: const Key('edit_table'),
              label: 'edit_table'.tr(),
              size: TavoButtonSize.compact,
              expand: true,
              leading: const Icon(Iconsax.edit_2, size: 15),
              onPressed: busy ? null : onEdit,
            ),
          ),
        if (onDelete != null) ...[
          SizedBox(width: 8.w),
          Expanded(
            child: TavoButton.destructive(
              key: const Key('delete_table'),
              label: 'delete_table'.tr(),
              size: TavoButtonSize.compact,
              expand: true,
              leading: const Icon(Iconsax.trash, size: 15),
              onPressed: busy ? null : onDelete,
            ),
          ),
        ],
      ],
    );
  }
}

/// One table card at A5 landscape on a single A4 page. Used by the sheet's
/// print action and by the batch screen's per-card preview.
pw.Document buildTableQrDocument(
  List<({String code, String zone, String url})> rows,
) {
  final doc = pw.Document();
  const perPage = 4;
  for (var start = 0; start < rows.length; start += perPage) {
    final chunk = rows.skip(start).take(perPage).toList();
    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => pw.Column(
          children: [
            for (var row = 0; row < 2; row++)
              pw.Expanded(
                child: pw.Row(
                  children: [
                    for (var col = 0; col < 2; col++)
                      pw.Expanded(
                        child: (row * 2 + col) < chunk.length
                            ? _qrPdfCard(chunk[row * 2 + col])
                            : pw.SizedBox(),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
  return doc;
}

pw.Widget _qrPdfCard(({String code, String zone, String url}) row) {
  return pw.Container(
    margin: const pw.EdgeInsets.all(8),
    padding: const pw.EdgeInsets.all(14),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400, width: 1.2),
      borderRadius: pw.BorderRadius.circular(12),
    ),
    child: pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        pw.Text(
          row.code,
          style: pw.TextStyle(fontSize: 26, fontWeight: pw.FontWeight.bold),
        ),
        if (row.zone.isNotEmpty)
          pw.Text(row.zone, style: const pw.TextStyle(fontSize: 11)),
        pw.SizedBox(height: 12),
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: row.url,
          width: 120,
          height: 120,
        ),
        pw.SizedBox(height: 10),
        pw.Text(
          'Scan to order from this table',
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
      ],
    ),
  );
}

Future<void> _printSingle(
  BuildContext context,
  PanelPhysicalTable table,
  PanelTableQr qr,
) async {
  final doc = buildTableQrDocument([
    (code: table.code, zone: table.zone ?? '', url: qr.url),
  ]);
  await Printing.layoutPdf(
    name: 'table-${table.code}-qr',
    onLayout: (_) => doc.save(),
  );
}
