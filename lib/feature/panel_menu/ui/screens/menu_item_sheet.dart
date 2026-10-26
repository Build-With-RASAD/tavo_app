// lib/feature/panel_menu/ui/screens/menu_item_sheet.dart
//
// The item editor. It is one sheet for two audiences:
//
//   • managers get the full form (bilingual basics, price, category,
//     availability, photo, specifications);
//   • read-only staff get the same information without a single enabled
//     input, so the sheet never pretends they can save.
//
// Specifications are the reason this is not a two-field dialog. A guest
// choice ("dough", "size") is stored per language in Mongo; the editor keeps
// one bilingual group and refuses to publish a half-filled one instead of
// silently dropping it. The live preview at the top shows exactly what the
// guest will read in the language being edited.
import 'package:easy_localization/easy_localization.dart' hide TextDirection;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:tavo/core/ui/tavo_web/tavo_web.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';
import 'package:tavo/feature/panel_menu/ui/logic/panel_menu_cubit.dart';
import 'package:tavo/feature/panel_menu/ui/widgets/menu_widgets.dart';

/// One editable specification option. Controllers (not `initialValue`) keep
/// the text alive while sibling rows are added or removed.
class _OptionDraft {
  _OptionDraft({String ar = '', String en = '', String price = ''})
      : arCtrl = TextEditingController(text: ar),
        enCtrl = TextEditingController(text: en),
        priceCtrl = TextEditingController(text: price);

  factory _OptionDraft.fromModel(PanelMenuOption option) => _OptionDraft(
        ar: option.arTitle,
        en: option.enTitle,
        price: option.price == 0 ? '' : formatMenuPrice(option.price),
      );

  final TextEditingController arCtrl;
  final TextEditingController enCtrl;
  final TextEditingController priceCtrl;

  String get ar => arCtrl.text.trim();
  String get en => enCtrl.text.trim();

  /// `null` when the field is not a number; empty counts as zero.
  double? get price {
    final String raw = priceCtrl.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return 0;
    return double.tryParse(raw);
  }

  bool get hasAnyContent =>
      ar.isNotEmpty || en.isNotEmpty || priceCtrl.text.trim().isNotEmpty;

  void dispose() {
    arCtrl.dispose();
    enCtrl.dispose();
    priceCtrl.dispose();
  }
}

/// One bilingual specification group while it is being edited.
class _SpecDraft {
  _SpecDraft({
    required this.uid,
    this.key = '',
    String ar = '',
    String en = '',
    this.type = 'single',
    this.required = false,
    List<_OptionDraft>? options,
  })  : arCtrl = TextEditingController(text: ar),
        enCtrl = TextEditingController(text: en),
        options = options ?? <_OptionDraft>[_OptionDraft()];

  factory _SpecDraft.fromModel(PanelMenuSpecification spec, int uid) =>
      _SpecDraft(
        uid: uid,
        key: spec.key,
        ar: spec.arTitle,
        en: spec.enTitle,
        type: spec.type,
        required: spec.required,
        options: spec.options.isEmpty
            ? <_OptionDraft>[_OptionDraft()]
            : spec.options.map(_OptionDraft.fromModel).toList(),
      );

  final int uid;
  final String key;
  final TextEditingController arCtrl;
  final TextEditingController enCtrl;
  final List<_OptionDraft> options;

  String type;
  bool required;

  String get ar => arCtrl.text.trim();
  String get en => enCtrl.text.trim();

  bool get hasContent =>
      ar.isNotEmpty ||
      en.isNotEmpty ||
      options.any((_OptionDraft option) => option.hasAnyContent);

  bool get isPublishable =>
      ar.isNotEmpty &&
      en.isNotEmpty &&
      options.isNotEmpty &&
      options.every((_OptionDraft option) =>
          option.ar.isNotEmpty && option.en.isNotEmpty && option.price != null);

  PanelMenuSpecification toModel() => PanelMenuSpecification(
        key: key,
        arTitle: ar,
        enTitle: en,
        type: type,
        required: required,
        options: <PanelMenuOption>[
          for (final _OptionDraft option in options)
            PanelMenuOption(
              arTitle: option.ar,
              enTitle: option.en,
              price: option.price ?? 0,
            ),
        ],
      );

  void dispose() {
    arCtrl.dispose();
    enCtrl.dispose();
    for (final _OptionDraft option in options) {
      option.dispose();
    }
  }
}

