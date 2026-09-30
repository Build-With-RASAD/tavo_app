import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/network/panel_envelope.dart';

void main() {
  test('panelPayload reads the data field of a panel envelope', () {
    expect(
      panelPayload(const {'success': true, 'data': {'a': 1}}),
      {'a': 1},
    );
    expect(panelPayload(const {'success': true}), isNull);
    expect(panelPayload([1, 2]), isNull);
  });

  test('panelAsMap casts only real maps', () {
    expect(panelAsMap({'x': 1}), {'x': 1});
    expect(panelAsMap(['x']), isNull);
    expect(panelAsMap(null), isNull);
  });

  test('panelUnwrapList accepts the nested page shape', () {
    final out = panelUnwrapList(const {
      'data': [
        {'_id': 'a'}
      ],
      'pagination': {'page': 2, 'limit': 20, 'total': 41, 'pages': 3},
    });
    expect(out.items, hasLength(1));
    expect(out.pagination?['page'], 2);
    expect(out.pagination?['total'], 41);
  });

  test('panelUnwrapList accepts the flat list shape and empty payloads', () {
    final flat = panelUnwrapList([
      {'_id': 'a'},
    ]);
    expect(flat.items, hasLength(1));
    expect(flat.pagination, isNull);

    final empty = panelUnwrapList(const {'nope': true});
    expect(empty.items, isEmpty);
    expect(empty.pagination, isNull);
  });
}
