// lib/feature/panel_menu/ui/screens/menu_categories_sheet.dart
//
// The category manager. Categories are the menu's spine: a typo used to be
// permanent unless the whole category was rebuilt, and deleting one used to
// orphan every dish inside it. This sheet fixes both:
//
//   • create and rename in place, bilingual, with a real count beside every
//     row;
//   • delete is disabled while the count is above zero and confirmed when it
//     is not. The server enforces the same rule, so a stale screen cannot
//     orphan items either.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';
import 'package:tavo/feature/panel_menu/ui/logic/panel_menu_cubit.dart';

/// Add, rename and delete menu categories.
class MenuCategoriesSheet extends StatefulWidget {
  const MenuCategoriesSheet({super.key, required this.cubit});

  final PanelMenuCubit cubit;

  /// Opens the manager over the menu.
  static Future<void> show(
    BuildContext context, {
    required PanelMenuCubit cubit,
  }) {
    return TavoSheet.show<void>(
      context,
      title: 'menu_categories'.tr(),
      subtitle: 'menu_category_add_hint'.tr(),
      maxHeightFactor: 0.86,
      child: MenuCategoriesSheet(cubit: cubit),
    );
  }

  @override
  State<MenuCategoriesSheet> createState() => _MenuCategoriesSheetState();
}

class _MenuCategoriesSheetState extends State<MenuCategoriesSheet> {
  final TextEditingController _newAr = TextEditingController();
  final TextEditingController _newEn = TextEditingController();

  String? _editingId;
  final TextEditingController _editAr = TextEditingController();
  final TextEditingController _editEn = TextEditingController();

  String? _error;
  bool _saving = false;
  bool _showErrors = false;