/// The menu item editor / reader.
class MenuItemSheet extends StatefulWidget {
  const MenuItemSheet({
    super.key,
    required this.cubit,
    required this.categories,
    required this.item,
    required this.canManage,
    this.categoryName,
  });

  final PanelMenuCubit cubit;
  final List<PanelMenuCategory> categories;
  final PanelMenuItem? item;
  final bool canManage;
  final String? categoryName;

  /// Opens the sheet and resolves to `true` only when a write landed.
  static Future<bool?> show(
    BuildContext context, {
    required PanelMenuCubit cubit,
    required List<PanelMenuCategory> categories,
    required PanelMenuItem? item,
    required bool canManage,
    String? categoryName,
  }) {
    final String locale = context.locale.languageCode;
    final String title = item == null
        ? 'new_item'.tr()
        : (locale == 'ar'
            ? (item.arName.isNotEmpty ? item.arName : item.enName)
            : (item.enName.isNotEmpty ? item.enName : item.arName));
    return TavoSheet.show<bool>(
      context,
      title: title,
      subtitle: item == null ? 'menu_details'.tr() : categoryName,
      maxHeightFactor: 0.94,
      child: MenuItemSheet(
        cubit: cubit,
        categories: categories,
        item: item,
        canManage: canManage,
        categoryName: categoryName,
      ),
    );
  }

  @override
  State<MenuItemSheet> createState() => _MenuItemSheetState();
}

class _MenuItemSheetState extends State<MenuItemSheet> {
  late final TextEditingController _arName;
  late final TextEditingController _enName;
  late final TextEditingController _arDescription;
  late final TextEditingController _enDescription;
  late final TextEditingController _price;

  final List<_SpecDraft> _specs = <_SpecDraft>[];
  int _specUid = 0;

  String _language = 'ar';
  String? _categoryId;
  bool _active = true;
  bool _saving = false;
  bool _showErrors = false;
  String? _error;
  String? _photoUrl;

  bool get _isNew => widget.item == null;

  @override
  void initState() {
    super.initState();
    final PanelMenuItem? item = widget.item;
    _arName = TextEditingController(text: item?.arName ?? '');
    _enName = TextEditingController(text: item?.enName ?? '');
    _arDescription = TextEditingController(text: item?.arDescription ?? '');
    _enDescription = TextEditingController(text: item?.enDescription ?? '');
    _price = TextEditingController(
      text: item == null || item.price == 0 ? '' : formatMenuPrice(item.price),
    );
    _active = item?.active ?? true;
    _photoUrl = item?.imageUrl;
    _categoryId = item?.categoryId ??
        (widget.categories.length == 1 ? widget.categories.first.id : null);
    for (final PanelMenuSpecification spec in item?.specifications ?? const []) {
      _specs.add(_SpecDraft.fromModel(spec, _specUid++));
    }
  }

  @override
  void dispose() {
    _arName.dispose();
    _enName.dispose();
    _arDescription.dispose();
    _enDescription.dispose();
    _price.dispose();
    for (final _SpecDraft spec in _specs) {
      spec.dispose();
    }
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
      child: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              padding: const EdgeInsetsDirectional.only(top: TavoSpace.xxs),
              children: <Widget>[
                _preview(),
                if (!widget.canManage) ...<Widget>[
                  const SizedBox(height: TavoSpace.md),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TavoStatusPill(
                      label: 'menu_read_only'.tr(),
                      tone: TavoTone.neutral,
                    ),
                  ),
                ],
                const SizedBox(height: TavoSpace.lg),
                if (widget.canManage) ...<Widget>[
                  _languageTabs(),
                  const SizedBox(height: TavoSpace.md),
                  _basics(),
                  const SizedBox(height: TavoSpace.lg),
                  _pricing(),
                  const SizedBox(height: TavoSpace.lg),
                  _availability(),
                  const SizedBox(height: TavoSpace.lg),
                  _photo(),
                  const SizedBox(height: TavoSpace.lg),
                  _specifications(),
                ] else
                  _readOnlyDetails(),
                const SizedBox(height: TavoSpace.xl),
              ],
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- preview

