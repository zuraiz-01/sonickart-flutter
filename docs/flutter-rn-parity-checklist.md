# Flutter vs React Native Parity Checklist

Source apps:

- Flutter: `E:\work space\zia tech projects\soniccart_flutter`
- React Native: `E:\work space\zia tech projects\soniccart_flutter\react-native app\sonic cart ecommers REACT_NATIVE`

Status key:

- `Done`: Flutter side has a usable equivalent flow.
- `Partial`: Flutter side exists but is simplified, fallback-heavy, or missing important RN behavior.
- `Missing`: RN feature exists but no real Flutter equivalent was found.

## High-Level Summary

| Area | RN Status | Flutter Status | Notes |
|---|---|---|---|
| App bootstrap and navigation | Mature | `Done` | Flutter app shell is present with GetX routes and splash gating. |
| Customer auth | Mature | `Partial` | Firebase OTP + backend login exists in Flutter, but RN session handling is more mature. |
| Dashboard and catalog browsing | Mature | `Partial` | Flutter screens exist, but RN has richer data shaping and fewer static fallbacks. |
| Search | Mature | `Done` | Core search flow exists in Flutter. |
| Cart | Mature | `Partial` | Flutter syncs cart and storage, but RN store/service flow is broader. |
| Address book and vendor resolution | Mature | `Partial` | Flutter has strong progress here, but RN location state is still more complete. |
| Checkout and order placement | Mature | `Partial` | Flutter flow works, but order breakdown/payment depth is behind RN. |
| Live order tracking | Mature | `Missing` | Flutter only has a simplified tracking screen, not RN live map/socket behavior. |
| Package delivery flow | Mature | `Partial` | Flutter package flow exists, but RN has better API/error handling and richer detail flow. |
| Online payment | Mature | `Missing` | RN has Razorpay service wrappers; Flutter equivalent not found. |
| Delivery partner app flows | Present in codebase | `Missing` | No delivery-side Flutter app flow found. |
| Session expired handling | Mature | `Missing` | RN has global session modal flow; Flutter only has token refresh and route fallback. |
| Delivery settings / radius behavior | Mature | `Missing` | RN has dedicated delivery settings store/service; Flutter has no equivalent module. |
| Automated tests | Some targeted tests | `Missing` | Flutter only has default widget test. |

## Detailed Checklist

### 1. App Shell, Routing, Startup

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Root app container with providers | `App.tsx` | `Done` | `lib/main.dart` | Keep aligned. |
| Splash redirect based on session | `src/features/auth/SplashScreen.tsx` | `Done` | `lib/app/modules/splash/controllers/splash_controller.dart` | No immediate gap. |
| Main customer navigation stack | `src/navigation/Navigation.tsx` | `Done` | `lib/app/routes/app_pages.dart` | Keep route parity updated as features land. |

### 2. Customer Authentication

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Customer login screen | `src/features/auth/CustomerLogin.tsx` | `Done` | `lib/app/modules/auth/views/login_view.dart` | UI parity can still improve. |
| Firebase-backed customer login fallback payload | `src/service/authService.tsx` | `Done` | `lib/app/data/repositories/auth_repository.dart` | Already ported in principle. |
| OTP flow, resend, verification | `src/features/auth/CustomerLogin.tsx` | `Done` | `lib/app/modules/auth/controllers/auth_controller.dart` | Validate on real devices. |
| Refresh token flow | `src/service/authService.tsx`, `src/service/apiInterceptors.tsx` | `Partial` | `lib/app/core/network/api_service.dart` | Flutter refresh exists, but no global expired-session UX. |
| Global session expired modal | `src/components/ui/SessionExpiredModal.tsx` | `Missing` | Not found | Add a central expired-session UX flow. |

### 3. Dashboard, Categories, Products

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Product dashboard | `src/features/dashboard/ProductDashboard.tsx` | `Done` | `lib/app/modules/dashboard/views/dashboard_view.dart` | Core customer home exists. |
| Animated/visual dashboard extras | `AnimatedHeader.tsx`, `NoticeAnimation.tsx`, `Visuals.tsx` | `Partial` | `dashboard_view.dart` | Flutter is functionally present but visually simpler. |
| Categories listing | `src/features/category/ProductCategories.tsx` | `Done` | `lib/app/modules/categories/views/categories_view.dart` | Core parity exists. |
| Category-based products | `src/service/productService.tsx` | `Partial` | `lib/app/data/repositories/catalog_repository.dart` | Flutter falls back to static sample data. |
| Vendor-aware product loading | `src/hooks/useVendorLocationContext.ts`, `productService.tsx` | `Partial` | `catalog_repository.dart`, `profile_controller.dart` | Flutter passes `selectedVendorId`, but overall routing context is thinner. |
| Product detail | `src/features/product/ProductDetail.tsx` | `Done` | `lib/app/modules/product_detail_view.dart` | Feature exists. |
| Buy again | `src/features/dashboard/BuyAgainScreen.tsx` | `Done` | `lib/app/modules/buy_again_view.dart` | Verify UX parity later. |

