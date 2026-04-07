class ApiConstants {
  static const baseUrl = 'https://api.soniccart.com/v1';

  static const login = '/auth/login';
  static const signup = '/auth/signup';
  static const verifyOtp = '/auth/verify-otp';
  static const dashboard = '/customer/dashboard';
  static const categories = '/categories';

  static String productsByCategory(String categoryId) =>
      '/categories/$categoryId/products';
}
