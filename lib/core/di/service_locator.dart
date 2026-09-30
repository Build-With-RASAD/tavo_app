// lib/core/di/service_locator.dart
import 'package:get_it/get_it.dart';
import 'package:tavo/core/cache/cache_helper.dart';
import 'package:tavo/core/network/api_service.dart';
import 'package:tavo/feature/booking/data/repo/bookings_repo.dart';
import 'package:tavo/feature/booking/ui/logic/bookings_cubit.dart';
import 'package:tavo/feature/notifications/data/repo/notifications_repo.dart';
import 'package:tavo/feature/notifications/ui/logic/notifications_cubit.dart';
import 'package:tavo/feature/panel_menu/di/register_menu_module.dart';
import 'package:tavo/feature/panel_reviews/di/register_reviews_module.dart';
import 'package:tavo/feature/panel_settings/di/register_settings_module.dart';
import 'package:tavo/feature/panel_staff/di/register_staff_module.dart';
import 'package:tavo/feature/panel_tables/di/register_tables_module.dart';
import 'package:tavo/feature/panel_waitlist/di/register_waitlist_module.dart';
import 'package:tavo/feature/panel_customers/di/register_customers_module.dart';
import 'package:tavo/feature/panel_branches/di/register_branches_module.dart';
import 'package:tavo/feature/panel_contact/di/register_contact_module.dart';
import 'package:tavo/feature/panel_dashboard/di/register_dashboard_module.dart';
import 'package:tavo/feature/panel_invoice/di/register_invoice_module.dart';
import 'package:tavo/feature/Profile/ui/logic/cubit/profile_cubit.dart';
import 'package:tavo/feature/Profile/data/repo/profile_repo.dart';
import 'package:tavo/feature/auth/ui/data/repo/auth_repo.dart';
import 'package:tavo/feature/auth/ui/logic/cubit/auth_cubit.dart';
import 'package:tavo/feature/home/data/repo/home_repo.dart';
import 'package:tavo/feature/home/ui/logic/cubit/home_cubit.dart';
import 'package:tavo/feature/restaurant/data/repo/menu_item_specification_repo.dart';
import 'package:tavo/feature/restaurant/data/repo/menu_repo.dart';
import 'package:tavo/feature/restaurant/data/repo/order_repo.dart';
import 'package:tavo/feature/restaurant/data/repo/restaurant_details_repo.dart';
import 'package:tavo/feature/restaurant/data/repo/restaurants_repo.dart';
import 'package:tavo/feature/restaurant_auth/data/repo/restaurant_auth_repo.dart';
import 'package:tavo/feature/restaurant_panel/data/repo/restaurant_panel_repo.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/dashboard_cubit.dart';
import 'package:tavo/feature/restaurant_panel/ui/logic/orders_cubit.dart';
import 'package:tavo/feature/restaurant/ui/logic/menu_cubit.dart';
import 'package:tavo/feature/restaurant/ui/logic/menu_item_specification_cubit.dart';
import 'package:tavo/feature/restaurant/ui/logic/order_cubit.dart';
import 'package:tavo/feature/restaurant/ui/logic/restaurant_details_cubit.dart';
import 'package:tavo/feature/restaurant/ui/logic/restaurants_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_auth_cubit.dart';
import 'package:tavo/feature/restaurant_auth/ui/logic/restaurant_home_cubit.dart';

final getIt = GetIt.instance;

