// lib/feature/restaurant_panel/ui/screens/reviews_screen.dart
//
// Wave C (Task 14): real reviews list + owner responses. Replaces the Task 11
// placeholder in place (same class name + constructor) so `shell_defaults.dart`
// keeps compiling; the `reviews` hub entry is swapped via
// `registerReviewsModule()`.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_reviews/data/model/experience_summary.dart';
import 'package:tavo/feature/panel_reviews/data/model/review_models.dart';
import 'package:tavo/feature/panel_reviews/data/repo/reviews_panel_repo.dart';
import 'package:tavo/feature/panel_reviews/ui/logic/reviews_panel_cubit.dart';

/// Staff panel reviews: rating filter chips over the paged review list, with
/// role-gated owner responses through a bottom sheet.
///
/// Builds its own [ReviewsPanelCubit] through get_it (mirroring
/// `PanelMenuScreen`) and drives the three async states with [ListSkeleton] /
/// [ErrorStateView] / content. Respond failures surface as a SnackBar while
/// every row stays on screen (`ReviewsPanelLoaded.actionError`).
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen(
      {super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  bool _canRespond() =>
      venue.role == 'owner' ||
      venue.role == 'manager' ||
      venue.permissions.contains('full_access') ||
      venue.permissions.contains('manage_reviews');

  @override
  Widget build(BuildContext context) {
    final manageable = _canRespond();
    return BlocProvider(
      create: (_) => ReviewsPanelCubit(
        GetIt.instance<ReviewsPanelRepo>(),
        restaurantId: restaurantId,
      )..load(),
      child: BlocConsumer<ReviewsPanelCubit, ReviewsPanelState>(
        listener: (context, state) {
          if (state is ReviewsPanelLoaded && state.actionError != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.actionError!),
                backgroundColor: const Color(0xFFC62828),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                margin: EdgeInsets.all(16.w),
              ),
            );
          }
        },
        builder: (context, state) {
          final cubit = context.read<ReviewsPanelCubit>();
          return Scaffold(
            body: SafeArea(
                child: _buildBody(context, cubit, state, manageable)),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    ReviewsPanelCubit cubit,
    ReviewsPanelState state,
    bool manageable,
  ) {
    if (state is ReviewsPanelError) {
      return Column(
        children: [
          Expanded(
            child: ErrorStateView(message: state.message, onRetry: cubit.load),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: cubit.load,
          ),
          SizedBox(height: 8.h),
        ],
      );
    }
    if (state is ReviewsPanelLoaded) {
      return Column(
        children: [
          _buildHeader(context, state.summary),
          _buildRatingChips(cubit, state.filterRating),
          Expanded(child: _buildList(context, cubit, state, manageable)),
          _buildPagination(context, cubit, state),
        ],
      );
    }
    // ReviewsPanelInitial / ReviewsPanelLoading.
    return const ListSkeleton();
  }

  Widget _buildHeader(BuildContext context, ExperienceSummary? summary) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'reviews'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),
          _RatingSummaryCard(summary: summary),
        ],
      ),
    );
  }

  /// Server-side rating filter chips (`all` = no `&rating=` param).
  Widget _buildRatingChips(ReviewsPanelCubit cubit, int? filterRating) {
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: ChoiceChip(
                key: const Key('filter_rating_all'),
                label: Text('filter_rating_all'.tr()),
                selected: filterRating == null,
                onSelected: (_) => cubit.setRating(null),
              ),
            ),
            for (var rating = 5; rating >= 1; rating--)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: ChoiceChip(
                  key: Key('filter_rating_$rating'),
                  label: Text('$rating ★'),
                  selected: filterRating == rating,
                  onSelected: (_) => cubit.setRating(rating),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    ReviewsPanelCubit cubit,
    ReviewsPanelLoaded state,
    bool manageable,
  ) {
    if (state.reviews.isEmpty) {
      return EmptyStateView(
        icon: Icons.star_border,
        title: 'empty_reviews_title'.tr(),
        message: 'empty_reviews_message'.tr(),
        onRetry: cubit.load,
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        itemCount: state.reviews.length,
        itemBuilder: (context, index) {
          final review = state.reviews[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _ReviewCard(
              key: ValueKey('review_card_${review.id}'),
              review: review,
              acting: state.actionId == review.id,
              manageable: manageable,
              onRespond: () => _openRespondSheet(context, cubit, review),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagination(
    BuildContext context,
    ReviewsPanelCubit cubit,
    ReviewsPanelLoaded state,
  ) {
    if (state.pages <= 1) return const SizedBox.shrink();
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 12.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed:
                state.page > 1 ? () => cubit.goToPage(state.page - 1) : null,
          ),
          Text(
            'page_of'.tr(
                namedArgs: {'i': '${state.page}', 'n': '${state.pages}'}),
            style: textTheme.bodySmall,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: state.page < state.pages
                ? () => cubit.goToPage(state.page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  void _openRespondSheet(
    BuildContext context,
    ReviewsPanelCubit cubit,
    PanelReview review,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RespondSheet(cubit: cubit, reviewId: review.id),
    );
  }
}

/// One review row: stars, comment, author, date and — when the role may
/// respond — the owner-response block or the respond action.
class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    super.key,
    required this.review,
    required this.acting,
    required this.manageable,
    required this.onRespond,
  });

  final PanelReview review;
  final bool acting;
  final bool manageable;
  final VoidCallback onRespond;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final answered =
        review.ownerResponse != null && review.ownerResponse!.isNotEmpty;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 1; i <= 5; i++)
                Icon(
                  Icons.star,
                  size: 16,
                  color: i <= review.rating
                      ? Colors.amber
                      : Colors.grey.shade300,
                ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  review.userName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall,
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(review.comment, style: textTheme.bodyMedium),
          SizedBox(height: 4.h),
          Text(review.createdAt, style: textTheme.bodySmall),
          SizedBox(height: 8.h),
          if (answered)
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(10.r),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'responded'.tr(),
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2.h),
                  Text(review.ownerResponse!, style: textTheme.bodyMedium),
                ],
              ),
            )
          else ...[
            Text(
              'no_response_yet'.tr(),
              style: textTheme.bodySmall,
            ),
            SizedBox(height: 4.h),
            if (acting)
              const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (manageable)
              TextButton.icon(
                key: ValueKey('respond_${review.id}'),
                icon: const Icon(Icons.reply_outlined, size: 18),
                label: Text('respond_to_review'.tr()),
                onPressed: onRespond,
              ),
          ],
        ],
      ),
    );
  }
}

