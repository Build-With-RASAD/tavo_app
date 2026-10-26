// lib/feature/panel_menu/data/model/menu_models.dart
//
// Every field is decoded through a tolerant helper. The panel receives
// populated references (`menuCategoryId: {_id, ar: {name}}`), plain ids and
// occasionally localized strings; a hard `as String` cast turned any of those
// shapes into a runtime crash on the menu screen.
//
// Specifications are stored per language in Mongo (`ar.specifications`,
// `en.specifications`). The editor works with ONE group that carries both
// titles, so [PanelMenuSpecification.fromLocales] pairs the two arrays by
// `key` (falling back to position) and [PanelMenuItemPayload] writes them
// back as two parallel arrays.
String _text(Object? value) {
  if (value == null) return '';
  if (value is Map) {
    // A populated reference — the id is the only stable value.
    return (value['_id'] ?? value['id'] ?? value['code'] ?? '').toString();
  }
  return value.toString();
}

/// Reads `{ar: {name: '...'}}`, `{ar: '...'}` and `{ar: {ar: '...'}}` alike.
String _localized(Object? block, String field) {
  if (block == null) return '';
  if (block is String) return block;
  if (block is! Map) return block.toString();

  final value = block[field];
  if (value is String) return value;
  if (value is Map) {
    final nested = value['ar'] ?? value['en'] ?? value['name'];
    if (nested is String) return nested;
    if (nested is Map) return (nested['ar'] ?? nested['en'] ?? '').toString();
  }
  return value?.toString() ?? '';
}

double _double(Object? value) =>
    value is num ? value.toDouble() : double.tryParse('${value ?? ''}') ?? 0;

List<Map<String, dynamic>> _maps(Object? value) => value is List
    ? value
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList()
    : const [];

/// One selectable choice inside a specification ("Classic crust").
class PanelMenuOption {
  const PanelMenuOption({
    this.arTitle = '',
    this.enTitle = '',
    this.price = 0,
  });

  final String arTitle;
  final String enTitle;
  final double price;

  String title(String locale) =>
      locale == 'ar' ? (arTitle.isEmpty ? enTitle : arTitle) : (enTitle.isEmpty ? arTitle : enTitle);

  PanelMenuOption copyWith({String? arTitle, String? enTitle, double? price}) =>
      PanelMenuOption(
        arTitle: arTitle ?? this.arTitle,
        enTitle: enTitle ?? this.enTitle,
        price: price ?? this.price,
      );
}

/// A choose-one / choose-many group ("Dough", "Size") with its bilingual
/// titles and the same ordered options in both languages.
class PanelMenuSpecification {
  const PanelMenuSpecification({
    this.key = '',
    this.arTitle = '',
    this.enTitle = '',
    this.type = 'single',
    this.required = false,
    this.options = const [],
  });

  final String key;
  final String arTitle;
  final String enTitle;

  /// `single` (radio) or `multiple` (checkbox).
  final String type;

  /// True when the guest must pick one before ordering.
  final bool required;

  final List<PanelMenuOption> options;

  bool get isRequired => required;
  bool get isMultiple => type == 'multiple';

  String title(String locale) => locale == 'ar'
      ? (arTitle.isEmpty ? enTitle : arTitle)
      : (enTitle.isEmpty ? arTitle : enTitle);

  PanelMenuSpecification copyWith({
    String? key,
    String? arTitle,
    String? enTitle,
    String? type,
    bool? required,
    List<PanelMenuOption>? options,
  }) =>
      PanelMenuSpecification(
        key: key ?? this.key,
        arTitle: arTitle ?? this.arTitle,
        enTitle: enTitle ?? this.enTitle,
        type: type ?? this.type,
        required: required ?? this.required,
        options: options ?? this.options,
      );

