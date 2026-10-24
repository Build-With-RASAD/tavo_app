// lib/feature/panel_waitlist/ui/widgets/add_walkin_sheet.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_waitlist/ui/logic/waitlist_panel_cubit.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// The walk-in sheet: name, phone and party size, plus an optional e-mail
/// and note.
///
/// It writes through [WaitlistPanelCubit.addWalkIn] and closes only when the
/// backend accepted the entry — a failure keeps the sheet open with the
/// message beside it, so a walk-in is never lost to a silent error.
class AddWalkinSheet extends StatefulWidget {
  const AddWalkinSheet({super.key});

  @override
  State<AddWalkinSheet> createState() => _AddWalkinSheetState();
}

class _AddWalkinSheetState extends State<AddWalkinSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _guests = TextEditingController(text: '2');
  final _email = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _guests.dispose();
    _email.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final created = await context.read<WaitlistPanelCubit>().addWalkIn(
            guestsCount: int.tryParse(_guests.text.trim()) ?? 0,
            name: _name.text.trim(),
            phone: _phone.text.trim(),
            email: _email.text.trim().isEmpty ? null : _email.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
      // Only a created entry closes the sheet — a failure stays open with
      // the message beside the form.
      if (created) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h + bottom),
      child: BlocBuilder<WaitlistPanelCubit, WaitlistPanelState>(
        builder: (context, state) {
          final error =
              state is WaitlistPanelLoaded ? state.actionError : null;
          return SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.user_add,
                      size: 20.r,
                      color: ColorsManager.primary500,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'dash_sheet_title'.tr(),
                        style: TextStyles.font16Black500Weight(context),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                TextField(
                  key: const ValueKey('dash_field_name'),
                  controller: _name,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'dash_field_name'.tr(),
                  ),
                ),
                SizedBox(height: 8.h),
                TextField(
                  key: const ValueKey('dash_field_phone'),
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  decoration: InputDecoration(
                    labelText: 'dash_field_phone'.tr(),
                  ),
                ),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('dash_field_guests'),
                        controller: _guests,
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'dash_field_guests'.tr(),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: TextField(
                        key: const ValueKey('dash_field_email'),
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: 'dash_field_email'.tr(),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                TextField(
                  key: const ValueKey('dash_field_notes'),
                  controller: _notes,
                  decoration: InputDecoration(
                    labelText: 'dash_field_notes'.tr(),
                  ),
                ),
                if (error != null) ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(
                        Iconsax.info_circle,
                        size: 16.r,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text(
                          error,
                          style: TextStyles.font14DarkGray400Weight(context)
                              .copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 12.h),
                FilledButton(
                  key: const ValueKey('dash_submit'),
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text('dash_submit'.tr()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
