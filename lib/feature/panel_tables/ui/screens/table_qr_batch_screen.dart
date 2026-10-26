// lib/feature/panel_tables/ui/screens/table_qr_batch_screen.dart
//
// Batch table cards: one QR per table, ready to print on the office printer
// or export as a PDF. Reads are idempotent (GET /qr never rotates), so
// opening this screen can never kill a card already stuck to a table.
import 'dart:async';

import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:printing/printing.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../data/model/table_models.dart';
import '../logic/tables_panel_cubit.dart';
import '../widgets/tables_widgets.dart';
import 'table_sheet.dart';

class TableQrBatchScreen extends StatefulWidget {
  const TableQrBatchScreen({super.key, required this.tables});

  final List<PanelPhysicalTable> tables;

  @override
  State<TableQrBatchScreen> createState() => _TableQrBatchScreenState();
}

class _TableQrBatchScreenState extends State<TableQrBatchScreen> {
  bool _requested = false;
  bool _printing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_requested) return;
    _requested = true;
    final cubit = context.read<TablesPanelCubit>();
    for (final table in widget.tables) {
      unawaited(cubit.loadQr(table.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TableColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'batch_qr_title'.tr(),
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: TableColors.ink,
              ),
            ),
            Text(
              'batch_qr_subtitle'.tr(),
              style: TextStyle(fontSize: 10.sp, color: TableColors.inkSoft),
            ),
          ],
        ),
        actions: [
          BlocBuilder<TablesPanelCubit, TablesPanelState>(
            builder: (context, state) {
              final loaded = state is TablesPanelLoaded ? state : null;
              final ready = widget.tables
                  .where((t) => loaded?.qr[t.id] != null)
                  .toList();
              return TextButton.icon(
                key: const Key('print_all_qr'),
                onPressed: _printing || ready.isEmpty
                    ? null
                    : () => _print(loaded!, widget.tables),
                icon: _printing
                    ? SizedBox(
                        width: 14.w,
                        height: 14.w,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Iconsax.printer, size: 15.sp),
                label: Text(
                  'print_all'.tr(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: BlocBuilder<TablesPanelCubit, TablesPanelState>(
        builder: (context, state) {
          final loaded = state is TablesPanelLoaded ? state : null;
          if (widget.tables.isEmpty) {
            return Center(
              child: Text(
                'qr_batch_empty'.tr(),
                style: TextStyle(fontSize: 12.sp, color: TableColors.inkSoft),
              ),
            );
          }
          return GridView.builder(
            key: const Key('qr_batch_grid'),
            padding: EdgeInsets.all(16.w),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10.h,
              crossAxisSpacing: 10.w,
              childAspectRatio: 0.72,
            ),
            itemCount: widget.tables.length,
            itemBuilder: (context, index) {
              final table = widget.tables[index];
              final qr = loaded?.qr[table.id];
              final loading = loaded?.qrLoadingId == table.id;
              return Container(
                key: Key('qr_card_${table.id}'),
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: TableColors.line),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            table.code,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w800,
                              color: TableColors.ink,
                            ),
                          ),
                        ),
                        if (table.zone?.isNotEmpty == true)
                          Text(
                            table.zone!,
                            style: TextStyle(
                              fontSize: 9.sp,
                              color: TableColors.inkSoft,
                            ),
                          ),
                      ],
                    ),
                    Expanded(
                      child: Center(
                        child: loading
                            ? const CircularProgressIndicator()
                            : qr == null
                            ? IconButton(
                                key: Key('qr_retry_${table.id}'),
                                onPressed: () => context
                                    .read<TablesPanelCubit>()
                                    .loadQr(table.id),
                                icon: Icon(
                                  Iconsax.refresh,
                                  size: 18.sp,
                                  color: TableColors.inkSoft,
                                ),
                              )
                            : QrImageView(
                                data: qr.url,
                                size: 120.w,
                                backgroundColor: Colors.white,
                                padding: EdgeInsets.zero,
                              ),
                      ),
                    ),
                    Text(
                      qr == null ? '—' : 'v${qr.version}',
                      style: TextStyle(
                        fontSize: 9.sp,
                        color: TableColors.inkSoft,
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _print(
    TablesPanelLoaded state,
    List<PanelPhysicalTable> tables,
  ) async {
    final rows = <({String code, String zone, String url})>[
      for (final table in tables)
        if (state.qr[table.id] != null)
          (
            code: table.code,
            zone: table.zone ?? '',
            url: state.qr[table.id]!.url,
          ),
    ];
    if (rows.isEmpty) return;
    setState(() => _printing = true);
    try {
      final doc = buildTableQrDocument(rows);
      await Printing.layoutPdf(
        name: 'table-qr-codes',
        onLayout: (_) => doc.save(),
      );
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}