Future<void> initServiceLocator() async {
  await CacheHelper.init();

  // Services
  getIt.registerLazySingleton<ApiService>(() => ApiService());

  // Repositories
  getIt.registerLazySingleton<AuthRepo>(() => AuthRepo(getIt<ApiService>()));
  getIt.registerLazySingleton<HomeRepo>(() => HomeRepo(getIt<ApiService>()));
  getIt.registerLazySingleton<RestaurantsRepo>(
    () => RestaurantsRepo(getIt<ApiService>()),
  );
  getIt.registerLazySingleton<RestaurantDetailsRepo>(
    () => RestaurantDetailsRepo(getIt<ApiService>()),
  );
  getIt.registerLazySingleton<MenuRepo>(() => MenuRepo(getIt<ApiService>()));
  getIt.registerLazySingleton<ProfileRepo>(
    () => ProfileRepo(getIt<ApiService>()),
  );

  // Cubits
  getIt.registerFactory<AuthCubit>(() => AuthCubit(getIt<AuthRepo>()));
  getIt.registerFactory<HomeCubit>(() => HomeCubit(getIt<HomeRepo>()));
  getIt.registerFactory<ProfileCubit>(
    () => ProfileCubit(getIt<ProfileRepo>()),
  ); // ✅ Only ONCE
  getIt.registerFactory<RestaurantDetailsCubit>(
    () => RestaurantDetailsCubit(getIt<RestaurantDetailsRepo>()),
  );
  getIt.registerFactoryParam<RestaurantsCubit, String, void>(
    (locale, _) => RestaurantsCubit(getIt<RestaurantsRepo>(), locale: locale),
  );
  getIt.registerFactoryParam<MenuCubit, String, void>(
    (restaurantId, _) =>
        MenuCubit(getIt<MenuRepo>(), restaurantId: restaurantId),
  );
  getIt.registerLazySingleton<MenuItemSpecificationRepo>(
    () => MenuItemSpecificationRepo(getIt<ApiService>()),
  );

  getIt.registerFactoryParam<MenuItemSpecificationCubit, String, String>(
    (restaurantId, menuItemId) => MenuItemSpecificationCubit(
      getIt<MenuItemSpecificationRepo>(),
      restaurantId: restaurantId,
      menuItemId: menuItemId,
    ),
  );
  getIt.registerLazySingleton<OrderRepo>(() => OrderRepo(getIt<ApiService>()));

  getIt.registerFactoryParam<OrderCubit, String, void>(
    (restaurantId, _) =>
        OrderCubit(getIt<OrderRepo>(), restaurantId: restaurantId),
  );
  getIt.registerLazySingleton<BookingsRepo>(
    () => BookingsRepo(getIt<ApiService>()),
  );

  getIt.registerLazySingleton<RestaurantAuthRepo>(
    () => RestaurantAuthRepo(getIt<ApiService>()),
  );

  getIt.registerFactory<RestaurantAuthCubit>(
    () => RestaurantAuthCubit(getIt<RestaurantAuthRepo>()),
  );

  getIt.registerFactoryParam<RestaurantHomeCubit, String, void>(
    (restaurantId, _) =>
        RestaurantHomeCubit(getIt<RestaurantPanelRepo>(), restaurantId: restaurantId),
  );

  // Staff panel (dashboard / orders / reservations tabs of the shell).
  getIt.registerFactory<RestaurantPanelRepo>(
    () => RestaurantPanelRepo(getIt<ApiService>()),
  );
  getIt.registerFactory<DashboardCubit>(
    () => DashboardCubit(getIt<RestaurantPanelRepo>()),
  );
  getIt.registerFactoryParam<OrdersCubit, String, void>(
    (restaurantId, _) =>
        OrdersCubit(getIt<RestaurantPanelRepo>(), restaurantId: restaurantId),
  );

  getIt.registerFactory<BookingsCubit>(
    () => BookingsCubit(getIt<BookingsRepo>()),
  );
  getIt.registerLazySingleton<NotificationsRepo>(
    () => NotificationsRepo(getIt<ApiService>()),
  );

  getIt.registerFactory<NotificationsCubit>(
    () => NotificationsCubit(getIt<NotificationsRepo>()),
  );

  // Wave 1 panel modules (one-liners reported by module tasks; controller-owned file).
  registerMenuModule();
  registerReviewsModule();
  registerTablesModule();
  registerStaffModule();
  registerSettingsModule();
  registerWaitlistModule();
  registerCustomersModule();
  registerBranchesModule();
  registerContactModule();
  registerDashboardModule(); // Wave E2: dashboard extras (floor/waitlist/orders)
  registerInvoiceModule(); // Wave E2: invoice screen
}
