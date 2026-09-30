// lib/feature/panel_menu/ui/screens/panel_menu_screen.dart
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tavo/core/di/service_locator.dart';
import 'package:tavo/core/theme/colors.dart';
import 'package:tavo/core/theme/text_styles.dart';
import 'package:tavo/core/widgets/state/async_state_view.dart';
import 'package:tavo/core/widgets/status_badge.dart';
import 'package:tavo/feature/auth/ui/data/models/staff_restaurant.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';
import 'package:tavo/feature/panel_menu/data/repo/menu_panel_repo.dart';
import 'package:tavo/feature/panel_menu/ui/logic/panel_menu_cubit.dart';

/// `32.0` → `32`, `32.5` → `32.5` — whole prices read without the `.0`.
String formatMenuPrice(double price) =>
    price == price.roundToDouble() ? '${price.round()}' : '$price';

/// Staff panel menu: category + status filter chips over the paged item list,
/// with role-gated add/edit/delete/photo mutations.
///
/// Builds its own [PanelMenuCubit] through get_it (mirroring
/// `DashboardScreen`: the shell only supplies the restaurant id, the venue
/// and the `canManage` gate) and drives the three async states with
/// [ListSkeleton] / [ErrorStateView] / content. Mutation failures surface as
/// a SnackBar while every row stays on screen
/// (`PanelMenuLoaded.actionError`).
class PanelMenuScreen extends StatelessWidget {
  const PanelMenuScreen({
    super.key,
    required this.restaurantId,
    required this.venue,
    required this.canManage,
  });