/// Owner-response bottom sheet: a text field plus submit.
class _RespondSheet extends StatefulWidget {
  const _RespondSheet({required this.cubit, required this.reviewId});

  final ReviewsPanelCubit cubit;
  final String reviewId;

  @override
  State<_RespondSheet> createState() => _RespondSheetState();
}

class _RespondSheetState extends State<_RespondSheet> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'respond_to_review'.tr(),
            style:
                textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16.h),
          TextField(
            key: const Key('response_field'),
            controller: _controller,
            maxLines: 3,
            decoration:
                InputDecoration(labelText: 'write_response'.tr()),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('submit_response'),
              onPressed: _submit,
              child: Text('submit_response'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.cubit.respond(widget.reviewId, text);
    Navigator.of(context).pop();
  }
}

/// The real business rating: a 0–5 aggregate of the five guest-rated areas
/// plus the waiter leaderboard, read from `GET /experience-ratings/summary`.
///
/// Deliberately dark: it is the one "scoreboard" on the screen, and the
/// contrast keeps the gold number readable in a bright kitchen. A venue with
/// no guest ratings yet gets an honest empty line instead of a fake 0.0.
class _RatingSummaryCard extends StatelessWidget {
  const _RatingSummaryCard({required this.summary});

  final ExperienceSummary? summary;

  static const _labels = {
    'restaurant': 'rating_restaurant',
    'waiter': 'rating_waiter',
    'food': 'rating_food',
    'speed': 'rating_service_speed',
    'cleanliness': 'rating_cleanliness',
  };

