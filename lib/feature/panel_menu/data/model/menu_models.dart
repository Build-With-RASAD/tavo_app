// lib/feature/panel_menu/data/model/menu_models.dart
class PanelMenuCategory {
  const PanelMenuCategory(
      {required this.id,
      required this.arName,
      required this.enName,
      this.itemCount = 0});
  final String id;
  final String arName;
  final String enName;
  final int itemCount;

  factory PanelMenuCategory.fromJson(Map<String, dynamic> json) =>
      PanelMenuCategory(
        id: json['_id'] as String? ?? '',
        arName: (json['ar'] is Map ? (json['ar']['name'] ?? '') : '') as String,
        enName: (json['en'] is Map ? (json['en']['name'] ?? '') : '') as String,
        itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
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

  factory PanelMenuItem.fromJson(Map<String, dynamic> json) => PanelMenuItem(
        id: json['_id'] as String? ?? '',
        categoryId:
            (json['menuCategoryId'] ?? json['categoryId'] ?? '') as String,
        arName: (json['ar'] is Map ? (json['ar']['name'] ?? '') : '') as String,
        enName: (json['en'] is Map ? (json['en']['name'] ?? '') : '') as String,
        price: (json['price'] as num?)?.toDouble() ?? 0,
        active: (json['status'] as String?) != 'inactive',
        imageUrl:
            json['image'] is Map ? json['image']['imageUrl'] as String? : null,
        description:
            (json['en'] is Map ? (json['en']['description'] ?? '') : '')
                as String?,
      );
}