  final String restaurantId;
  final StaffRestaurant venue;
  final bool Function() canManage;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => PanelMenuCubit(
        getIt<MenuPanelRepo>(),
        restaurantId: restaurantId,
        canManage: canManage,
      )..load(),
      child: BlocConsumer<PanelMenuCubit, PanelMenuState>(
        listener: (context, state) {
          if (state is PanelMenuLoaded && state.actionError != null) {
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
          final cubit = context.read<PanelMenuCubit>();
          return Scaffold(
            body: SafeArea(child: _buildBody(context, cubit, state)),
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuState state,
  ) {
    if (state is PanelMenuError) {
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
    if (state is PanelMenuLoaded) {
      return Column(
        children: [
          _buildHeader(context, cubit),
          _buildStatusChips(cubit, state.filterStatus),
          _buildCategoryChips(context, cubit, state),
          Expanded(child: _buildList(context, cubit, state)),
          _buildPagination(context, cubit, state),
        ],
      );
    }
    // PanelMenuInitial / PanelMenuLoading.
    return const ListSkeleton();
  }

  Widget _buildHeader(BuildContext context, PanelMenuCubit cubit) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 0),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'menu'.tr(),
              style: TextStyles.font20Black500Weight(context),
            ),
          ),
          if (canManage())
            IconButton(
              key: const ValueKey('add_item'),
              icon: const Icon(Icons.add),
              onPressed: () => _openItemSheet(context, cubit, null),
            ),
        ],
      ),
    );
  }

  /// Server-side status filter chips (`all` = no `&status=` param).
  Widget _buildStatusChips(PanelMenuCubit cubit, String filterStatus) {
    const filters = ['all', 'active', 'inactive'];
    return Padding(
      padding: EdgeInsets.only(top: 12.h, bottom: 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            for (final status in filters)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: ChoiceChip(
                  key: ValueKey('filter_$status'),
                  label: Text('menu_filter_$status'.tr()),
                  selected: filterStatus == status,
                  onSelected: (_) => cubit.setStatus(status),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Client-side category filter chips with a trailing add-category action.
  Widget _buildCategoryChips(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
  ) {
    final locale = context.locale.languageCode;
    return Padding(
      padding: EdgeInsets.only(top: 4.h, bottom: 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: ChoiceChip(
                key: const ValueKey('category_chip_all'),
                label: Text('all'.tr()),
                selected: state.selectedCategoryId == null,
                onSelected: (_) => cubit.setCategory(null),
              ),
            ),
            for (final category in state.categories)
              Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: ChoiceChip(
                  key: ValueKey('category_chip_${category.id}'),
                  label: Text(
                    locale == 'ar' ? category.arName : category.enName,
                  ),
                  selected: state.selectedCategoryId == category.id,
                  onSelected: (_) => cubit.setCategory(category.id),
                ),
              ),
            if (canManage())
              TextButton.icon(
                key: const ValueKey('add_category'),
                icon: const Icon(Icons.add, size: 18),
                label: Text('add_category'.tr()),
                onPressed: () => _openCategorySheet(context, cubit),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
  ) {
    if (state.items.isEmpty) {
      return EmptyStateView(
        icon: Icons.restaurant_menu_outlined,
        title: 'empty_menu_title'.tr(),
        message: 'empty_menu_message'.tr(),
        onRetry: cubit.load,
      );
    }
    return RefreshIndicator(
      onRefresh: cubit.load,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(16.w),
        itemCount: state.items.length,
        itemBuilder: (context, index) {
          final item = state.items[index];
          return Padding(
            padding: EdgeInsets.only(bottom: 12.h),
            child: _MenuItemCard(
              key: ValueKey('menu_card_${item.id}'),
              item: item,
              categories: state.categories,
              acting: state.actionId == item.id,
              manageable: canManage(),
              onToggle: () => cubit.toggleStatus(item),
              onDelete: () => _confirmDelete(context, cubit, item),
              onEdit: () => _openItemSheet(context, cubit, item),
              onAddPhoto: () => _pickAndUpload(context, cubit, item),
              onRemovePhoto: () => cubit.removeImage(item.id),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPagination(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuLoaded state,
  ) {
    if (state.pages <= 1) return const SizedBox.shrink();
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
            'page_of'.tr(namedArgs: {'i': '${state.page}', 'n': '${state.pages}'}),
            style: TextStyles.font12DarkGray400Weight(context),
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

  /// Destructive delete always confirms through an action sheet first.
  Future<void> _confirmDelete(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuItem item,
  ) async {
    final locale = context.locale.languageCode;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _DeleteItemSheet(
        title: locale == 'ar' ? item.arName : item.enName,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    cubit.deleteItem(item);
  }

  void _openItemSheet(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuItem? item,
  ) {
    final state = cubit.state;
    if (state is! PanelMenuLoaded) return;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ItemSheet(
        cubit: cubit,
        categories: state.categories,
        item: item,
      ),
    );
  }

  void _openCategorySheet(BuildContext context, PanelMenuCubit cubit) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(cubit: cubit),
    );
  }

  /// `image_picker` runs on a platform channel and never completes in
  /// `flutter test` — widget tests cover photo buttons through the fake
  /// repo's stubbed `uploadItemImage`/`removeItemImage`, never by tapping
  /// into the real picker.
  Future<void> _pickAndUpload(
    BuildContext context,
    PanelMenuCubit cubit,
    PanelMenuItem item,
  ) async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null || !context.mounted) return;
    final bytes = await picked.readAsBytes();
    if (!context.mounted) return;
    cubit.uploadImage(item.id, bytes, picked.name);
  }
}

/// One menu row: thumbnail, names, price, status badge and — when the role
/// may manage — toggle / edit / delete / photo actions.
class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    super.key,
    required this.item,
    required this.categories,
    required this.acting,
    required this.manageable,
    required this.onToggle,
    required this.onDelete,
    required this.onEdit,
    required this.onAddPhoto,
    required this.onRemovePhoto,
  });

  final PanelMenuItem item;
  final List<PanelMenuCategory> categories;
  final bool acting;
  final bool manageable;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onEdit;
  final VoidCallback onAddPhoto;
  final VoidCallback onRemovePhoto;

  @override
  Widget build(BuildContext context) {
    final locale = context.locale.languageCode;
    final category = categories
        .where((c) => c.id == item.categoryId)
        .firstOrNull;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: ColorsManager.grey100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Thumbnail(imageUrl: item.imageUrl),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  locale == 'ar' ? item.arName : item.enName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyles.font14Black400Weight(context).copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Text(
                      '${'price'.tr()}: ',
                      style: TextStyles.font12DarkGray400Weight(context),
                    ),
                    Text(
                      formatMenuPrice(item.price),
                      style: TextStyles.font12DarkGray400Weight(context),
                    ),
                  ],
                ),
                if (category != null) ...[
                  SizedBox(height: 2.h),
                  Text(
                    locale == 'ar' ? category.arName : category.enName,
                    style: TextStyles.font12DarkGray400Weight(context),
                  ),
                ],
                SizedBox(height: 6.h),
                StatusBadge(
                  status: item.active ? 'active' : 'inactive',
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          if (acting)
            const Padding(
              padding: EdgeInsets.all(12),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (manageable)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: ValueKey('toggle_${item.id}'),
                  icon: Icon(
                    item.active ? Icons.toggle_on : Icons.toggle_off,
                    size: 28,
                  ),
                  onPressed: onToggle,
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      key: ValueKey('delete_${item.id}'),
                      icon: const Icon(Icons.delete_outline, size: 20),
                      onPressed: onDelete,
                    ),
                  ],
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20),
                  onSelected: (value) {
                    if (value == 'add') {
                      onAddPhoto();
                    } else {
                      onRemovePhoto();
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      key: ValueKey('add_photo_${item.id}'),
                      value: 'add',
                      child: Text('add_photo'.tr()),
                    ),
                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty)
                      PopupMenuItem(
                        key: ValueKey('remove_photo_${item.id}'),
                        value: 'remove',
                        child: Text('remove_photo'.tr()),
                      ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// 72×72 image area: the network image when one exists, otherwise a
/// decorated placeholder (no network call).
class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.network(
          imageUrl!,
          width: 72.w,
          height: 72.w,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return CustomPaint(
      painter: _DashedBorderPainter(),
      child: SizedBox(
        width: 72.w,
        height: 72.w,
        child: const Icon(Icons.image_outlined, color: ColorsManager.grey100),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const dash = 5.0;
    const gap = 4.0;
    final paint = Paint()
      ..color = ColorsManager.grey100
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics().first;
    var distance = 0.0;
    while (distance < metrics.length) {
      final segment = metrics.extractPath(distance, distance + dash);
      canvas.drawPath(segment, paint);
      distance += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Action sheet for the destructive delete: names the item and only sends
/// `true` back when the confirmation button is tapped.
class _DeleteItemSheet extends StatelessWidget {
  const _DeleteItemSheet({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'delete_item'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 6.h),
          Text(
            title,
            style: TextStyles.font12DarkGray400Weight(context),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('cancel'.tr()),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorsManager.redButton,
                    foregroundColor: ColorsManager.white,
                  ),
                  child: Text('delete'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Add/edit item bottom sheet: bilingual names, price and category.
class _ItemSheet extends StatefulWidget {
  const _ItemSheet({
    required this.cubit,
    required this.categories,
    required this.item,
  });

  final PanelMenuCubit cubit;
  final List<PanelMenuCategory> categories;
  final PanelMenuItem? item;

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late final TextEditingController _ar = TextEditingController(
    text: widget.item?.arName ?? '',
  );
  late final TextEditingController _en = TextEditingController(
    text: widget.item?.enName ?? '',
  );
  late final TextEditingController _price = TextEditingController(
    text: widget.item == null ? '' : formatMenuPrice(widget.item!.price),
  );
  late String? _categoryId = widget.item?.categoryId ??
      (widget.categories.isNotEmpty ? widget.categories.first.id : null);

  @override
  void dispose() {
    _ar.dispose();
    _en.dispose();
    _price.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (widget.item == null ? 'add_item' : 'edit_item').tr(),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _ar,
              decoration: InputDecoration(labelText: 'item_name_ar'.tr()),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _en,
              decoration: InputDecoration(labelText: 'item_name_en'.tr()),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'price_sar'.tr()),
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              initialValue: _categoryId,
              decoration: InputDecoration(labelText: 'category'.tr()),
              items: [
                for (final c in widget.categories)
                  DropdownMenuItem(
                    value: c.id,
                    child: Text(context.locale.languageCode == 'ar'
                        ? c.arName
                        : c.enName),
                  ),
              ],
              onChanged: (value) => setState(() => _categoryId = value),
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _categoryId == null ? null : _save,
                child: Text('save'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    final price = double.tryParse(_price.text.trim()) ?? 0;
    widget.cubit.saveItem(
      id: widget.item?.id,
      categoryId: _categoryId!,
      arName: _ar.text.trim(),
      enName: _en.text.trim(),
      price: price,
    );
    Navigator.of(context).pop();
  }
}

/// Add-category bottom sheet: bilingual names only.
class _CategorySheet extends StatefulWidget {
  const _CategorySheet({required this.cubit});

  final PanelMenuCubit cubit;

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final TextEditingController _ar = TextEditingController();
  final TextEditingController _en = TextEditingController();

  @override
  void dispose() {
    _ar.dispose();
    _en.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 24.h),
      decoration: BoxDecoration(
        color: ColorsManager.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'add_category'.tr(),
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _ar,
            decoration: InputDecoration(labelText: 'category_name_ar'.tr()),
          ),
          SizedBox(height: 12.h),
          TextField(
            controller: _en,
            decoration: InputDecoration(labelText: 'category_name_en'.tr()),
          ),
          SizedBox(height: 20.h),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: Text('save'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
    widget.cubit.createCategory(
      arName: _ar.text.trim(),
      enName: _en.text.trim(),
    );
    Navigator.of(context).pop();
  }
}