  /// Pairs the two localized arrays. `key` is the join column; when the
  /// backend has no keys (older rows) the position is used instead, which is
  /// exactly how the editor writes them.
  static List<PanelMenuSpecification> fromLocales(Object? ar, Object? en) {
    final arGroups = _maps(ar);
    final enGroups = _maps(en);
    if (arGroups.isEmpty && enGroups.isEmpty) return const [];

    final byKey = <String, Map<String, dynamic>>{
      for (final group in arGroups)
        if (_text(group['key']).isNotEmpty) _text(group['key']): group,
    };

    // The widest side decides how many groups exist: a group that only has an
    // English title must still be editable (and visible as untranslated).
    final length = arGroups.length > enGroups.length
        ? arGroups.length
        : enGroups.length;

    return [
      for (var i = 0; i < length; i++)
        () {
          final arGroup = i < arGroups.length ? arGroups[i] : null;
          final enGroup = i < enGroups.length ? enGroups[i] : null;
          final key = _text(enGroup?['key'] ?? arGroup?['key']);
          final paired = key.isEmpty
              ? null
              : byKey[key];
          final arOptions = _maps((paired ?? arGroup)?['options']);
          final enOptions = _maps((enGroup ?? paired)?['options']);
          final optionsLength = arOptions.length > enOptions.length
              ? arOptions.length
              : enOptions.length;
          final type = _text((enGroup ?? arGroup)?['type']);
          return PanelMenuSpecification(
            key: key,
            arTitle: _text((paired ?? arGroup)?['title']),
            enTitle: _text((enGroup ?? paired)?['title']),
            type: type == 'multiple' ? 'multiple' : 'single',
            required: (enGroup ?? arGroup)?['required'] == true,
            options: [
              for (var j = 0; j < optionsLength; j++)
                PanelMenuOption(
                  arTitle: _text(
                    j < arOptions.length ? arOptions[j]['title'] : null,
                  ),
                  enTitle: _text(
                    j < enOptions.length ? enOptions[j]['title'] : null,
                  ),
                  price: _double(
                    j < enOptions.length
                        ? enOptions[j]['price']
                        : (j < arOptions.length ? arOptions[j]['price'] : 0),
                  ),
                ),
            ],
          );
        }(),
    ];
  }

  /// True when the group is complete enough to publish: a title in both
  /// languages and at least one option in both.
  bool get isPublishable =>
      arTitle.trim().isNotEmpty &&
      enTitle.trim().isNotEmpty &&
      options.isNotEmpty &&
      options.every((o) => o.arTitle.trim().isNotEmpty && o.enTitle.trim().isNotEmpty);
}

class PanelMenuCategory {
  const PanelMenuCategory({
    required this.id,
    required this.arName,
    required this.enName,
    this.itemCount = 0,
  });

  final String id;
  final String arName;
  final String enName;
  final int itemCount;

  String name(String locale) =>
      locale == 'ar' ? (arName.isEmpty ? enName : arName) : (enName.isEmpty ? arName : enName);

  factory PanelMenuCategory.fromJson(Map<String, dynamic> json) =>
      PanelMenuCategory(
        id: _text(json['_id'] ?? json['id']),
        arName: _localized(json['ar'], 'name'),
        enName: _localized(json['en'], 'name'),
        itemCount: _double(json['itemCount']).toInt(),
      );
}

class PanelMenuItem {
  const PanelMenuItem({
    required this.id,
    required this.categoryId,
    required this.arName,
    required this.enName,
    required this.price,
    required this.active,
    this.imageUrl,
    this.arDescription = '',
    this.enDescription = '',
    this.specifications = const [],
  });

  final String id;
  final String categoryId;
  final String arName;
  final String enName;
  final double price;
  final bool active;
  final String? imageUrl;
  final String arDescription;
  final String enDescription;
  final List<PanelMenuSpecification> specifications;

  String name(String locale) =>
      locale == 'ar' ? (arName.isEmpty ? enName : arName) : (enName.isEmpty ? arName : enName);

  String description(String locale) => locale == 'ar'
      ? (arDescription.isEmpty ? enDescription : arDescription)
      : (enDescription.isEmpty ? arDescription : enDescription);

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasSpecifications => specifications.isNotEmpty;

  factory PanelMenuItem.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    final imageUrl = image is Map
        ? _text(image['imageUrl'] ?? image['url'])
        : _text(image);

