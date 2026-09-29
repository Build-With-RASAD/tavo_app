import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tavo/core/cache/cache_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('active restaurant round-trips and is cleared with user data',
      () async {
    SharedPreferences.setMockInitialValues({});
    await CacheHelper.init();

    await CacheHelper.setActiveRestaurant('r9');
    expect(CacheHelper.getActiveRestaurant(), 'r9');

    await CacheHelper.clearUserData();
    expect(CacheHelper.getActiveRestaurant(), isNull);
  });
}
