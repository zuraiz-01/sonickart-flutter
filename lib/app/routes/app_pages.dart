import 'package:get/get.dart';

import '../modules/auth/bindings/auth_binding.dart';
import '../modules/auth/views/login_view.dart';
import '../modules/categories/bindings/categories_binding.dart';
import '../modules/categories/views/categories_view.dart';
import '../modules/customer_order_details_view.dart';
import '../modules/customer_orders_view.dart';
import '../modules/buy_again_view.dart';
import '../modules/dashboard/bindings/dashboard_binding.dart';
import '../modules/dashboard/views/dashboard_view.dart';
import '../modules/live_tracking_view.dart';
import '../modules/order_checkout_view.dart';
import '../modules/order_success_view.dart';
import '../modules/package/package_view.dart';
import '../modules/package/package_order_details_view.dart';
import '../modules/product_detail_view.dart';
import '../modules/profile/address_book_view.dart';
import '../modules/profile/profile_view.dart';
import '../modules/search_view.dart';
import '../modules/splash/bindings/splash_binding.dart';
import '../modules/splash/views/splash_view.dart';
import 'app_routes.dart';

class AppPages {
  static final routes = <GetPage>[
    GetPage(
      name: AppRoutes.splash,
      page: SplashView.new,
      binding: SplashBinding(),
    ),
    GetPage(name: AppRoutes.login, page: LoginView.new, binding: AuthBinding()),
    GetPage(
      name: AppRoutes.signup,
      page: LoginView.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.otpVerification,
      page: LoginView.new,
      binding: AuthBinding(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: DashboardView.new,
      bindings: [AuthBinding(), DashboardBinding()],
    ),
    GetPage(
      name: AppRoutes.categories,
      page: CategoriesView.new,
      binding: CategoriesBinding(),
    ),
    GetPage(
      name: AppRoutes.search,
      page: SearchView.new,
      binding: CategoriesBinding(),
    ),
    GetPage(
      name: AppRoutes.productDetail,
      page: ProductDetailView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.buyAgain,
      page: BuyAgainView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.liveTracking,
      page: LiveTrackingView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.package,
      page: PackageView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.packageDetails,
      page: PackageOrderDetailsView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.profile,
      page: ProfileView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.checkout,
      page: OrderCheckoutView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.orderSuccess,
      page: OrderSuccessView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.customerOrders,
      page: CustomerOrdersView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.customerOrderDetails,
      page: CustomerOrderDetailsView.new,
      binding: DashboardBinding(),
    ),
    GetPage(
      name: AppRoutes.addressBook,
      page: AddressBookView.new,
      binding: DashboardBinding(),
    ),
  ];
}
