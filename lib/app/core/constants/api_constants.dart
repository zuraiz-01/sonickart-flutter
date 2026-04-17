class ApiConstants {
  static const mobileHost = 'https://api.sonickartnow.com/mobile';
  static const baseUrl = '$mobileHost/api';

  // Auth
  static const customerLogin = '/customer/login';
  static const login = customerLogin;
  static const signup = '/auth/signup';
  static const verifyOtp = '/auth/verify-otp';
  static const refreshToken = '/refresh-token';
  static const user = '/user';
  static const dashboard = '/customer/dashboard';

  // Catalog
  static const categories = '/categories';
  static const productSearch = '/products/search';

  // Cart (legacy compatible)
  static const cart = '/cart';
  static const cartAdd = '/cart/add';
  static const cartRemove = '/cart/remove';
  static const cartClear = '/cart/clear';
  static const cartFetch = '/cart/fetch';
  static const cartApplyCoupon = '/cart/apply-coupon';

  // Orders
  static const orders = '/order';
  static const packageOrder = '/order/package';
  static const customerOrders = '/order';
  static const packageOrders = '/order/package';

  // Address
  static const addressSave = '/address/save';
  static const addressList = '/address/list';
  static const resolveVendor = '/address/resolve-vendor';
  static const addresses = addressSave;

  // Payment
  static const paymentOrder = '/payment/create-order';
  static const paymentVerify = '/payment/verify';

  static String productsByCategory(String categoryId) => '/products/$categoryId';

  static String orderById(String id) => '/order/$id';

  static String packageOrderById(String id) => '/order/package/$id';

  static String addressById(String id) => '/address/$id';
}
