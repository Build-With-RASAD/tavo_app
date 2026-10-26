// lib/feature/restaurant_panel/ui/screens/reviews_screen.dart
//
// The feedback inbox. One screen answers three questions a manager actually
// asks: how are we doing (the overview), what did people say (ratings,
// complaints, suggestions as tabs), and who said it (guest, table, waiter and
// time in the detail sheet).
//
// The three types share one page because they share one triage habit: read,
// then resolve. Filters go to the server — a local `where` over page one would
// hide anything that arrived yesterday.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_reviews/data/model/experience_summary.dart';
import 'package:tavo/feature/panel_reviews/data/model/review_models.dart';
import 'package:tavo/feature/panel_reviews/data/repo/reviews_panel_repo.dart';
import 'package:tavo/feature/panel_reviews/ui/logic/reviews_panel_cubit.dart';

class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
  });

  final String restaurantId;
  final StaffRestaurant venue;

  /// Mirrors the server's `manage_reviews` gate. Anyone else reads the inbox.
  bool get _canTriage =>
      venue.role == 'owner' ||
      venue.role == 'manager' ||
      venue.permissions.contains('full_access') ||
      venue.permissions.contains('manage_reviews');

  @override
  Widget build(BuildContext context) {
    final bool canTriage = _canTriage;
    return BlocProvider(
      create: (_) => ReviewsPanelCubit(
        GetIt.instance<ReviewsPanelRepo>(),
        restaurantId: restaurantId,
      )..load(),
      child: BlocConsumer<ReviewsPanelCubit, ReviewsPanelState>(
        listener: (context, state) {
          if (state is ReviewsPanelLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.actionError!),
                  backgroundColor: TavoColors.destructiveSolid,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(TavoRadii.lg),
                  ),
                  margin: const EdgeInsets.all(TavoSpace.lg),
                ),
              );
          }
        },
        builder: (context, state) {
          return Scaffold(
            backgroundColor: TavoColors.background,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _Header(
                    onRefresh: context.read<ReviewsPanelCubit>().load,
                  ),
                  Expanded(
                    child: switch (state) {
                      ReviewsPanelError(:final String message) => ErrorStateView(
                          message: message,
                          onRetry: context.read<ReviewsPanelCubit>().load,
                        ),
                      ReviewsPanelLoaded() => _Inbox(
                          state: state,
                          canTriage: canTriage,
                        ),
                      _ => const ListSkeleton(),
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TavoSpace.lg,
        TavoSpace.lg,
        TavoSpace.sm,
        TavoSpace.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('feedback_title'.tr(), style: TavoType.h2),
                const SizedBox(height: 2),
                Text(
                  'feedback_subtitle'.tr(),
                  style: TavoType.bodySmall.copyWith(
                    color: TavoColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          TavoButton.ghost(
            key: const ValueKey<String>('feedback_refresh'),
            label: 'refresh'.tr(),
            size: TavoButtonSize.compact,
            leading: const Icon(Iconsax.refresh, size: 16),
            onPressed: onRefresh,
          ),
        ],
      ),
    );
  }
}

class _Inbox extends StatelessWidget {
  const _Inbox({required this.state, required this.canTriage});

  final ReviewsPanelLoaded state;
  final bool canTriage;

  @override
  Widget build(BuildContext context) {
    final ReviewsPanelCubit cubit = context.read<ReviewsPanelCubit>();

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TavoSpace.lg,
            0,
            TavoSpace.lg,
            TavoSpace.sm,
          ),
          child: _OverviewCard(state: state),
        ),
        _TypeTabs(state: state),
        if (state.status != null || state.hasFilters)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              TavoSpace.lg,
              TavoSpace.sm,
              TavoSpace.lg,
              0,
            ),
            child: Row(
              children: <Widget>[
                if (state.status != null)
                  Flexible(
                    child: TavoStatusPill(
                      label: _statusLabel(state.status!),
                      tone: _statusTone(state.status!),
                      size: TavoPillSize.small,
                    ),
                  ),
                const Spacer(),
                if (state.hasFilters)
                  TavoButton.ghost(
                    key: const ValueKey<String>('feedback_clear_filters'),
                    label: 'feedback_clear_filters'.tr(),
                    size: TavoButtonSize.compact,
                    onPressed: cubit.clearFilters,
                  ),
              ],
            ),
          ),
        Expanded(child: _buildList(context, cubit)),
        if (state.pages > 1) _Pagination(state: state),
      ],
    );
  }

  Widget _buildList(BuildContext context, ReviewsPanelCubit cubit) {
    if (state.items.isEmpty) {
      return RefreshIndicator(
        onRefresh: cubit.refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: <Widget>[
            SizedBox(height: TavoSpace.xxl),
            EmptyStateView(
              icon: switch (state.type) {
                ExperienceType.complaint => Iconsax.warning_2,
                ExperienceType.suggestion => Iconsax.message_text,
                _ => Iconsax.star,
              },
              title: 'feedback_empty_title'.tr(),
              message: state.hasFilters
                  ? 'feedback_empty_filtered'.tr()
                  : 'feedback_empty_message'.tr(),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: cubit.refresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(
          TavoSpace.lg,
          TavoSpace.sm,
          TavoSpace.lg,
          TavoSpace.xl,
        ),
        itemCount: state.items.length,
        separatorBuilder: (_, __) => const SizedBox(height: TavoSpace.sm),
        itemBuilder: (BuildContext context, int index) {
          final ExperienceRating rating = state.items[index];
          return _FeedbackRow(
            key: ValueKey<String>('feedback_row_${rating.id}'),
            rating: rating,
            busy: state.actionId == rating.id,
            onTap: () => _openDetail(context, cubit, rating),
          );
        },
      ),
    );
  }

  void _openDetail(
    BuildContext context,
    ReviewsPanelCubit cubit,
    ExperienceRating rating,
  ) {
    TavoSheet.show<void>(
      context,
      title: feedbackTypeLabel(rating.type),
      subtitle: feedbackGuestLine(rating),
      maxHeightFactor: 0.9,
      child: _FeedbackSheet(
        rating: rating,
        canTriage: canTriage,
        onMarkRead: () => _triage(context, cubit, rating, true),
        onResolve: () => _triage(context, cubit, rating, false),
      ),
    );
  }

  Future<void> _triage(
    BuildContext context,
    ReviewsPanelCubit cubit,
    ExperienceRating rating,
    bool asRead,
  ) async {
    if (asRead) {
      await cubit.markRead(rating);
    } else {
      await cubit.resolve(rating);
    }
    if (!context.mounted) return;
    final ReviewsPanelState after = cubit.state;
    // Only close when the write actually landed; a failure keeps the sheet so
    // the manager can retry without hunting for the row again.
    if (after is ReviewsPanelLoaded && after.actionError == null) {
      Navigator.of(context).maybePop();
    }
  }
}

// ----------------------------------------------------------------- overview

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.state});

  final ReviewsPanelLoaded state;

  @override
  Widget build(BuildContext context) {
    final ExperienceSummary? summary = state.summary;
    if (summary == null) {
      // The summary is decoration: if it failed, say so quietly instead of
      // blocking the inbox behind an error the manager cannot act on.
      return TavoCard(
        child: Text(
          'feedback_overview_unavailable'.tr(),
          style: TavoType.bodySmall.copyWith(
            color: TavoColors.mutedForeground,
          ),
        ),
      );
    }

    return TavoCard(
      variant: TavoCardVariant.warm,
      padding: const EdgeInsets.all(TavoSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _AverageBlock(summary: summary),
              const SizedBox(width: TavoSpace.lg),
              Expanded(child: _CountsBlock(state: state)),
            ],
          ),
          const SizedBox(height: TavoSpace.md),
          for (final MapEntry<String, double?> area in summary.areas.entries)
            _AreaBar(area: area.key, score: area.value),
          if (summary.openComplaints > 0) ...<Widget>[
            const SizedBox(height: TavoSpace.sm),
            _OpenComplaints(
              count: summary.openComplaints,
              onTap: () {
                context.read<ReviewsPanelCubit>()
                  ..setType(ExperienceType.complaint)
                  ..setStatus(ExperienceStatus.unread);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _AverageBlock extends StatelessWidget {
  const _AverageBlock({required this.summary});

  final ExperienceSummary summary;

  @override
  Widget build(BuildContext context) {
    final double? average = summary.average;
    return SizedBox(
      width: 96,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            average == null ? '—' : average.toStringAsFixed(1),
            style: TavoType.display.copyWith(
              fontFeatures: TavoType.tabular,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              for (int star = 1; star <= 5; star++)
                Icon(
                  Iconsax.star_1,
                  size: 12,
                  color: (average ?? 0) >= star
                      ? TavoColors.brand500
                      : TavoColors.input,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            summary.hasScores
                ? 'feedback_scored_count'.tr(
                    namedArgs: <String, String>{'n': '${summary.scored}'},
                  )
                : 'no_ratings_yet'.tr(),
            style: TavoType.micro.copyWith(
              color: TavoColors.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountsBlock extends StatelessWidget {
  const _CountsBlock({required this.state});

  final ReviewsPanelLoaded state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _CountCell(
                label: 'feedback_type_review'.tr(),
                value: state.reviewCount,
                tone: TavoTone.success,
              ),
            ),
            const SizedBox(width: TavoSpace.sm),
            Expanded(
              child: _CountCell(
                label: 'feedback_type_complaint'.tr(),
                value: state.complaintCount,
                tone: TavoTone.danger,
              ),
            ),
          ],
        ),
        const SizedBox(height: TavoSpace.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: _CountCell(
                label: 'feedback_type_suggestion'.tr(),
                value: state.suggestionCount,
                tone: TavoTone.info,
              ),
            ),
            const SizedBox(width: TavoSpace.sm),
            Expanded(
              child: _CountCell(
                label: 'feedback_total'.tr(),
                value: state.allCount,
                tone: TavoTone.neutral,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CountCell extends StatelessWidget {
  const _CountCell({
    required this.label,
    required this.value,
    required this.tone,
  });

  final String label;
  final int value;
  final TavoTone tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TavoSpace.sm,
        vertical: TavoSpace.xs,
      ),
      decoration: BoxDecoration(
        color: TavoColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(TavoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '$value',
            style: TavoType.title.copyWith(
              fontFeatures: TavoType.tabular,
              color: _countToneColor(tone),
            ),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TavoType.micro.copyWith(color: TavoColors.mutedForeground),
          ),
        ],
      ),
    );
  }
}

class _AreaBar extends StatelessWidget {
  const _AreaBar({required this.area, required this.score});

  final String area;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final double value = score ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 82,
            child: Text(
              feedbackAreaLabel(area),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TavoType.micro.copyWith(
                color: TavoColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TavoRadii.xs),
              child: LinearProgressIndicator(
                value: value / 5,
                minHeight: 5,
                backgroundColor: TavoColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(
                  score == null ? TavoColors.input : TavoColors.brand500,
                ),
              ),
            ),
          ),
          const SizedBox(width: TavoSpace.sm),
          SizedBox(
            width: 22,
            child: Text(
              score == null ? '—' : score!.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: TavoType.micro.copyWith(
                fontFeatures: TavoType.tabular,
                color: TavoColors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenComplaints extends StatelessWidget {
  const _OpenComplaints({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TavoPressScale(
      child: Semantics(
        button: true,
        label: 'feedback_open_complaints'.tr(
          namedArgs: <String, String>{'n': '$count'},
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TavoSpace.sm,
              vertical: TavoSpace.xs,
            ),
            decoration: BoxDecoration(
              color: TavoColors.destructiveSolid.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(TavoRadii.md),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Iconsax.warning_2,
                  size: 14,
                  color: TavoColors.destructiveSolid,
                ),
                const SizedBox(width: TavoSpace.xs),
                Expanded(
                  child: Text(
                    'feedback_open_complaints'.tr(
                      namedArgs: <String, String>{'n': '$count'},
                    ),
                    style: TavoType.micro.copyWith(
                      color: TavoColors.destructiveSolid,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Icon(
                  Iconsax.arrow_left_2,
                  size: 14,
                  color: TavoColors.destructiveSolid,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- tabs

class _TypeTabs extends StatelessWidget {
  const _TypeTabs({required this.state});

  final ReviewsPanelLoaded state;

  @override
  Widget build(BuildContext context) {
    final ReviewsPanelCubit cubit = context.read<ReviewsPanelCubit>();
    final List<({ExperienceType? type, String label, int count})> tabs =
        <({ExperienceType? type, String label, int count})>[
      (
        type: null,
        label: 'feedback_tab_all'.tr(),
        count: state.allCount,
      ),
      (
        type: ExperienceType.review,
        label: 'feedback_type_review'.tr(),
        count: state.reviewCount,
      ),
      (
        type: ExperienceType.complaint,
        label: 'feedback_type_complaint'.tr(),
        count: state.complaintCount,
      ),
      (
        type: ExperienceType.suggestion,
        label: 'feedback_type_suggestion'.tr(),
        count: state.suggestionCount,
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TavoSpace.lg,
        ),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: TavoSpace.xs),
        itemBuilder: (BuildContext context, int index) {
          final ({ExperienceType? type, String label, int count}) tab =
              tabs[index];
          final bool selected = state.type == tab.type;
          return _TypeChip(
            key: ValueKey<String>(
              'feedback_tab_${tab.type == null ? 'all' : experienceTypeWire(tab.type!)}',
            ),
            label: tab.label,
            count: tab.count,
            selected: selected,
            onTap: () => cubit.setType(tab.type),
          );
        },
      ),
    );
  }
}

class _TypeChip extends StatelessWidget {
  const _TypeChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TavoPressScale(
      child: Semantics(
        button: true,
        selected: selected,
        label: '$label ($count)',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TavoSpace.md,
            ),
            decoration: BoxDecoration(
              color: selected ? TavoColors.foreground : TavoColors.muted,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: selected ? TavoColors.foreground : TavoColors.border,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  label,
                  style: TavoType.label.copyWith(
                    color: selected
                        ? TavoColors.background
                        : TavoColors.foreground,
                  ),
                ),
                const SizedBox(width: TavoSpace.xs),
                Container(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? TavoColors.background.withValues(alpha: 0.16)
                        : TavoColors.background,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TavoType.micro.copyWith(
                      fontFeatures: TavoType.tabular,
                      color: selected
                          ? TavoColors.background
                          : TavoColors.mutedForeground,
                    ),
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

// --------------------------------------------------------------------- rows

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({
    super.key,
    required this.rating,
    required this.busy,
    required this.onTap,
  });

  final ExperienceRating rating;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String name = rating.displayName;
    return TavoCard(
      onTap: busy ? null : onTap,
      padding: const EdgeInsets.all(TavoSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _typeTone(rating.type).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(TavoRadii.lg),
            ),
            child: Icon(
              feedbackTypeIcon(rating.type),
              size: 17,
              color: _typeTone(rating.type),
            ),
          ),
          const SizedBox(width: TavoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        name.isEmpty ? 'feedback_guest'.tr() : name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TavoType.label,
                      ),
                    ),
                    const SizedBox(width: TavoSpace.xs),
                    TavoStatusPill(
                      label: _statusLabel(rating.status),
                      tone: _statusTone(rating.status),
                      size: TavoPillSize.small,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  feedbackGuestLine(rating),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TavoType.micro.copyWith(
                    color: TavoColors.mutedForeground,
                  ),
                ),
                if (rating.headline.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    rating.headline,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TavoType.bodySmall,
                  ),
                ],
                const SizedBox(height: 6),
                Row(
                  children: <Widget>[
                    _MiniTag(
                      label: feedbackTypeLabel(rating.type),
                      color: _typeTone(rating.type),
                    ),
                    if (rating.hasScores) ...<Widget>[
                      const SizedBox(width: TavoSpace.xs),
                      _MiniTag(
                        label: rating.overall!.toStringAsFixed(1),
                        color: TavoColors.foreground,
                        icon: Iconsax.star_1,
                      ),
                    ],
                    if (busy) ...<Widget>[
                      const SizedBox(width: TavoSpace.xs),
                      const SizedBox(
                        width: 10,
                        height: 10,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color, this.icon});

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: TavoSpace.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TavoRadii.sm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 10, color: color),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: TavoType.micro.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------- detail

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({
    required this.rating,
    required this.canTriage,
    required this.onMarkRead,
    required this.onResolve,
  });

  final ExperienceRating rating;
  final bool canTriage;
  final Future<void> Function() onMarkRead;
  final Future<void> Function() onResolve;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    await action();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final ExperienceRating rating = widget.rating;

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    rating.displayName.isEmpty
                        ? 'feedback_guest'.tr()
                        : rating.displayName,
                    style: TavoType.title,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    feedbackGuestLine(rating),
                    style: TavoType.micro.copyWith(
                      color: TavoColors.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            TavoStatusPill(
              label: _statusLabel(rating.status),
              tone: _statusTone(rating.status),
            ),
          ],
        ),
        const SizedBox(height: TavoSpace.lg),
        _FactRow(
          icon: Iconsax.grid_1,
          label: 'feedback_table'.tr(),
          value: rating.tableCode.isEmpty ? '—' : rating.tableCode,
        ),
        _FactRow(
          icon: Iconsax.people,
          label: 'feedback_waiter'.tr(),
          value: (rating.waiterName ?? '').isEmpty
              ? '—'
              : rating.waiterName!,
        ),
        _FactRow(
          icon: Iconsax.clock,
          label: 'feedback_received'.tr(),
          value: feedbackTime(rating.createdAt),
        ),
        if (rating.resolvedAt != null)
          _FactRow(
            icon: Iconsax.tick_circle,
            label: 'feedback_resolved_at'.tr(),
            value: feedbackTime(rating.resolvedAt),
          ),
        if (rating.hasScores) ...<Widget>[
          const SizedBox(height: TavoSpace.md),
          Text(
            'feedback_scores'.tr(),
            style: TavoType.label.copyWith(color: TavoColors.mutedForeground),
          ),
          const SizedBox(height: TavoSpace.xs),
          for (final MapEntry<String, int> entry in rating.scoredAreas.entries)
            _ScoreRow(area: entry.key, score: entry.value),
        ] else ...<Widget>[
          const SizedBox(height: TavoSpace.md),
          Text(
            'feedback_no_scores'.tr(),
            style: TavoType.micro.copyWith(
              color: TavoColors.mutedForeground,
            ),
          ),
        ],
        if (rating.subject.isNotEmpty) ...<Widget>[
          const SizedBox(height: TavoSpace.md),
          Text(
            'feedback_subject'.tr(),
            style: TavoType.label.copyWith(color: TavoColors.mutedForeground),
          ),
          const SizedBox(height: 2),
          Text(rating.subject, style: TavoType.bodySmall),
        ],
        if (rating.comment.isNotEmpty) ...<Widget>[
          const SizedBox(height: TavoSpace.md),
          Text(
            'feedback_comment'.tr(),
            style: TavoType.label.copyWith(color: TavoColors.mutedForeground),
          ),
          const SizedBox(height: 2),
          Text(rating.comment, style: TavoType.bodySmall),
        ],
        if (rating.waiterMessage.isNotEmpty) ...<Widget>[
          const SizedBox(height: TavoSpace.md),
          Text(
            'feedback_waiter_message'.tr(),
            style: TavoType.label.copyWith(color: TavoColors.mutedForeground),
          ),
          const SizedBox(height: 2),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TavoSpace.sm),
            decoration: BoxDecoration(
              color: TavoColors.muted,
              borderRadius: BorderRadius.circular(TavoRadii.md),
            ),
            child: Text(rating.waiterMessage, style: TavoType.bodySmall),
          ),
        ],
        if (rating.photoUrl.isNotEmpty) ...<Widget>[
          const SizedBox(height: TavoSpace.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(TavoRadii.lg),
            child: Image.network(
              rating.photoUrl,
              height: 180,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        ],
        const SizedBox(height: TavoSpace.xl),
        if (!widget.canTriage)
          TavoStatusPill(
            label: 'feedback_read_only'.tr(),
            tone: TavoTone.neutral,
            size: TavoPillSize.small,
          )
        else
          Row(
            children: <Widget>[
              if (rating.status == ExperienceStatus.unread)
                Expanded(
                  child: TavoButton.secondary(
                    key: const ValueKey<String>('feedback_mark_read'),
                    label: 'feedback_mark_read'.tr(),
                    expand: true,
                    isLoading: _busy,
                    onPressed: () => _run(widget.onMarkRead),
                  ),
                ),
              if (rating.status != ExperienceStatus.resolved) ...<Widget>[
                if (rating.status == ExperienceStatus.unread)
                  const SizedBox(width: TavoSpace.sm),
                Expanded(
                  child: TavoButton.primary(
                    key: const ValueKey<String>('feedback_resolve'),
                    label: 'feedback_resolve'.tr(),
                    expand: true,
                    isLoading: _busy,
                    leading: const Icon(Iconsax.tick_circle, size: 16),
                    onPressed: () => _run(widget.onResolve),
                  ),
                ),
              ] else
                Expanded(
                  child: TavoButton.ghost(
                    label: 'close'.tr(),
                    expand: true,
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

class _FactRow extends StatelessWidget {
  const _FactRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 14, color: TavoColors.mutedForeground),
          const SizedBox(width: TavoSpace.xs),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: TavoType.micro.copyWith(
                color: TavoColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TavoType.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreRow extends StatelessWidget {
  const _ScoreRow({required this.area, required this.score});

  final String area;
  final int score;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 100,
            child: Text(
              feedbackAreaLabel(area),
              style: TavoType.micro.copyWith(
                color: TavoColors.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TavoRadii.xs),
              child: LinearProgressIndicator(
                value: score / 5,
                minHeight: 6,
                backgroundColor: TavoColors.muted,
                valueColor: AlwaysStoppedAnimation<Color>(
                  score >= 4
                      ? TavoColors.success
                      : score >= 3
                          ? TavoColors.warning
                          : TavoColors.destructiveSolid,
                ),
              ),
            ),
          ),
          const SizedBox(width: TavoSpace.sm),
          Text(
            '$score/5',
            style: TavoType.micro.copyWith(
              fontFeatures: TavoType.tabular,
              color: TavoColors.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- pagination

class _Pagination extends StatelessWidget {
  const _Pagination({required this.state});

  final ReviewsPanelLoaded state;

  @override
  Widget build(BuildContext context) {
    final ReviewsPanelCubit cubit = context.read<ReviewsPanelCubit>();
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TavoSpace.lg,
        0,
        TavoSpace.lg,
        TavoSpace.md,
      ),
      child: Row(
        children: <Widget>[
          TavoButton.ghost(
            label: 'feedback_previous'.tr(),
            size: TavoButtonSize.compact,
            leading: const Icon(Iconsax.arrow_right_2, size: 15),
            onPressed:
                state.page > 1 ? () => cubit.goToPage(state.page - 1) : null,
          ),
          Expanded(
            child: Text(
              'page_of'.tr(
                namedArgs: <String, String>{
                  'i': '${state.page}',
                  'n': '${state.pages}',
                },
              ),
              textAlign: TextAlign.center,
              style: TavoType.micro.copyWith(
                color: TavoColors.mutedForeground,
              ),
            ),
          ),
          TavoButton.ghost(
            label: 'feedback_next'.tr(),
            size: TavoButtonSize.compact,
            trailing: const Icon(Iconsax.arrow_left_2, size: 15),
            onPressed: state.page < state.pages
                ? () => cubit.goToPage(state.page + 1)
                : null,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ helpers

String feedbackTypeLabel(ExperienceType type) => switch (type) {
      ExperienceType.review => 'feedback_type_review'.tr(),
      ExperienceType.complaint => 'feedback_type_complaint'.tr(),
      ExperienceType.suggestion => 'feedback_type_suggestion'.tr(),
    };

IconData feedbackTypeIcon(ExperienceType type) => switch (type) {
      ExperienceType.review => Iconsax.star_1,
      ExperienceType.complaint => Iconsax.warning_2,
      ExperienceType.suggestion => Iconsax.message_text,
    };

Color _typeTone(ExperienceType type) => switch (type) {
      ExperienceType.review => TavoColors.success,
      ExperienceType.complaint => TavoColors.destructiveSolid,
      ExperienceType.suggestion => TavoColors.info,
    };

Color _countToneColor(TavoTone tone) => switch (tone) {
      TavoTone.success => TavoColors.success,
      TavoTone.danger => TavoColors.destructiveSolid,
      TavoTone.info => TavoColors.info,
      TavoTone.brand => TavoColors.brand700,
      TavoTone.warning => TavoColors.warning,
      TavoTone.neutral => TavoColors.foreground,
    };

String _statusLabel(ExperienceStatus status) => switch (status) {
      ExperienceStatus.unread => 'feedback_status_unread'.tr(),
      ExperienceStatus.read => 'feedback_status_read'.tr(),
      ExperienceStatus.resolved => 'feedback_status_resolved'.tr(),
    };

TavoTone _statusTone(ExperienceStatus status) => switch (status) {
      ExperienceStatus.unread => TavoTone.warning,
      ExperienceStatus.read => TavoTone.info,
      ExperienceStatus.resolved => TavoTone.success,
    };

String feedbackAreaLabel(String area) => switch (area) {
      'restaurant' => 'rating_restaurant'.tr(),
      'waiter' => 'rating_waiter'.tr(),
      'food' => 'rating_food'.tr(),
      'speed' => 'rating_service_speed'.tr(),
      'cleanliness' => 'rating_cleanliness'.tr(),
      _ => area,
    };

/// "Table T1-1 · 26 Oct 14:32" — who and when, in one line.
String feedbackGuestLine(ExperienceRating rating) {
  final List<String> parts = <String>[
    if (rating.tableCode.isNotEmpty)
      '${'feedback_table'.tr()} ${rating.tableCode}',
    feedbackTime(rating.createdAt),
  ];
  return parts.join(' · ');
}

/// Locale-neutral on purpose: an English month name inside an Arabic panel is
/// the kind of detail that makes a UI feel translated rather than built.
String feedbackTime(DateTime? value) {
  if (value == null) return '—';
  return DateFormat('d/M · HH:mm', 'en').format(value);
}