  @override
  void dispose() {
    _newAr.dispose();
    _newEn.dispose();
    _editAr.dispose();
    _editEn.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PanelMenuCubit, PanelMenuState>(
      bloc: widget.cubit,
      listenWhen: (PanelMenuState previous, PanelMenuState current) =>
          current is PanelMenuLoaded && current.actionError != null,
      listener: (BuildContext context, PanelMenuState state) {
        final String raw = (state as PanelMenuLoaded).actionError!;
        setState(() {
          _error = raw == 'category_not_empty'
              ? 'category_not_empty_hint'.tr()
              : raw;
          _saving = false;
        });
        widget.cubit.clearActionError();
      },
      child: BlocBuilder<PanelMenuCubit, PanelMenuState>(
        bloc: widget.cubit,
        builder: (BuildContext context, PanelMenuState state) {
          if (state is! PanelMenuLoaded) {
            return const SizedBox(
              height: 220,
              child: Center(
                child: Text('…'),
              ),
            );
          }
          return Column(
            children: <Widget>[
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    _newCategoryCard(),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: TavoSpace.md),
                      _InlineError(message: _error!),
                    ],
                    const SizedBox(height: TavoSpace.lg),
                    Row(
                      children: <Widget>[
                        Text(
                          '${'menu_categories'.tr()} · ${state.categories.length}',
                          style: TavoType.overline.copyWith(
                            color: TavoColors.mutedForeground,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TavoSpace.sm),
                    if (state.categories.isEmpty)
                      TavoCard(
                        variant: TavoCardVariant.muted,
                        padding: const EdgeInsets.all(TavoSpace.md),
                        child: Text(
                          'menu_no_categories_message'.tr(),
                          style: TavoType.caption.copyWith(
                            color: TavoColors.mutedForeground,
                          ),
                        ),
                      ),
                    for (final PanelMenuCategory category
                        in state.categories)
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.only(bottom: 10),
                        child: _categoryCard(context, category),
                      ),
                    const SizedBox(height: TavoSpace.md),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ add category

  Widget _newCategoryCard() {
    final bool invalid = _showErrors &&
        (_newAr.text.trim().length < 2 || _newEn.text.trim().length < 2);
    return TavoCard(
      variant: TavoCardVariant.warm,
      padding: const EdgeInsets.all(TavoSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const TavoIconTile(
                icon: Icon(Iconsax.category_2, size: 18),
                size: 36,
                radius: TavoRadii.md,
              ),
              const SizedBox(width: TavoSpace.sm),
              Text(
                'add_category'.tr(),
                style: TavoType.label.copyWith(
                  color: TavoColors.foreground,
                ),
              ),
            ],
          ),
          const SizedBox(height: TavoSpace.sm),
          _CategoryField(
            key: const ValueKey<String>('category_new_ar'),
            controller: _newAr,
            label: 'category_name_ar'.tr(),
            rtl: true,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TavoSpace.xs),
          _CategoryField(
            key: const ValueKey<String>('category_new_en'),
            controller: _newEn,
            label: 'category_name_en'.tr(),
            onChanged: (_) => setState(() {}),
          ),
          if (invalid) ...<Widget>[
            const SizedBox(height: TavoSpace.xs),
            Text(
              'menu_validation_category_name'.tr(),
              style: TavoType.caption.copyWith(
                color: TavoColors.destructiveSolid,
              ),
            ),
          ],
          const SizedBox(height: TavoSpace.sm),
          TavoButton.primary(
            key: const ValueKey<String>('category_new_save'),
            label: 'add_category'.tr(),
            size: TavoButtonSize.compact,
            leading: const Icon(Iconsax.add, size: 16),
            isLoading: _saving,
            expand: true,
            onPressed: _saving ? null : _create,
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final String ar = _newAr.text.trim();
    final String en = _newEn.text.trim();
    if (ar.length < 2 || en.length < 2) {
      setState(() {
        _showErrors = true;
        _error = 'menu_validation_category_name'.tr();
      });
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final bool ok =
        await widget.cubit.createCategory(arName: ar, enName: en);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      _newAr.clear();
      _newEn.clear();
      setState(() => _showErrors = false);
    }
  }

  // ---------------------------------------------------------------- one row

  Widget _categoryCard(BuildContext context, PanelMenuCategory category) {
    final String locale = context.locale.languageCode;
    final bool editing = _editingId == category.id;
    final bool blocked = category.itemCount > 0;

    return TavoCard(
      key: ValueKey<String>('category_row_${category.id}'),
      padding: const EdgeInsets.all(TavoSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TavoColors.muted,
                  borderRadius: BorderRadius.circular(TavoRadii.md),
                ),
                child: Text(
                  _initials(category.name(locale)),
                  style: TavoType.caption.copyWith(
                    color: TavoColors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: TavoSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      category.name(locale),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TavoType.label.copyWith(
                        color: TavoColors.foreground,
                      ),
                    ),
                    Text(
                      'menu_category_items'
                          .tr(namedArgs: {'count': '${category.itemCount}'}),
                      style: TavoType.caption.copyWith(
                        color: TavoColors.mutedForeground,
                        fontFeatures: TavoType.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              if (!editing) ...<Widget>[
                IconButton(
                  key: ValueKey<String>('category_edit_${category.id}'),
                  tooltip: 'menu_rename_category'.tr(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Iconsax.edit_2, size: 17),
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _editingId = category.id;
                            _editAr.text = category.arName;
                            _editEn.text = category.enName;
                            _error = null;
                          }),
                ),
                Tooltip(
                  message: blocked
                      ? 'menu_delete_category_blocked'.tr()
                      : 'delete_category'.tr(),
                  child: IconButton(
                    key: ValueKey<String>('category_delete_${category.id}'),
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      Iconsax.trash,
                      size: 17,
                      color: blocked
                          ? TavoColors.mutedForeground.withValues(alpha: 0.35)
                          : TavoColors.destructiveSolid,
                    ),
                    onPressed: _saving || blocked
                        ? null
                        : () => _confirmDelete(context, category),
                  ),
                ),
              ],
            ],
          ),
          if (editing) ...<Widget>[
            const SizedBox(height: TavoSpace.sm),
            _CategoryField(
              key: ValueKey<String>('category_edit_ar_${category.id}'),
              controller: _editAr,
              label: 'category_name_ar'.tr(),
              rtl: true,
            ),
            const SizedBox(height: TavoSpace.xs),
            _CategoryField(
              key: ValueKey<String>('category_edit_en_${category.id}'),
              controller: _editEn,
              label: 'category_name_en'.tr(),
            ),
            const SizedBox(height: TavoSpace.sm),
            Row(
              children: <Widget>[
                Expanded(
                  child: TavoButton.secondary(
                    label: 'cancel'.tr(),
                    size: TavoButtonSize.compact,
                    expand: true,
                    onPressed: _saving
                        ? null
                        : () => setState(() => _editingId = null),
                  ),
                ),
                const SizedBox(width: TavoSpace.sm),
                Expanded(
                  flex: 2,
                  child: TavoButton.primary(
                    key: ValueKey<String>('category_edit_save_${category.id}'),
                    label: 'save_changes'.tr(),
                    size: TavoButtonSize.compact,
                    expand: true,
                    isLoading: _saving,
                    onPressed: _saving
                        ? null
                        : () => _rename(context, category),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rename(
    BuildContext context,
    PanelMenuCategory category,
  ) async {
    final String ar = _editAr.text.trim();
    final String en = _editEn.text.trim();
    if (ar.length < 2 || en.length < 2) {
      setState(() => _error = 'menu_validation_category_name'.tr());
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final bool ok = await widget.cubit.updateCategory(
      category,
      arName: ar,
      enName: en,
    );
    if (!mounted) return;
    setState(() {
      _saving = false;
      if (ok) _editingId = null;
    });
  }

  Future<void> _confirmDelete(
    BuildContext context,
    PanelMenuCategory category,
  ) async {
    final String locale = context.locale.languageCode;
    final String name = category.name(locale);
    final bool? confirmed = await TavoSheet.show<bool>(
      context,
      title: 'delete_category'.tr(),
      subtitle: name,
      maxHeightFactor: 0.45,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'menu_delete_category_confirm'.tr(namedArgs: {'name': name}),
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
                  key: const ValueKey<String>('category_delete_confirm'),
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
    setState(() => _saving = true);
    final bool ok = await widget.cubit.deleteCategory(category);
    if (!mounted) return;
    setState(() => _saving = false);
    if (!ok) return;
  }

  String _initials(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return '·';
    final List<String> parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.characters.first;
    }
    return '${parts.first.characters.first}${parts[1].characters.first}';
  }
}

/// A compact, labelled field used only inside the category manager.
class _CategoryField extends StatelessWidget {
  const _CategoryField({
    super.key,
    required this.controller,
    required this.label,
    this.rtl = false,
    this.onChanged,
  });

  final TextEditingController controller;
  final String label;
  final bool rtl;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      maxLength: 40,
      textDirection: rtl ? TextDirection.rtl : null,
      textAlign: rtl ? TextAlign.right : TextAlign.start,
      style: TavoType.bodySmall.copyWith(color: TavoColors.foreground),
      cursorColor: TavoColors.brand800,
      decoration: InputDecoration(
        isDense: true,
        hintText: label,
        hintStyle: TavoType.bodySmall.copyWith(
          color: TavoColors.mutedForeground,
        ),
        counterText: '',
        filled: true,
        fillColor: TavoColors.background,
        contentPadding: const EdgeInsetsDirectional.symmetric(
          horizontal: TavoSpace.md,
          vertical: TavoSpace.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TavoRadii.md),
          borderSide: const BorderSide(color: TavoColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TavoRadii.md),
          borderSide: const BorderSide(color: TavoColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(TavoRadii.md),
          borderSide: const BorderSide(color: TavoColors.brand500, width: 1.5),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsetsDirectional.all(TavoSpace.sm),
      decoration: BoxDecoration(
        color: TavoColors.destructiveSolid.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(TavoRadii.md),
        border: Border.all(
          color: TavoColors.destructiveSolid.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Iconsax.info_circle,
            size: 16,
            color: TavoColors.destructiveSolid,
          ),
          const SizedBox(width: TavoSpace.sm),
          Expanded(
            child: Text(
              message,
              style: TavoType.caption.copyWith(
                color: TavoColors.destructiveSolid,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
