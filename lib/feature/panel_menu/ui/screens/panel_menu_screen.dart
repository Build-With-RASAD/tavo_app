// lib/feature/panel_menu/ui/screens/panel_menu_screen.dart
//
// The menu control room. One screen answers the four questions a manager
// actually has:
//
//   • what is on the menu right now, and what is hidden?
//   • which category needs attention (and how many dishes live in it)?
//   • where is the dish I just edited? (server-side search, honest pager)
//   • can I fix the name/price/photo without leaving the list?
//
// Layout: title → search + view toggle → category rail → status chips →
// dense photo-led rows (default) or a 2-up grid → pager. The editor opens as
// a full-height sheet; read-only staff get the same sheet without the form.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';
import 'package:tavo/feature/panel_menu/data/repo/menu_panel_repo.dart';
import 'package:tavo/feature/panel_menu/ui/logic/panel_menu_cubit.dart';
import 'package:tavo/feature/panel_menu/ui/screens/menu_categories_sheet.dart';
import 'package:tavo/feature/panel_menu/ui/screens/menu_item_sheet.dart';
import 'package:tavo/feature/panel_menu/ui/widgets/menu_widgets.dart';

enum _MenuView { list, grid }

/// Staff panel menu — categories, server-side filters and the item editor.
class PanelMenuScreen extends StatefulWidget {
  const PanelMenuScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
    this.canManage,
    this.repo,
    this.searchDebounce = const Duration(milliseconds: 320),
  });

  final String restaurantId;
  final StaffRestaurant venue;

  /// Explicit permission gate from the hub. Merged with the venue's own
  /// owner/manager/full_access/`manage_menu` flags.
  final bool Function()? canManage;

  /// Test/DI override; production resolves the singleton.
  final MenuPanelRepo? repo;

  /// Debounce before a keystroke hits the server.
  final Duration searchDebounce;

  @override
  State<PanelMenuScreen> createState() => _PanelMenuScreenState();
}

class _PanelMenuScreenState extends State<PanelMenuScreen> {
  final TextEditingController _search = TextEditingController();
  _MenuView _view = _MenuView.list;