  @override
  Widget build(BuildContext context) {
    final data = summary;
    if (data == null || !data.hasScores) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xFF15181D),
          borderRadius: BorderRadius.circular(18.r),
        ),
        child: Row(
          children: [
            const Icon(Iconsax.star, size: 18, color: Color(0xFF6B7280)),
            SizedBox(width: 8.w),
            Expanded(
              child: Text(
                'no_ratings_yet'.tr(),
                style: TextStyle(
                  fontSize: 12.sp,
                  color: const Color(0xFF9AA0A6),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final average = data.average ?? 0;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: const Color(0xFF15181D),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        average.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: 36.sp,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFFE7CD6A),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(bottom: 4.h, left: 2.w),
                        child: Text(
                          '/ 5',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: const Color(0xFF9AA0A6),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      for (var i = 0; i < 5; i++)
                        Icon(
                          average >= i + 0.75
                              ? Iconsax.star_1
                              : Iconsax.star,
                          size: 12.sp,
                          color: average >= i + 0.75
                              ? const Color(0xFFE7CD6A)
                              : const Color(0xFF3A4048),
                        ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'ratings_count'
                        .tr(args: ['${data.scored > 0 ? data.scored : data.count}']),
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: const Color(0xFF9AA0A6),
                    ),
                  ),
                  if (data.openComplaints > 0) ...[
                    SizedBox(height: 8.h),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFC62828).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999.r),
                      ),
                      child: Text(
                        '${data.openComplaints} ${'open_complaints'.tr()}',
                        style: TextStyle(
                          fontSize: 9.sp,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFFFF8A80),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  children: [
                    for (final key in ExperienceSummary.areaKeys)
                      _AreaBar(
                        label: _labels[key]!.tr(),
                        value: data.areas[key],
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (data.waiters.isNotEmpty) ...[
            SizedBox(height: 12.h),
            Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
            SizedBox(height: 10.h),
            Row(
              children: [
                const Icon(Iconsax.medal_star,
                    size: 14, color: Color(0xFFE7CD6A)),
                SizedBox(width: 6.w),
                Text(
                  'waiter_leaderboard'.tr(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFF5F2EA),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Wrap(
              spacing: 6.w,
              runSpacing: 6.h,
              children: [
                for (final waiter in data.waiters.take(4))
                  _WaiterChip(waiter: waiter),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// One area average: label, 4px bar and the numeric value. A missing area
/// draws an empty track (no score yet), never a zero-length "bad" bar.
class _AreaBar extends StatelessWidget {
  const _AreaBar({required this.label, required this.value});

  final String label;
  final double? value;

  @override
  Widget build(BuildContext context) {
    final score = value;
    final ratio = score == null ? 0.0 : (score / 5).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.only(bottom: 6.h),
      child: Row(
        children: [
          SizedBox(
            width: 74.w,
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9.sp,
                color: const Color(0xFF9AA0A6),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(99.r),
              child: Container(
                height: 4.h,
                color: const Color(0xFF2A2F37),
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: ratio,
                  child: Container(
                    color: score == null
                        ? const Color(0xFF2A2F37)
                        : const Color(0xFFE7CD6A),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: 6.w),
          SizedBox(
            width: 20.w,
            child: Text(
              score == null ? '—' : score.toStringAsFixed(1),
              textAlign: TextAlign.end,
              style: TextStyle(
                fontSize: 9.sp,
                fontWeight: FontWeight.w700,
                color: score == null
                    ? const Color(0xFF6B7280)
                    : const Color(0xFFE7CD6A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WaiterChip extends StatelessWidget {
  const _WaiterChip({required this.waiter});

  final WaiterScore waiter;

  @override
  Widget build(BuildContext context) {
    final name = waiter.name.isEmpty ? '—' : waiter.name;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E232A),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: const Color(0xFF2A2F37)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFF5F2EA),
            ),
          ),
          SizedBox(width: 6.w),
          Text(
            waiter.average.toStringAsFixed(1),
            style: TextStyle(
              fontSize: 10.sp,
              fontWeight: FontWeight.w800,
              color: const Color(0xFFE7CD6A),
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            '(${waiter.count})',
            style: TextStyle(
              fontSize: 9.sp,
              color: const Color(0xFF9AA0A6),
            ),
          ),
        ],
      ),
    );
  }
}
