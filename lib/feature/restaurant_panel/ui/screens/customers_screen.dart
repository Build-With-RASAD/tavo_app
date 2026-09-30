// lib/feature/restaurant_panel/ui/screens/customers_screen.dart
//
// Wave D (Task 18): real customers CRM list + detail. Replaces the Task 11
// placeholder in place (same class name + constructor) so `shell_defaults.dart`
// keeps compiling; the `customers` hub entry is swapped via
// `registerCustomersModule()`.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:get_it/get_it.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_customers/data/model/customer_models.dart';
import 'package:tavo/feature/panel_customers/data/repo/customers_panel_repo.dart';
import 'package:tavo/feature/panel_customers/ui/logic/customer_detail_cubit.dart';
import 'package:tavo/feature/panel_customers/ui/logic/customers_panel_cubit.dart';
import 'package:tavo/feature/panel_customers/ui/screens/customer_detail_screen.dart';

/// Staff panel customers CRM: search field over the paged customer list;
/// row tap loads the profile + histories, then pushes the detail screen.
///
/// Builds its own [CustomersPanelCubit] through get_it (mirroring
/// `ReviewsScreen`) and drives the three async states with [ListSkeleton] /
/// [ErrorStateView] / content. Read-only domain — no role gating, visible
/// to every shell user.
class CustomersScreen extends StatelessWidget {
  const CustomersScreen(
      {super.key, required this.restaurantId, required this.venue});

  final String restaurantId;
  final StaffRestaurant venue;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CustomersPanelCubit(
        GetIt.instance<CustomersPanelRepo>(),
        restaurantId: restaurantId,
      )..load(),
      child: BlocBuilder<CustomersPanelCubit, CustomersPanelState>(
        builder: (context, state) {
          final cubit = context.read<CustomersPanelCubit>();
          return Scaffold(
            body: SafeArea(
                child: _buildBody(context, cubit, state)),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    CustomersPanelCubit cubit,
    CustomersPanelState state,
  ) {
    if (state is CustomersPanelError) {
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
    if (state is CustomersPanelLoaded) {
      return Column(
        children: [
          _buildHeader(context, cubit),
          Expanded(child: _buildList(context, cubit, state)),
          _buildPagination(context, cubit, state),
        ],
      );
    }
    // CustomersPanelInitial / CustomersPanelLoading.
    return const ListSkeleton();
  }

  Widget _buildHeader(BuildContext context, CustomersPanelCubit cubit) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'customers'.tr(),
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12.h),
          TextField(
            key: const Key('customer_search'),
            textInputAction: TextInputAction.search,
            onSubmitted: cubit.search,
            decoration: InputDecoration(
              labelText: 'search_customers'.tr(),
              prefixIcon: const Icon(Icons.search),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    CustomersPanelCubit cubit,
    CustomersPanelLoaded state,
  ) {
    if (state.customers.isEmpty) {
      return EmptyStateView(
        icon: Icons.people_outline,
        title: 'empty_customers_title'.tr(),
        message: 'empty_customers_message'.tr(),
        onRetry: cubit.load,
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        itemCount: state.customers.length,
        itemBuilder: (context, index) {
          final customer = state.customers[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _CustomerCard(
              key: ValueKey('customer_card_${customer.key}'),
              customer: customer,
              onTap: () => _openDetail(context, customer.key),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagination(
    BuildContext context,
    CustomersPanelCubit cubit,
    CustomersPanelLoaded state,
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

  /// Awaits the detail cubit first; only pushes when the profile + histories
  /// loaded — failures surface a SnackBar and stay on the list.
  Future<void> _openDetail(BuildContext context, String key) async {
    final detailCubit = CustomerDetailCubit(
      GetIt.instance<CustomersPanelRepo>(),
      restaurantId: restaurantId,
    );
    try {
      await detailCubit.load(key);
    } catch (_) {
      // [load] never throws (failures emit CustomerDetailError), but a
      // defensive catch keeps the list on screen no matter what.
    }
    final loaded = detailCubit.state;
    await detailCubit.close();
    if (!context.mounted) return;
    if (loaded is CustomerDetailLoaded) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CustomerDetailScreen(detail: loaded.detail),
        ),
      );
    } else if (loaded is CustomerDetailError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loaded.message)),
      );
    }
  }
}

/// One customer row: name, phone + counts subtitle, total-spent trailing.
/// A [Material] + [InkWell] pair (not `ListTile` in a decorated box) so ink
/// splashes stay visible and the debug ListTile-background assertion never
/// fires.
class _CustomerCard extends StatelessWidget {
  const _CustomerCard({super.key, required this.customer, required this.onTap});

  final PanelCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16.r),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      '${customer.phone}\n${customer.orderCount} · ${customer.reservationCount}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              Text(
                '${'total_spent'.tr()}: ${formatCustomerTotal(customer.totalSpent)}',
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
