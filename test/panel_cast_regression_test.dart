// test/panel_cast_regression_test.dart
//
// Regression: the tables and menu screens crashed with
//   type 'Map<String, dynamic>' is not a subtype of type 'String'
// whenever the panel API populated a reference or localized a label. Both
// parsers must accept populated maps, plain ids and plain strings.
import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/feature/panel_menu/data/model/menu_models.dart';
import 'package:tavo/feature/panel_tables/data/model/table_models.dart';

void main() {
  group('panel menu decoding', () {
    test('a populated menuCategoryId map does not throw', () {
      final item = PanelMenuItem.fromJson({
        '_id': 'm1',
        'menuCategoryId': {
          '_id': 'c1',
          'ar': {'name': 'أطباق رئيسية'},
          'en': {'name': 'Mains'},
        },
        'ar': {'name': 'كبسة'},
        'en': {'name': 'Kabsa', 'description': 'Lamb and rice'},
        'price': 55,
        'image': {'imageUrl': 'https://cdn/kabsa.png'},
      });

      expect(item.id, 'm1');
      expect(item.categoryId, 'c1');
      expect(item.arName, 'كبسة');
      expect(item.enName, 'Kabsa');
      expect(item.description, 'Lamb and rice');
      expect(item.imageUrl, 'https://cdn/kabsa.png');
      expect(item.price, 55);
    });

    test('plain ids, string labels and numeric strings still decode', () {
      final item = PanelMenuItem.fromJson({
        '_id': 'm2',
        'categoryId': 'c2',
        'ar': 'شاي',
        'en': 'Tea',
        'price': '12.5',
        'image': 'https://cdn/tea.png',
      });

      expect(item.categoryId, 'c2');
      expect(item.arName, 'شاي');
      expect(item.enName, 'Tea');
      expect(item.price, 12.5);
      expect(item.imageUrl, 'https://cdn/tea.png');
    });

    test('a category with a localized label map decodes', () {
      final category = PanelMenuCategory.fromJson({
        '_id': 'c1',
        'ar': {'name': 'أطباق'},
        'en': {'name': 'Dishes'},
        'itemCount': '7',
      });

      expect(category.arName, 'أطباق');
      expect(category.enName, 'Dishes');
      expect(category.itemCount, 7);
    });
  });

  group('panel tables decoding', () {
    test('a populated tableTypeId and a map zone do not throw', () {
      final table = PanelPhysicalTable.fromJson({
        '_id': 't1',
        'tableTypeId': {'_id': 'type1', 'label': 'Booth'},
        'code': 'A12',
        'seats': '4',
        'status': 'available',
        'zone': {'ar': 'التراس', 'en': 'Terrace'},
        'occupied': true,
        'position': {'x': '1.5', 'y': 2},
      });

      expect(table.id, 't1');
      expect(table.tableTypeId, 'type1');
      expect(table.seats, 4);
      expect(table.zone, 'التراس');
      expect(table.occupied, isTrue);
      expect(table.x, 1.5);
      expect(table.y, 2);
      expect(table.positioned, isTrue);
    });

    test('a plain string zone is preserved', () {
      final table = PanelPhysicalTable.fromJson({
        '_id': 't2',
        'tableTypeId': 'type1',
        'code': 'B2',
        'zone': 'Garden',
      });

      expect(table.zone, 'Garden');
      expect(table.status, 'available');
      expect(table.occupied, isNull);
      expect(table.positioned, isFalse);
    });
  });
}