    return PanelMenuItem(
      id: _text(json['_id'] ?? json['id']),
      categoryId: _text(json['menuCategoryId'] ?? json['categoryId']),
      arName: _localized(json['ar'], 'name'),
      enName: _localized(json['en'], 'name'),
      price: _double(json['price']),
      active: _text(json['status']) != 'inactive',
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      arDescription: _localized(json['ar'], 'description'),
      enDescription: _localized(json['en'], 'description'),
      specifications: PanelMenuSpecification.fromLocales(
        json['ar'] is Map ? (json['ar'] as Map)['specifications'] : null,
        json['en'] is Map ? (json['en'] as Map)['specifications'] : null,
      ),
    );
  }

  PanelMenuItem copyWith({
    String? categoryId,
    String? arName,
    String? enName,
    double? price,
    bool? active,
    String? imageUrl,
    bool clearImage = false,
    String? arDescription,
    String? enDescription,
    List<PanelMenuSpecification>? specifications,
  }) =>
      PanelMenuItem(
        id: id,
        categoryId: categoryId ?? this.categoryId,
        arName: arName ?? this.arName,
        enName: enName ?? this.enName,
        price: price ?? this.price,
        active: active ?? this.active,
        imageUrl: clearImage ? null : (imageUrl ?? this.imageUrl),
        arDescription: arDescription ?? this.arDescription,
        enDescription: enDescription ?? this.enDescription,
        specifications: specifications ?? this.specifications,
      );
}

/// What the editor sends to `POST /menu` and `PUT /menu/:id`.
///
/// Both languages are always sent: the update service replaces each localized
/// subdocument wholesale, so a partial payload would drop the other language.
class PanelMenuItemPayload {
  const PanelMenuItemPayload({
    required this.categoryId,
    required this.arName,
    required this.enName,
    required this.price,
    this.arDescription = '',
    this.enDescription = '',
    this.specifications = const [],
    this.active = true,
  });

  final String categoryId;
  final String arName;
  final String enName;
  final double price;
  final String arDescription;
  final String enDescription;
  final List<PanelMenuSpecification> specifications;

  /// Availability. Sent with the write so the document never flips active
  /// between a create/update and a second toggle request.
  final bool active;

  /// Only complete groups are published — a half-filled row would make the
  /// guest menu render an empty choice list.
  List<PanelMenuSpecification> get publishableSpecifications =>
      specifications.where((s) => s.isPublishable).toList();

  /// Pairs each publishable group with the key written to both languages.
  /// A group without a key gets a slug of its English title; duplicates get
  /// `-2`, `-3`, … so the guest UI never sees two `size` groups.
  List<({PanelMenuSpecification group, String key})> _keyedGroups() {
    final used = <String>{};
    return [
      for (var i = 0; i < publishableSpecifications.length; i++)
        () {
          final PanelMenuSpecification group = publishableSpecifications[i];
          final String base = group.key.trim().isNotEmpty
              ? group.key.trim()
              : menuSpecKey(group.enTitle, index: i);
          var key = base;
          var suffix = 2;
          while (!used.add(key)) {
            key = '$base-$suffix';
            suffix += 1;
          }
          return (group: group, key: key);
        }(),
    ];
  }

  Map<String, dynamic> toJson() {
    final groups = _keyedGroups();
    return {
      'categoryId': categoryId,
      'price': price,
      'status': active ? 'active' : 'inactive',
      'ar': {
        'name': arName.trim(),
        if (arDescription.trim().isNotEmpty)
          'description': arDescription.trim(),
        'specifications': [
          for (final entry in groups)
            {
              'key': entry.key,
              'title': entry.group.arTitle.trim(),
              'type': entry.group.type,
              'required': entry.group.required,
              'options': [
                for (final option in entry.group.options)
                  {
                    'title': option.arTitle.trim(),
                    'price': option.price,
                  },
              ],
            },
        ],
      },
      'en': {
        'name': enName.trim(),
        if (enDescription.trim().isNotEmpty)
          'description': enDescription.trim(),
        'specifications': [
          for (final entry in groups)
            {
              'key': entry.key,
              'title': entry.group.enTitle.trim(),
              'type': entry.group.type,
              'required': entry.group.required,
              'options': [
                for (final option in entry.group.options)
                  {
                    'title': option.enTitle.trim(),
                    'price': option.price,
                  },
              ],
            },
        ],
      },
    };
  }
}

/// A stable, URL-safe spec key derived from the English title. Falls back to
/// a positional key when the title has no latin characters yet.
String menuSpecKey(String title, {int index = 0}) {
  final slug = title
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (slug.isEmpty) return 'option-${index + 1}';
  final capped = slug.length > 40 ? slug.substring(0, 40) : slug;
  return capped.replaceAll(RegExp(r'-+$'), '');
}
