// lib/feature/panel_menu/data/model/menu_models.dart
//
// Every field is decoded through a tolerant helper. The panel receives
// populated references (`menuCategoryId: {_id, ar: {name}}`), plain ids and
// occasionally localized strings; a hard `as String` cast turned any of those
// shapes into a runtime crash on the menu screen.
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

  factory PanelMenuCategory.fromJson(Map<String, dynamic> json) =>
      PanelMenuCategory(
        id: _text(json['_id'] ?? json['id']),
        arName: _localized(json['ar'], 'name'),
        enName: _localized(json['en'], 'name'),
        itemCount: (json['itemCount'] is num)
            ? (json['itemCount'] as num).toInt()
            : int.tryParse('${json['itemCount'] ?? ''}') ?? 0,
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
    this.description,
  });

  final String id;
  final String categoryId;
  final String arName;
  final String enName;
  final double price;
  final bool active;
  final String? imageUrl;
  final String? description;

  factory PanelMenuItem.fromJson(Map<String, dynamic> json) {
    final image = json['image'];
    final imageUrl = image is Map
        ? _text(image['imageUrl'] ?? image['url'])
        : _text(image);
    final description = _localized(json['en'], 'description');

    return PanelMenuItem(
      id: _text(json['_id'] ?? json['id']),
      categoryId: _text(json['menuCategoryId'] ?? json['categoryId']),
      arName: _localized(json['ar'], 'name'),
      enName: _localized(json['en'], 'name'),
      price: (json['price'] is num)
          ? (json['price'] as num).toDouble()
          : double.tryParse('${json['price'] ?? ''}') ?? 0,
      active: _text(json['status']) != 'inactive',
      imageUrl: imageUrl.isEmpty ? null : imageUrl,
      description: description.isEmpty ? null : description,
    );
  }
}