  Widget _preview() {
    final String name = _language == 'ar'
        ? (_arName.text.trim().isNotEmpty
            ? _arName.text.trim()
            : _enName.text.trim())
        : (_enName.text.trim().isNotEmpty
            ? _enName.text.trim()
            : _arName.text.trim());
    final double? price = _parsedPrice();
    final PanelMenuCategory? category = _selectedCategory();

    return TavoCard(
      variant: TavoCardVariant.warm,
      padding: const EdgeInsets.all(TavoSpace.md),
      child: Row(
        children: <Widget>[
          MenuThumb(imageUrl: _photoUrl, size: 84),
          const SizedBox(width: TavoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'menu_preview'.tr().toUpperCase(),
                  style: TavoType.micro.copyWith(
                    color: TavoColors.brand800,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name.isEmpty ? 'menu_untitled_item'.tr() : name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TavoType.title.copyWith(
                    color: TavoColors.foreground,
                  ),
                ),
                if (category != null)
                  Text(
                    category.name(_language),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TavoType.caption.copyWith(
                      color: TavoColors.mutedForeground,
                    ),
                  ),
                const SizedBox(height: 4),
                Row(
                  children: <Widget>[
                    Text(
                      price == null
                          ? '—'
                          : '${formatMenuPrice(price)} ${'currency'.tr()}',
                      style: TavoType.label.copyWith(
                        color: TavoColors.foreground,
                        fontFeatures: TavoType.tabular,
                      ),
                    ),
                    if (_specs.any((_SpecDraft spec) => spec.hasContent)) ...<Widget>[
                      const SizedBox(width: TavoSpace.sm),
                      Icon(
                        Iconsax.setting_2,
                        size: 12,
                        color: TavoColors.mutedForeground,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${_specs.where((_SpecDraft s) => s.hasContent).length}',
                        style: TavoType.caption.copyWith(
                          color: TavoColors.mutedForeground,
                          fontFeatures: TavoType.tabular,
                        ),
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

  // --------------------------------------------------------------- language

  Widget _languageTabs() {
    final bool arComplete = _arName.text.trim().length >= 2;
    final bool enComplete = _enName.text.trim().length >= 2;

    return _Segmented<_LanguageTab>(
      value: _language == 'ar' ? _LanguageTab.ar : _LanguageTab.en,
      options: <_SegmentOption<_LanguageTab>>[
        _SegmentOption<_LanguageTab>(
          value: _LanguageTab.ar,
          label: 'arabic'.tr(),
          complete: arComplete,
          key: const ValueKey<String>('menu_tab_ar'),
        ),
        _SegmentOption<_LanguageTab>(
          value: _LanguageTab.en,
          label: 'english'.tr(),
          complete: enComplete,
          key: const ValueKey<String>('menu_tab_en'),
        ),
      ],
      onChanged: (_LanguageTab tab) => setState(() {
        _language = tab == _LanguageTab.ar ? 'ar' : 'en';
      }),
    );
  }

  Widget _basics() {
    final bool ar = _language == 'ar';
    final TextEditingController nameCtrl = ar ? _arName : _enName;
    final TextEditingController descriptionCtrl =
        ar ? _arDescription : _enDescription;
    final bool nameInvalid =
        _showErrors && nameCtrl.text.trim().length < 2;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(
          icon: Iconsax.note_1,
          label: 'menu_basics'.tr(),
        ),
        const SizedBox(height: TavoSpace.sm),
        _SheetField(
          key: ValueKey<String>(ar ? 'item_name_ar' : 'item_name_en'),
          label: ar ? 'item_name_ar'.tr() : 'item_name_en'.tr(),
          hint: 'menu_item_name_hint'.tr(),
          controller: nameCtrl,
          rtl: ar,
          maxLength: 50,
          forceError: nameInvalid,
          errorText: nameInvalid ? 'menu_validation_name'.tr() : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: TavoSpace.md),
        _SheetField(
          key: ValueKey<String>(
            ar ? 'item_description_ar' : 'item_description_en',
          ),
          label: ar ? 'item_description_ar'.tr() : 'item_description_en'.tr(),
          hint: 'menu_item_description_hint'.tr(),
          controller: descriptionCtrl,
          rtl: ar,
          maxLines: 3,
          minLines: 2,
          maxLength: 300,
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- pricing

  Widget _pricing() {
    final bool priceInvalid =
        _showErrors && (_parsedPrice() == null || _parsedPrice()! < 0);
    final bool categoryInvalid = _showErrors && _categoryId == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(
          icon: Iconsax.card,
          label: 'menu_pricing'.tr(),
        ),
        const SizedBox(height: TavoSpace.sm),
        _SheetField(
          key: const ValueKey<String>('item_price'),
          label: 'price'.tr(),
          hint: '0',
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          ltr: true,
          suffix: 'currency'.tr(),
          forceError: priceInvalid,
          errorText: priceInvalid ? 'menu_validation_price'.tr() : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: TavoSpace.md),
        Text(
          'category'.tr(),
          style: TavoType.caption.copyWith(
            color: TavoColors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: TavoSpace.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: <Widget>[
              for (final PanelMenuCategory category in widget.categories)
                Padding(
                  padding:
                      const EdgeInsetsDirectional.only(end: TavoSpace.sm),
                  child: MenuFilterChip(
                    key: ValueKey<String>('item_category_${category.id}'),
                    label: category.name(_language),
                    selected: _categoryId == category.id,
                    onTap: () => setState(() => _categoryId = category.id),
                  ),
                ),
            ],
          ),
        ),
        if (categoryInvalid) ...<Widget>[
          const SizedBox(height: TavoSpace.xs),
          Text(
            'menu_validation_category'.tr(),
            style: TavoType.caption.copyWith(
              color: TavoColors.destructiveSolid,
            ),
          ),
        ],
      ],
    );
  }

  // ----------------------------------------------------------- availability

  Widget _availability() {
    return TavoCard(
      padding: const EdgeInsets.all(TavoSpace.md),
      child: Row(
        children: <Widget>[
          TavoIconTile(
            icon: Icon(
              _active ? Iconsax.tick_circle : Iconsax.close_circle,
              size: 20,
            ),
            tone: _active ? TavoTone.success : TavoTone.neutral,
            size: 40,
          ),
          const SizedBox(width: TavoSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'menu_availability'.tr(),
                  style: TavoType.label.copyWith(
                    color: TavoColors.foreground,
                  ),
                ),
                Text(
                  _active ? 'available'.tr() : 'unavailable'.tr(),
                  style: TavoType.caption.copyWith(
                    color: TavoColors.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            key: const ValueKey<String>('item_availability'),
            value: _active,
            activeTrackColor: TavoColors.brand500,
            activeThumbColor: TavoColors.foreground,
            onChanged: (bool value) => setState(() => _active = value),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ photo

  Widget _photo() {
    final PanelMenuItem? item = widget.item;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(icon: Iconsax.camera, label: 'menu_photo'.tr()),
        const SizedBox(height: TavoSpace.sm),
        if (item == null)
          Text(
            'menu_photo_new_hint'.tr(),
            style: TavoType.caption.copyWith(
              color: TavoColors.mutedForeground,
            ),
          )
        else
          Row(
            children: <Widget>[
              MenuThumb(imageUrl: _photoUrl, size: 92),
              const SizedBox(width: TavoSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    TavoButton.secondary(
                      key: const ValueKey<String>('menu_photo_change'),
                      label: _photoUrl == null
                          ? 'add_photo'.tr()
                          : 'change_photo'.tr(),
                      size: TavoButtonSize.compact,
                      leading: const Icon(Iconsax.gallery_add, size: 16),
                      onPressed: _saving ? null : () => _pickPhoto(item),
                    ),
                    if (_photoUrl != null) ...<Widget>[
                      const SizedBox(height: TavoSpace.xs),
                      TavoButton.ghost(
                        key: const ValueKey<String>('menu_photo_remove'),
                        label: 'remove_photo'.tr(),
                        size: TavoButtonSize.compact,
                        leading: const Icon(Iconsax.gallery_slash, size: 16),
                        onPressed: _saving ? null : () => _removePhoto(item),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Future<void> _pickPhoto(PanelMenuItem item) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final bool ok =
        await widget.cubit.uploadImage(item.id, bytes, picked.name);
    if (!mounted || !ok) return;
    final PanelMenuState state = widget.cubit.state;
    if (state is PanelMenuLoaded) {
      setState(() => _photoUrl = state.itemById(item.id)?.imageUrl);
    }
  }

  Future<void> _removePhoto(PanelMenuItem item) async {
    final bool ok = await widget.cubit.removeImage(item.id);
    if (!mounted || !ok) return;
    setState(() => _photoUrl = null);
  }

  // --------------------------------------------------------- specifications

  Widget _specifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _SectionLabel(
                icon: Iconsax.element_3,
                label: 'menu_specifications'.tr(),
              ),
            ),
            TavoButton.ghost(
              key: const ValueKey<String>('spec_add'),
              label: 'add'.tr(),
              size: TavoButtonSize.compact,
              leading: const Icon(Iconsax.add, size: 16),
              onPressed: _saving ? null : _addSpec,
            ),
          ],
        ),
        Text(
          'menu_specifications_hint'.tr(),
          style: TavoType.caption.copyWith(
            color: TavoColors.mutedForeground,
          ),
        ),
        const SizedBox(height: TavoSpace.sm),
        if (_specs.isEmpty)
          TavoCard(
            variant: TavoCardVariant.muted,
            padding: const EdgeInsets.all(TavoSpace.md),
            child: Text(
              'menu_no_specifications'.tr(),
              style: TavoType.caption.copyWith(
                color: TavoColors.mutedForeground,
              ),
            ),
          ),
        for (int i = 0; i < _specs.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: TavoSpace.sm),
            child: _specCard(_specs[i], i),
          ),
      ],
    );
  }

  void _addSpec() {
    setState(() {
      _specs.add(_SpecDraft(uid: _specUid++));
    });
  }

  void _removeSpec(_SpecDraft spec) {
    setState(() {
      _specs.remove(spec);
      spec.dispose();
    });
  }

  void _addOption(_SpecDraft spec) {
    setState(() => spec.options.add(_OptionDraft()));
  }

  void _removeOption(_SpecDraft spec, int index) {
    if (spec.options.length <= 1) return;
    setState(() {
      final _OptionDraft removed = spec.options.removeAt(index);
      removed.dispose();
    });
  }

  Widget _specCard(_SpecDraft spec, int index) {
    return TavoCard(
      key: ValueKey<String>('spec_group_${spec.uid}'),
      padding: const EdgeInsets.all(TavoSpace.md),
      borderColor: TavoColors.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: TavoColors.brand50,
                  borderRadius: BorderRadius.circular(TavoRadii.sm),
                ),
                child: Text(
                  '${index + 1}',
                  style: TavoType.caption.copyWith(
                    color: TavoColors.brand800,
                    fontWeight: FontWeight.w700,
                    fontFeatures: TavoType.tabular,
                  ),
                ),
              ),
              const SizedBox(width: TavoSpace.sm),
              Expanded(
                child: Text(
                  spec.en.isEmpty && spec.ar.isEmpty
                      ? 'menu_new_specification'.tr()
                      : (spec.en.isNotEmpty ? spec.en : spec.ar),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TavoType.label.copyWith(
                    color: TavoColors.foreground,
                  ),
                ),
              ),
              IconButton(
                key: ValueKey<String>('spec_remove_${spec.uid}'),
                tooltip: 'delete'.tr(),
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Iconsax.trash,
                  size: 17,
                  color: TavoColors.destructiveSolid,
                ),
                onPressed: _saving ? null : () => _removeSpec(spec),
              ),
            ],
          ),
          const SizedBox(height: TavoSpace.xs),
          _SheetField(
            key: ValueKey<String>('spec_ar_${spec.uid}'),
            label: 'menu_spec_title_ar'.tr(),
            hint: 'menu_spec_title_hint'.tr(),
            controller: spec.arCtrl,
            rtl: true,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TavoSpace.sm),
          _SheetField(
            key: ValueKey<String>('spec_en_${spec.uid}'),
            label: 'menu_spec_title_en'.tr(),
            hint: 'menu_spec_title_hint'.tr(),
            controller: spec.enCtrl,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TavoSpace.sm),
          _Segmented<String>(
            value: spec.type,
            dense: true,
            options: <_SegmentOption<String>>[
              _SegmentOption<String>(
                value: 'single',
                label: 'menu_spec_single'.tr(),
                key: ValueKey<String>('spec_type_single_${spec.uid}'),
              ),
              _SegmentOption<String>(
                value: 'multiple',
                label: 'menu_spec_multiple'.tr(),
                key: ValueKey<String>('spec_type_multiple_${spec.uid}'),
              ),
            ],
            onChanged: (String value) => setState(() => spec.type = value),
          ),
          Row(
            children: <Widget>[
              Text(
                'menu_spec_required'.tr(),
                style: TavoType.caption.copyWith(
                  color: TavoColors.foreground,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Switch.adaptive(
                key: ValueKey<String>('spec_required_${spec.uid}'),
                value: spec.required,
                activeTrackColor: TavoColors.brand500,
                activeThumbColor: TavoColors.foreground,
                onChanged: _saving
                    ? null
                    : (bool value) => setState(() => spec.required = value),
              ),
            ],
          ),
          const Divider(height: TavoSpace.lg, color: TavoColors.border),
          for (int i = 0; i < spec.options.length; i++)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: TavoSpace.sm),
              child: _optionCard(spec, spec.options[i], i),
            ),
          TavoButton.ghost(
            key: ValueKey<String>('spec_option_add_${spec.uid}'),
            label: 'menu_add_option'.tr(),
            size: TavoButtonSize.compact,
            leading: const Icon(Iconsax.add, size: 16),
            onPressed: _saving ? null : () => _addOption(spec),
          ),
        ],
      ),
    );
  }

  Widget _optionCard(_SpecDraft spec, _OptionDraft option, int index) {
    return Container(
      padding: const EdgeInsets.all(TavoSpace.sm),
      decoration: BoxDecoration(
        color: TavoColors.muted.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(TavoRadii.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '${index + 1}',
                style: TavoType.caption.copyWith(
                  color: TavoColors.mutedForeground,
                  fontWeight: FontWeight.w700,
                  fontFeatures: TavoType.tabular,
                ),
              ),
              const Spacer(),
              if (spec.options.length > 1)
                IconButton(
                  key: ValueKey<String>('spec_option_remove_${spec.uid}_$index'),
                  tooltip: 'delete'.tr(),
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Iconsax.minus,
                    size: 16,
                    color: TavoColors.destructiveSolid,
                  ),
                  onPressed:
                      _saving ? null : () => _removeOption(spec, index),
                ),
            ],
          ),
          _SheetField(
            key: ValueKey<String>('spec_option_ar_${spec.uid}_$index'),
            label: 'menu_option_title_ar'.tr(),
            hint: 'menu_option_title_hint'.tr(),
            controller: option.arCtrl,
            rtl: true,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TavoSpace.xs),
          _SheetField(
            key: ValueKey<String>('spec_option_en_${spec.uid}_$index'),
            label: 'menu_option_title_en'.tr(),
            hint: 'menu_option_title_hint'.tr(),
            controller: option.enCtrl,
            maxLength: 60,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: TavoSpace.xs),
          _SheetField(
            key: ValueKey<String>('spec_option_price_${spec.uid}_$index'),
            label: 'menu_option_price'.tr(),
            hint: '0',
            controller: option.priceCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            ltr: true,
            suffix: 'currency'.tr(),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- read-only

  Widget _readOnlyDetails() {
    final PanelMenuCategory? category = _selectedCategory();
    final String description = _language == 'ar'
        ? _arDescription.text.trim()
        : _enDescription.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _SectionLabel(icon: Iconsax.info_circle, label: 'menu_details'.tr()),
        const SizedBox(height: TavoSpace.sm),
        TavoCard(
          padding: const EdgeInsets.all(TavoSpace.md),
          child: Column(
            children: <Widget>[
              _detailRow('category'.tr(),
                  category?.name(_language) ?? '—'),
              const Divider(height: TavoSpace.lg, color: TavoColors.border),
              _detailRow('price'.tr(), menuPriceLabel(menuPrice())),
              const Divider(height: TavoSpace.lg, color: TavoColors.border),
              _detailRow(
                'menu_availability'.tr(),
                _active ? 'available'.tr() : 'unavailable'.tr(),
              ),
            ],
          ),
        ),
        if (description.isNotEmpty) ...<Widget>[
          const SizedBox(height: TavoSpace.lg),
          _SectionLabel(icon: Iconsax.message_text, label: 'description'.tr()),
          const SizedBox(height: TavoSpace.xs),
          Text(
            description,
            style: TavoType.bodySmall.copyWith(
              color: TavoColors.mutedForeground,
            ),
          ),
        ],
        if (_specs.isNotEmpty) ...<Widget>[
          const SizedBox(height: TavoSpace.lg),
          _SectionLabel(
            icon: Iconsax.element_3,
            label: 'menu_specifications'.tr(),
          ),
          const SizedBox(height: TavoSpace.xs),
          for (final _SpecDraft spec in _specs)
            Padding(
              padding: const EdgeInsetsDirectional.only(bottom: TavoSpace.sm),
              child: TavoCard(
                padding: const EdgeInsets.all(TavoSpace.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            _language == 'ar' ? spec.ar : spec.en,
                            style: TavoType.label.copyWith(
                              color: TavoColors.foreground,
                            ),
                          ),
                        ),
                        TavoStatusPill(
                          label: spec.required
                              ? 'required'.tr()
                              : 'optional'.tr(),
                          tone: spec.required
                              ? TavoTone.brand
                              : TavoTone.neutral,
                          size: TavoPillSize.small,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      spec.type == 'multiple'
                          ? 'select_multiple_options'.tr()
                          : 'select_one_option'.tr(),
                      style: TavoType.caption.copyWith(
                        color: TavoColors.mutedForeground,
                      ),
                    ),
                    const SizedBox(height: TavoSpace.xs),
                    for (final _OptionDraft option in spec.options)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(top: 2),
                        child: Row(
                          children: <Widget>[
                            const Icon(
                              Iconsax.tick_circle,
                              size: 13,
                              color: TavoColors.success,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                _language == 'ar'
                                    ? option.ar
                                    : option.en,
                                style: TavoType.caption.copyWith(
                                  color: TavoColors.foreground,
                                ),
                              ),
                            ),
                            if ((option.price ?? 0) > 0)
                              Text(
                                '+${menuPriceLabel(option.price ?? 0)}',
                                style: TavoType.caption.copyWith(
                                  color: TavoColors.mutedForeground,
                                  fontFeatures: TavoType.tabular,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: TavoType.caption.copyWith(
            color: TavoColors.mutedForeground,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TavoType.label.copyWith(
              color: TavoColors.foreground,
              fontFeatures: TavoType.tabular,
            ),
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------------- footer

  Widget _footer() {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(
        TavoSpace.lg,
        TavoSpace.sm,
        TavoSpace.lg,
        TavoSpace.md,
      ),
      decoration: const BoxDecoration(
        color: TavoColors.background,
        border: Border(top: BorderSide(color: TavoColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_error != null) ...<Widget>[
            _ErrorBanner(message: _error!),
            const SizedBox(height: TavoSpace.sm),
          ],
          if (!widget.canManage)
            TavoButton.secondary(
              label: 'close'.tr(),
              expand: true,
              onPressed: () => Navigator.of(context).pop(false),
            )
          else
            Row(
              children: <Widget>[
                Expanded(
                  child: TavoButton.secondary(
                    label: 'cancel'.tr(),
                    expand: true,
                    onPressed: _saving
                        ? null
                        : () => Navigator.of(context).pop(false),
                  ),
                ),
                const SizedBox(width: TavoSpace.md),
                Expanded(
                  flex: 2,
                  child: TavoButton.primary(
                    key: const ValueKey<String>('menu_item_save'),
                    label: _isNew ? 'add_item'.tr() : 'save_changes'.tr(),
                    expand: true,
                    isLoading: _saving,
                    loadingSemanticsLabel: 'save'.tr(),
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ save

  double menuPrice() => _parsedPrice() ?? 0;

  double? _parsedPrice() {
    final String raw = _price.text.trim().replaceAll(',', '.');
    if (raw.isEmpty) return 0;
    return double.tryParse(raw);
  }

  PanelMenuCategory? _selectedCategory() {
    for (final PanelMenuCategory category in widget.categories) {
      if (category.id == _categoryId) return category;
    }
    return null;
  }

  String? _validate() {
    if (_arName.text.trim().length < 2 || _enName.text.trim().length < 2) {
      _language =
          _arName.text.trim().length < 2 ? 'ar' : 'en';
      return 'menu_validation_name'.tr();
    }
    final double? price = _parsedPrice();
    if (price == null || price < 0) return 'menu_validation_price'.tr();
    if (_categoryId == null) return 'menu_validation_category'.tr();

    for (final _SpecDraft spec in _specs) {
      if (spec.hasContent && !spec.isPublishable) {
        return 'menu_spec_incomplete'.tr();
      }
    }
    return null;
  }

  Future<void> _save() async {
    if (_saving) return;
    FocusScope.of(context).unfocus();

    final String? validation = _validate();
    if (validation != null) {
      setState(() {
        _showErrors = true;
        _error = validation;
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final List<PanelMenuSpecification> specs = <PanelMenuSpecification>[
      for (final _SpecDraft spec in _specs)
        if (spec.hasContent) spec.toModel(),
    ];

    final bool ok = await widget.cubit.saveItem(
      id: widget.item?.id,
      payload: PanelMenuItemPayload(
        categoryId: _categoryId!,
        arName: _arName.text.trim(),
        enName: _enName.text.trim(),
        price: _parsedPrice() ?? 0,
        arDescription: _arDescription.text.trim(),
        enDescription: _enDescription.text.trim(),
        specifications: specs,
        active: _active,
      ),
    );

    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _saving = false);
    }
  }
}

enum _LanguageTab { ar, en }

// ------------------------------------------------------------------ widgets

class _SegmentOption<T> {
  const _SegmentOption({
    required this.value,
    required this.label,
    required this.key,
    this.complete,
  });

  final T value;
  final String label;
  final Key key;
  final bool? complete;
}

/// Kit-styled segmented control. `complete` renders a small dot: a language
/// tab that still needs its name is visible without opening it.
class _Segmented<T> extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.options,
    required this.onChanged,
    this.dense = false,
  });

  final T value;
  final List<_SegmentOption<T>> options;
  final ValueChanged<T> onChanged;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: dense ? 36 : 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: TavoColors.muted,
        borderRadius: BorderRadius.circular(TavoRadii.pill),
        border: Border.all(color: TavoColors.border),
      ),
      child: Row(
        children: <Widget>[
          for (final _SegmentOption<T> option in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == option.value,
                label: option.label,
                child: GestureDetector(
                  key: option.key,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(option.value),
                  child: AnimatedContainer(
                    duration: TavoMotion.fast,
                    curve: TavoMotion.outStrong,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == option.value
                          ? TavoColors.background
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(TavoRadii.pill),
                      boxShadow: value == option.value
                          ? TavoShadows.sm
                          : TavoShadows.none,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          option.label,
                          style: TavoType.label.copyWith(
                            color: value == option.value
                                ? TavoColors.foreground
                                : TavoColors.mutedForeground,
                            fontSize: dense ? 12 : 13,
                          ),
                        ),
                        if (option.complete != null) ...<Widget>[
                          const SizedBox(width: 5),
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: option.complete!
                                  ? TavoColors.success
                                  : TavoColors.warning,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 15, color: TavoColors.brand800),
        const SizedBox(width: TavoSpace.xs),
        Text(
          label,
          style: TavoType.overline.copyWith(
            color: TavoColors.foreground,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

/// Labelled input with the kit's hairline/brand focus treatment.
class _SheetField extends StatelessWidget {
  const _SheetField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.rtl = false,
    this.ltr = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.keyboardType,
    this.inputFormatters,
    this.suffix,
    this.forceError = false,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool rtl;
  final bool ltr;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final String? suffix;
  final bool forceError;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final bool error = forceError && errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TavoType.caption.copyWith(
            color: error ? TavoColors.destructiveSolid : TavoColors.foreground,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          onChanged: onChanged,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: minLines,
          maxLength: maxLength,
          textDirection:
              rtl ? TextDirection.rtl : (ltr ? TextDirection.ltr : null),
          textAlign: rtl ? TextAlign.right : TextAlign.start,
          style: TavoType.bodySmall.copyWith(color: TavoColors.foreground),
          cursorColor: TavoColors.brand800,
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: TavoType.bodySmall.copyWith(
              color: TavoColors.mutedForeground.withValues(alpha: 0.8),
            ),
            filled: true,
            fillColor: TavoColors.background,
            counterText: '',
            suffixText: suffix,
            suffixStyle: TavoType.caption.copyWith(
              color: TavoColors.mutedForeground,
              fontWeight: FontWeight.w600,
            ),
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
              borderSide: BorderSide(
                color: error ? TavoColors.destructiveSolid : TavoColors.border,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(TavoRadii.md),
              borderSide: BorderSide(
                color: error
                    ? TavoColors.destructiveSolid
                    : TavoColors.brand500,
                width: 1.5,
              ),
            ),
          ),
        ),
        if (error) ...<Widget>[
          const SizedBox(height: 4),
          Text(
            errorText!,
            style: TavoType.caption.copyWith(
              color: TavoColors.destructiveSolid,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
