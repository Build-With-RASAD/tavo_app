// lib/feature/panel_dashboard/ui/widgets/section_error_boundary.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

/// One dashboard section behind its own error wall (spec decision 14).
///
/// Every section of the dashboard is wrapped in this boundary, so a section
/// that cannot be read renders ITS OWN inline error + retry while the rest
/// of the page keeps working. This is the fix for the old dashboard, where
/// one failing fetch collapsed the whole screen.
///
/// Two failure modes are covered:
///
///   * a DATA failure — the caller passes [error] (the message the section
///     read produced) and the boundary renders it inline;
///   * a BUILD failure — the section's own builder throws while the
///     boundary assembles it; the boundary catches it and renders the same
///     inline error instead of letting it escape into the page.
///
/// The section content is built INSIDE the boundary, so the data preparation
/// (formatting, ratio maths, chart series) is covered by the same guard.
class SectionErrorBoundary extends StatefulWidget {
  const SectionErrorBoundary({
    super.key,
    required this.builder,
    this.error,
    this.onRetry,
    this.loading = false,
    this.placeholder,
  });

  /// The section content. Assembled inside the boundary's error wall.
  final WidgetBuilder builder;

  /// The section-level failure message — renders the inline error.
  final String? error;

  /// The inline retry action.
  final VoidCallback? onRetry;

  /// The section is still loading — renders [placeholder] instead.
  final bool loading;

  /// The loading placeholder.
  final Widget? placeholder;

  @override
  State<SectionErrorBoundary> createState() => _SectionErrorBoundaryState();
}

class _SectionErrorBoundaryState extends State<SectionErrorBoundary> {
  Object? _buildError;

  @override
  void didUpdateWidget(covariant SectionErrorBoundary oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.error != widget.error) _buildError = null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return widget.placeholder ?? const _SectionPlaceholder();
    }
    final error = widget.error;
    if (error != null) return _ErrorCard(message: error, onRetry: widget.onRetry);
    if (_buildError != null) {
      return _ErrorCard(message: '$_buildError', onRetry: widget.onRetry);
    }
    try {
      return widget.builder(context);
    } catch (e) {
      _buildError = e;
      return _ErrorCard(message: '$e', onRetry: widget.onRetry);
    }
  }
}

/// The inline error + retry a failing section renders.
class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: errorColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.info_circle, size: 18.r, color: errorColor),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'dash_section_error'.tr(),
                  style: TextStyles.font12Black500Weight(context)
                      .copyWith(color: errorColor),
                ),
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            message,
            style: TextStyles.font12DarkGray400Weight(context)
                .copyWith(color: errorColor),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 8.h),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                key: const ValueKey('dash_section_retry'),
                onPressed: onRetry,
                icon: const Icon(Iconsax.refresh, size: 16),
                label: Text('dash_section_retry'.tr()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The grey block a section shows while it is still loading.
class _SectionPlaceholder extends StatelessWidget {
  const _SectionPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: ColorsManager.grey100,
        borderRadius: BorderRadius.circular(14.r),
      ),
    );
  }
}