  bool get _canManage =>
      (widget.canManage?.call() ?? false) ||
      widget.venue.canManage ||
      widget.venue.permissions.contains('manage_menu');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _toast(String message, {bool error = false}) {
    if (!mounted) return;
    final Color background =
        error ? TavoColors.destructiveSolid : TavoColors.foreground;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TavoType.bodySmall.copyWith(color: TavoColors.background),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TavoRadii.md),
          ),
          margin: const EdgeInsets.all(TavoSpace.lg),
        ),
      );
  }

  /// `category_not_empty` is the cubit's sentinel for the server's guard;
  /// every other string is already a readable API error.
  String _errorText(String raw) => raw == 'category_not_empty'
      ? 'category_not_empty_hint'.tr()
      : raw;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PanelMenuCubit(
        widget.repo ?? getIt<MenuPanelRepo>(),
        restaurantId: widget.restaurantId,
        canManage: () => _canManage,
        searchDebounce: widget.searchDebounce,
      )..load(),
      child: BlocConsumer<PanelMenuCubit, PanelMenuState>(
        listener: (BuildContext context, PanelMenuState state) {
          if (state is! PanelMenuLoaded) return;
          final String? error = state.actionError;
          if (error != null) {
            _toast(_errorText(error), error: true);
            context.read<PanelMenuCubit>().clearActionError();
          }
        },
        builder: (BuildContext context, PanelMenuState state) {
          final PanelMenuCubit cubit = context.read<PanelMenuCubit>();
          return Scaffold(
            backgroundColor: TavoColors.background,
            body: SafeArea(
              child: Column(
                children: <Widget>[
                  _header(context, state),
                  if (state is PanelMenuLoaded)
                    _controls(context, cubit, state)
                  else
                    const SizedBox.shrink(),
                  Expanded(
                    child: switch (state) {
                      PanelMenuError() => MenuErrorState(
                          message: state.message,
                          onRetry: cubit.load,
                        ),
                      PanelMenuLoaded() => _content(context, cubit, state),
                      _ => const MenuSkeletonList(),
                    },
                  ),
                  if (state is PanelMenuLoaded && state.total > 0)
                    _pager(cubit, state),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(BuildContext context, PanelMenuState state) {
    final bool loaded = state is PanelMenuLoaded;
    final int items = loaded ? state.allCount : 0;
    final int categories = loaded ? state.categories.length : 0;

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TavoSpace.gutter,
        TavoSpace.md,
        TavoSpace.gutter,
        TavoSpace.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'menu_eyebrow'.tr().toUpperCase(),
                  style: TavoType.overline.copyWith(
                    color: TavoColors.mutedForeground,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: <Widget>[
                    Text(
                      'menu'.tr(),
                      style: TavoType.h2.copyWith(
                        color: TavoColors.foreground,
                      ),
                    ),
                    if (loaded && state.refreshing) ...<Widget>[
                      const SizedBox(width: TavoSpace.sm),
                      TavoStatusPill(
                        label: 'menu_updating'.tr(),
                        tone: TavoTone.brand,
                        size: TavoPillSize.small,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  loaded
                      ? 'menu_subtitle'.tr(namedArgs: {
                          'items': '$items',
                          'categories': '$categories',
                        })
                      : 'menu'.tr(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TavoType.caption.copyWith(
                    color: TavoColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          if (_canManage) ...<Widget>[
            const SizedBox(width: TavoSpace.sm),
            TavoButton.primary(
              key: const ValueKey<String>('menu_add_item'),
              label: 'add_item'.tr(),
              size: TavoButtonSize.compact,
              leading: const Icon(Iconsax.add, size: 18),
              onPressed: loaded
                  ? () => _openItem(context, context.read<PanelMenuCubit>(),
                      state, null)
                  : null,
            ),
          ],
        ],
      ),
    );
  }

  Widget _controls(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
  ) {
    final String locale = context.locale.languageCode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TavoSpace.gutter,
            TavoSpace.xs,
            TavoSpace.gutter,
            TavoSpace.sm,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: MenuSearchField(
                  controller: _search,
                  hint: 'menu_search_hint'.tr(),
                  onChanged: cubit.setQuery,
                  onSubmitted: (_) => cubit.submitSearch(),
                  onClear: () {
                    _search.clear();
                    cubit.setQuery('');
                    cubit.submitSearch();
                  },
                ),
              ),
              const SizedBox(width: TavoSpace.sm),
              _ViewToggle(
                grid: _view == _MenuView.grid,
                onChanged: (_MenuView view) => setState(() => _view = view),
              ),
            ],
          ),
        ),
        _categoryRail(context, cubit, state, locale),
        SizedBox(height: TavoSpace.xs),
        _statusRail(cubit, state),
        const SizedBox(height: TavoSpace.xxs),
      ],
    );
  }

  Widget _categoryRail(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
    String locale,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
            TavoSpace.gutter,
            0,
            TavoSpace.gutter,
            TavoSpace.xs,
          ),
          child: Row(
            children: <Widget>[
              Text(
                'menu_categories'.tr(),
                style: TavoType.overline.copyWith(
                  color: TavoColors.mutedForeground,
                  letterSpacing: 1.1,
                ),
              ),
              const Spacer(),
              if (_canManage)
                Semantics(
                  button: true,
                  label: 'manage_categories'.tr(),
                  child: InkWell(
                    key: const ValueKey<String>('manage_categories'),
                    borderRadius: BorderRadius.circular(TavoRadii.sm),
                    onTap: () => _openCategories(context, cubit),
                    child: Padding(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: TavoSpace.sm,
                        vertical: TavoSpace.xxs,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Text(
                            'manage'.tr(),
                            style: TavoType.caption.copyWith(
                              color: TavoColors.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(
                            Iconsax.setting_2,
                            size: 14,
                            color: TavoColors.foreground,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 42,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TavoSpace.gutter,
            ),
            children: <Widget>[
              Padding(
                padding: const EdgeInsetsDirectional.only(end: TavoSpace.sm),
                child: MenuFilterChip(
                  key: const ValueKey<String>('category_chip_all'),
                  label: 'category_all'.tr(),
                  count: state.allCount,
                  selected: state.selectedCategoryId == null,
                  onTap: () => cubit.setCategory(null),
                ),
              ),
              for (final PanelMenuCategory category in state.categories)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(end: TavoSpace.sm),
                  child: MenuFilterChip(
                    key: ValueKey<String>('category_chip_${category.id}'),
                    label: menuCategoryName(category, locale),
                    count: category.itemCount,
                    selected: state.selectedCategoryId == category.id,
                    onTap: () => cubit.setCategory(category.id),
                  ),
                ),
              if (_canManage)
                _AddCategoryChip(
                  onTap: () => _openCategories(context, cubit),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusRail(PanelMenuCubit cubit, PanelMenuLoaded state) {
    const List<String> statuses = PanelMenuStatusFilter.values;
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: TavoSpace.gutter,
        ),
        children: <Widget>[
          for (final String status in statuses)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: TavoSpace.sm),
              child: MenuFilterChip(
                key: ValueKey<String>('filter_$status'),
                label: 'menu_filter_$status'.tr(),
                count: state.countFor(status),
                selected: state.filterStatus == status,
                dotColor: switch (status) {
                  PanelMenuStatusFilter.active => TavoColors.success,
                  PanelMenuStatusFilter.inactive => TavoColors.mutedForeground,
                  _ => null,
                },
                onTap: () => cubit.setStatus(status),
              ),
            ),
        ],
      ),
    );
  }

  Widget _content(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
  ) {
    final String locale = context.locale.languageCode;

    if (state.items.isEmpty) {
      if (state.categories.isEmpty) {
        return MenuEmptyState(
          icon: Iconsax.category_2,
          title: 'menu_no_categories_title'.tr(),
          message: 'menu_no_categories_message'.tr(),
          actionLabel: _canManage ? 'add_category'.tr() : null,
          onAction:
              _canManage ? () => _openCategories(context, cubit) : null,
        );
      }
      if (state.hasFilters) {
        return MenuEmptyState(
          icon: Iconsax.search_normal,
          title: 'menu_no_results_title'.tr(),
          message: 'menu_no_results_message'.tr(),
          actionLabel: 'clear_filters'.tr(),
          onAction: () {
            _search.clear();
            cubit.clearFilters();
          },
        );
      }
      return MenuEmptyState(
        icon: Iconsax.cup,
        title: 'empty_menu_title'.tr(),
        message: 'empty_menu_message'.tr(),
        actionLabel: _canManage ? 'add_item'.tr() : null,
        onAction: _canManage
            ? () => _openItem(context, cubit, state, null)
            : null,
      );
    }

    final Widget body = AnimatedOpacity(
      duration: TavoMotion.fast,
      opacity: state.refreshing ? 0.55 : 1,
      child: CustomScrollView(
        key: const ValueKey<String>('menu_scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: <Widget>[
          if (_view == _MenuView.list)
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TavoSpace.gutter,
                TavoSpace.xs,
                TavoSpace.gutter,
                TavoSpace.lg,
              ),
              sliver: SliverList.separated(
                itemCount: state.items.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  final PanelMenuItem item = state.items[index];
                  return TavoReveal(
                    key: ValueKey<String>('menu_card_${item.id}'),
                    index: index,
                    child: MenuItemRow(
                      item: item,
                      locale: locale,
                      categoryName: _categoryLabel(state, item, locale),
                      acting: state.actionId == item.id,
                      manageable: _canManage,
                      onOpen: () => _openItem(context, cubit, state, item),
                      onAction: (MenuRowAction action) => _onRowAction(
                        context,
                        cubit,
                        state,
                        item,
                        action,
                      ),
                    ),
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                TavoSpace.gutter,
                TavoSpace.xs,
                TavoSpace.gutter,
                TavoSpace.lg,
              ),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 206,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: state.items.length,
                itemBuilder: (BuildContext context, int index) {
                  final PanelMenuItem item = state.items[index];
                  return TavoReveal(
                    key: ValueKey<String>('menu_tile_${item.id}'),
                    index: index,
                    child: MenuItemTile(
                      item: item,
                      locale: locale,
                      categoryName: _categoryLabel(state, item, locale),
                      acting: state.actionId == item.id,
                      manageable: _canManage,
                      onOpen: () => _openItem(context, cubit, state, item),
                      onAction: (MenuRowAction action) => _onRowAction(
                        context,
                        cubit,
                        state,
                        item,
                        action,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );

    return RefreshIndicator(
      color: TavoColors.brand800,
      backgroundColor: TavoColors.background,
      onRefresh: cubit.refresh,
      child: body,
    );
  }

  String _categoryLabel(
    PanelMenuLoaded state,
    PanelMenuItem item,
    String locale,
  ) {
    final PanelMenuCategory? category = state.categoryById(item.categoryId);
    return category == null
        ? 'category'.tr()
        : menuCategoryName(category, locale);
  }

  Widget _pager(PanelMenuCubit cubit, PanelMenuLoaded state) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TavoSpace.gutter,
        TavoSpace.sm,
        TavoSpace.gutter,
        TavoSpace.sm,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: TavoColors.border)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              'menu_results_range'.tr(namedArgs: {
                'from': '${state.firstRow}',
                'to': '${state.lastRow}',
                'total': '${state.total}',
              }),
              style: TavoType.caption.copyWith(
                color: TavoColors.mutedForeground,
                fontFeatures: TavoType.tabular,
              ),
            ),
          ),
          MenuPageButton(
            key: const ValueKey<String>('menu_prev_page'),
            back: true,
            tooltip: 'menu_previous_page'.tr(),
            onPressed: state.page > 1
                ? () => cubit.goToPage(state.page - 1)
                : null,
          ),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: TavoSpace.md,
            ),
            child: Text(
              '${state.page} / ${state.pages}',
              style: TavoType.caption.copyWith(
                color: TavoColors.foreground,
                fontWeight: FontWeight.w600,
                fontFeatures: TavoType.tabular,
              ),
            ),
          ),
          MenuPageButton(
            key: const ValueKey<String>('menu_next_page'),
            back: false,
            tooltip: 'menu_next_page'.tr(),
            onPressed: state.page < state.pages
                ? () => cubit.goToPage(state.page + 1)
                : null,
          ),
        ],
      ),
    );
  }

  Future<void> _onRowAction(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
    PanelMenuItem item,
    MenuRowAction action,
  ) async {
    switch (action) {
      case MenuRowAction.edit:
        await _openItem(context, cubit, state, item);
      case MenuRowAction.toggle:
        await cubit.toggleStatus(item);
      case MenuRowAction.addPhoto:
        await _pickAndUpload(item, cubit);
      case MenuRowAction.removePhoto:
        final bool ok = await cubit.removeImage(item.id);
        if (ok) _toast('menu_photo_removed'.tr());
      case MenuRowAction.delete:
        await _confirmDelete(context, cubit, item);
    }
  }

  Future<void> _openItem(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
    PanelMenuItem? item,
  ) async {
    final bool? saved = await MenuItemSheet.show(
      context,
      cubit: cubit,
      categories: state.categories,
      item: item,
      canManage: _canManage,
    );
    if (saved == true && mounted) {
      _toast('menu_item_saved'.tr());
    }
  }

  Future<void> _openCategories(
    BuildContext context,
    PanelMenuCubit cubit,
  ) async {
    await MenuCategoriesSheet.show(context, cubit: cubit);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuItem item,
  ) async {
    final String locale = context.locale.languageCode;
    final bool? confirmed = await TavoSheet.show<bool>(
      context,
      title: 'delete_item'.tr(),
      subtitle: menuName(item, locale),
      maxHeightFactor: 0.5,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'menu_delete_item_message'.tr(namedArgs: {
              'name': menuName(item, locale),
            }),
            style: TavoType.bodySmall.copyWith(
              color: TavoColors.mutedForeground,
            ),
          ),
          const SizedBox(height: TavoSpace.xl),
          Row(
            children: <Widget>[
              Expanded(
                child: TavoButton.secondary(
                  label: 'cancel'.tr(),
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: TavoSpace.md),
              Expanded(
                child: TavoButton.destructive(
                  key: const ValueKey<String>('confirm_delete_item'),
                  label: 'delete'.tr(),
                  expand: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final bool ok = await cubit.deleteItem(item);
    if (ok && mounted) _toast('menu_item_deleted'.tr());
  }

  /// `image_picker` runs on a platform channel and never completes in
  /// `flutter test`; widget tests drive `uploadImage` through the fake repo.
  Future<void> _pickAndUpload(
    PanelMenuItem item,
    PanelMenuCubit cubit,
  ) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final bool ok = await cubit.uploadImage(item.id, bytes, picked.name);
    if (ok && mounted) _toast('menu_photo_updated'.tr());
  }
}

/// A circular add button at the end of the category rail. It opens the same
/// manager sheet as "manage", because creating a category and renaming one
/// are the same job.
class _AddCategoryChip extends StatelessWidget {
  const _AddCategoryChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'add_category'.tr(),
      child: Semantics(
        button: true,
        label: 'add_category'.tr(),
        child: TavoPressScale(
          child: GestureDetector(
            key: const ValueKey<String>('menu_add_category'),
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: TavoColors.background,
                shape: BoxShape.circle,
                border: Border.all(color: TavoColors.border),
              ),
              child: const Icon(
                Iconsax.add,
                size: 18,
                color: TavoColors.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// List/grid segmented control. Selected segment lifts to a white plate.
class _ViewToggle extends StatelessWidget {
  const _ViewToggle({required this.grid, required this.onChanged});

  final bool grid;
  final ValueChanged<_MenuView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TavoColors.muted,
        borderRadius: BorderRadius.circular(TavoRadii.pill),
        border: Border.all(color: TavoColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _segment(
            key: const ValueKey<String>('menu_view_list'),
            icon: Iconsax.menu_board,
            selected: !grid,
            tooltip: 'menu_view_list'.tr(),
            onTap: () => onChanged(_MenuView.list),
          ),
          _segment(
            key: const ValueKey<String>('menu_view_grid'),
            icon: Iconsax.grid_2,
            selected: grid,
            tooltip: 'menu_view_grid'.tr(),
            onTap: () => onChanged(_MenuView.grid),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required Key key,
    required IconData icon,
    required bool selected,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: GestureDetector(
          key: key,
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: AnimatedContainer(
            duration: TavoMotion.fast,
            curve: TavoMotion.outStrong,
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: selected ? TavoColors.background : Colors.transparent,
              shape: BoxShape.circle,
              boxShadow: selected ? TavoShadows.sm : TavoShadows.none,
            ),
            child: Icon(
              icon,
              size: 17,
              color: selected
                  ? TavoColors.foreground
                  : TavoColors.mutedForeground,
            ),
          ),
        ),
      ),
    );
  }
}
