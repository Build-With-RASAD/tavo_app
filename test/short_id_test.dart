import 'package:flutter_test/flutter_test.dart';
import 'package:tavo/core/helpers/utils/short_id.dart';

/// Regression tests for order/booking id shortening.
///
/// The inline implementation used `value.substring(0, 8)` unguarded, which
/// throws `RangeError` while building the reservations list or the order
/// success sheet whenever an id is shorter than 8 characters (or empty).
void main() {
  group('shortId', () {
    test('truncates a long id to its first 8 characters, uppercased', () {
      expect(shortId('6521af4c9b3e1a0012345678'), '6521AF4C');
    });

    test('returns ids shorter than 8 characters intact (no RangeError)',
        () {
      expect(shortId('abc123'), 'ABC123');
      expect(shortId('1'), '1');
    });

    test('returns an empty string for an empty id (no RangeError)', () {
      expect(shortId(''), '');
    });

    test('already-uppercase input is unchanged apart from truncation', () {
      expect(shortId('ABCDEFGH1234'), 'ABCDEFGH');
    });
  });
}
