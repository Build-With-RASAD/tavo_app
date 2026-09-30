// lib/feature/panel_dashboard/ui/widgets/quick_actions.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/feature/panel_dashboard/ui/logic/dashboard_extras_cubit.dart';

/// Two dashboard shortcuts: staff walk-in (bottom sheet → the Task 26
/// `POST /waitlist` micro-endpoint through [DashboardExtrasCubit]) and
/// new order (hands off to the T23 create-flow entry via [onNewOrder] —
/// the navigation itself is controller-owned).
class QuickActions extends StatelessWidget {
  const QuickActions({super.key, this.onNewOrder});

  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            key: const ValueKey('dash_quick_waitlist'),
            style: FilledButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            ),
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              builder: (_) => BlocProvider.value(
                value: context.read<DashboardExtrasCubit>(),
                child: const _AddToWaitlistSheet(),
              ),
            ),
            icon: const Icon(Icons.person_add_outlined),
            label: Text('dash_quick_waitlist'.tr()),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: OutlinedButton.icon(
            key: const ValueKey('dash_quick_order'),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
            ),
            onPressed: onNewOrder,
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text('dash_quick_order'.tr()),
          ),
        ),
      ],
    );
  }
}

/// Walk-in form: name + phone + party size + optional email/notes.
/// Server-side validation owns the rules; failures render inline from
/// [DashboardExtrasLoaded.actionError]. Success pops the sheet.
class _AddToWaitlistSheet extends StatefulWidget {
  const _AddToWaitlistSheet();

  @override
  State<_AddToWaitlistSheet> createState() => _AddToWaitlistSheetState();
}

class _AddToWaitlistSheetState extends State<_AddToWaitlistSheet> {
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
      final cubit = context.read<DashboardExtrasCubit>();
      await cubit.addToWaitlist(
        guestsCount: int.tryParse(_guests.text.trim()) ?? 0,
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim().isEmpty ? null : _email.text.trim(),
        specialRequests:
            _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      );
      if (!mounted) return;
      final s = cubit.state;
      if (s is DashboardExtrasLoaded && s.actionError == null) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 16.h + bottom),
      child: BlocBuilder<DashboardExtrasCubit, DashboardExtrasState>(
        builder: (context, state) {
          final error = state is DashboardExtrasLoaded
              ? state.actionError
              : null;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.person_add_alt_1_outlined,
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
                        labelText: 'email'.tr(),
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
                    Icon(Icons.error_outline,
                        size: 16.r,
                        color: Theme.of(context).colorScheme.error),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        error,
                        style: TextStyles.font14DarkGray400Weight(context)
                            .copyWith(
                                color: Theme.of(context).colorScheme.error),
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
                        child:
                            CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text('dash_submit'.tr()),
              ),
            ],
          );
        },
      ),
    );
  }
}