### 4. Search

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Search screen | `src/features/search/SearchScreen.tsx` | `Done` | `lib/app/modules/search_view.dart` | Core feature exists. |
| Search with vendor/radius context | `src/service/productService.tsx` | `Partial` | `catalog_repository.dart` | Search works, but dependency on selected location/vendor needs stronger validation. |

### 5. Cart

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Persisted cart store | `src/state/cartStore.tsx` | `Done` | `lib/app/modules/cart/controllers/cart_controller.dart` | Same concept exists. |
| Cart backend sync | `src/service/cartService.tsx`, `cartStore.tsx` | `Partial` | `cart_controller.dart` | Flutter sync exists, but is less structured and more fallback-based. |
| Cart summary bar / add-remove widgets | `CartSummary.tsx`, `UniversalAdd.tsx` | `Done` | `lib/app/modules/cart/widgets/cart_summary_bar.dart`, `universal_add.dart` | Good parity. |
| Coupon application linked to cart backend | `cartStore.tsx`, coupon service | `Missing` | Only local coupon logic in `order_controller.dart` | Port backend-backed coupon flow if required. |

### 6. Profile and Address Book

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Customer profile screen | `src/features/profile/Profile.tsx` | `Done` | `lib/app/modules/profile/profile_view.dart` | Basic parity exists. |
| Edit profile | `authService.tsx` user update methods | `Partial` | `profile_controller.dart` | Flutter saves local profile; backend profile update equivalent not found. |
| Address CRUD | `src/features/profile/AddressBook.tsx`, `src/service/addressService.tsx` | `Done` | `profile_controller.dart`, `address_book_view.dart` | This is one of the strongest Flutter ports. |
| Vendor resolution from address | `addressService.tsx` | `Done` | `profile_controller.dart` | Flutter has `/address/resolve-vendor` usage. |
| Selected address persistence | `src/state/locationStore.tsx` | `Done` | `GetStorage` use in `profile_controller.dart` | Implemented differently but works. |
| Dedicated shared location store | `src/state/locationStore.tsx` | `Missing` | Not found | Add if multiple modules need cleaner shared location state. |
| Google place autocomplete/details | map/address-related utils | `Done` | `lib/app/core/services/location_lookup_service.dart` | Ported. |
| Profile extra sections: rewards, gift cards, refunds, suggestions | Profile feature set | `Missing` | Placeholder text in `profile_view.dart` | Either implement or hide. |
| Wallet section | `WalletSection.tsx` | `Missing` | Placeholder only in `profile_view.dart` | Not ported. |

### 7. Checkout and Orders

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Product order checkout screen | `src/features/order/ProductOrder.tsx` | `Done` | `lib/app/modules/order_checkout_view.dart` | Main flow exists. |
| Order create API payload with vendor/branch/address context | `src/service/orderService.tsx` | `Partial` | `lib/app/modules/order_controller.dart` | Flutter sends basic payload, but RN breakdown is richer. |
| Order totals breakdown | `checkoutTotals.ts`, `BillDetails.tsx` | `Missing` | Very simple total calc in Flutter | Port delivery fee/tax/coupon structure if backend expects it. |
| Customer orders list | `src/features/order/CustomerOrders.tsx` | `Done` | `lib/app/modules/customer_orders_view.dart` | Screen exists. |
| Customer order detail | `src/features/order/OrderItem.tsx`, detail flow | `Done` | `lib/app/modules/customer_order_details_view.dart` | Screen exists. |
| Cancel order with reason | `LiveTracking.tsx`, `CancellationReasonModal.tsx` | `Partial` | `order_controller.dart` | Flutter cancels with a fixed reason only. |
| Persist current active order globally | `authStore.tsx` | `Missing` | Not found | Add if live tracking/state restoration matters. |

### 8. Live Tracking and Realtime Updates

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Global order socket listener | `src/components/GlobalOrderSocketListener.tsx` | `Missing` | Not found | Port websocket/socket.io listener. |
| Live tracking screen with dynamic map | `src/features/map/LiveTracking.tsx`, `LiveMap.tsx` | `Missing` | `lib/app/modules/live_tracking_view.dart` is static/simplified | Major parity gap. |
| Driver location, ETA, distance updates | `LiveTracking.tsx` | `Missing` | Simplified ETA only in `live_tracking_view.dart` | Implement real order refresh and location tracking. |
| Delivery partner call CTA | `LiveTracking.tsx` | `Missing` | Not found | Add once live order payload supports it. |
| Order status pushed in realtime | socket + fetch by order id | `Missing` | Not found | Needed for production parity. |

### 9. Package Delivery Flow

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Package booking screen | `src/features/dashboard/PackageScreen.tsx` | `Done` | `lib/app/modules/package/package_view.dart` | Flow exists. |
| Package order creation API | `src/service/packageService.tsx` | `Partial` | `lib/app/modules/package/controllers/package_controller.dart` | Flutter API call exists but uses estimated local distance and simpler payload. |
| Package order detail fetch by id | `packageService.tsx` | `Partial` | `package_controller.dart`, `package_order_details_view.dart` | Verify refresh/detail parity. |
| Package status lifecycle | `src/service/orderService.tsx` package methods | `Missing` | Not found | Accept/update/cancel status parity not implemented. |
| Package live tracking | package-related map/order flows | `Missing` | Not found | Major gap if package orders need realtime view. |

### 10. Payments

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Razorpay order creation | `src/service/paymentService.tsx` | `Missing` | Not found | Port payment service. |
| Razorpay verification | `src/service/paymentService.tsx` | `Missing` | Not found | Port verification flow. |
| Online payment checkout UX | RN order flow | `Missing` | Only payment mode toggle in `order_checkout_view.dart` | Current Flutter UI is incomplete for real online payment. |

### 11. Delivery-Side Flows

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Delivery login | `src/features/auth/DeliveryLogin.tsx` | `Missing` | Not found | No Flutter equivalent. |
| Delivery dashboard | `src/features/delivery/DeliveryDashboard.tsx` | `Missing` | Not found | No Flutter equivalent. |
| Delivery map / live order handling | `DeliveryMap.tsx`, `withLiveOrder.tsx` | `Missing` | Not found | Separate Flutter delivery app/module required if scope includes it. |

### 12. Shared Platform Logic and Settings

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Delivery settings service/store | `deliverySettingsService.ts`, `deliverySettingsStore.tsx` | `Missing` | Not found | Port if radius, fees, or policy needs dynamic backend control. |
| Vendor radius helpers | `vendorRadius.ts` | `Partial` | hardcoded radius usage in Flutter controllers/repos | Move radius/config to shared configurable source. |
| Map service abstraction | `src/service/mapService.tsx` | `Missing` | Not found | Flutter currently talks directly to Google APIs through one local service. |

### 13. Testing

| RN Feature | RN Reference | Flutter Status | Flutter Reference | Action |
|---|---|---|---|---|
| Utility tests | `src/utils/__tests__/distanceValidation.test.ts` | `Missing` | Not found | Add focused tests for vendor resolve, order totals, auth normalization. |
| UI/session modal tests | `src/components/ui/__tests__/SessionExpiredModal.test.tsx` | `Missing` | Not found | Add widget/controller tests for session and auth flows. |

## Recommended Porting Order

1. Live tracking parity: socket listener, order refresh, real map, driver/contact UI.
2. Payment parity: real online payment order creation and verification.
3. Checkout parity: backend-backed totals, taxes, coupons, order breakdown.
4. Session handling parity: global expired-session UX instead of silent token fallback.
5. Package parity: real package status lifecycle and live tracking.
6. Profile parity: backend profile update, wallet/rewards/refund sections if still in scope.
7. Delivery-side parity: only if Flutter app is also meant to cover delivery partner flows.

## Important Current Flutter Strengths

- Firebase phone OTP flow is already meaningfully ported.
- Address book and location-assisted address save flow are already in good shape.
- Main customer browsing journey exists end-to-end.
- API service with token refresh is already present.

## Important Current Flutter Risks

- Several critical flows depend on local fallback data or local state recovery.
- Live tracking is not production-equivalent to RN.
- Online payment is effectively unfinished.
- Test coverage is close to zero.
