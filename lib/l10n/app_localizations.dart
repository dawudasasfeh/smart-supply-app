import 'package:flutter/material.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      // Cart Page
      'shopping_cart': 'Shopping Cart',
      'review_items': 'Review your items',
      'items_in_cart': 'items in cart',
      'from_distributor': 'From',
      'distributor': 'distributor',
      'distributors': 'distributors',
      'order_will_be_created': 'order will be created',
      'separate_orders_will_be_created': 'separate orders will be created',
      'multiple_distributors': 'Multiple Distributors',
      'items_split_message': 'Your items will be split into',
      'for_payment_delivery': 'separate orders for payment and delivery.',
      'items': 'items',
      'item': 'item',
      'order': 'Order',
      'from': 'From',
      'will_be_created': 'will be created',
      'in_cart': 'in cart',
      
      // Payment Methods
      'select_payment_method': 'Select Payment Method',
      'no_payment_methods': 'No payment methods available',
      'cash_on_delivery': 'Cash on Delivery',
      'cash_on_delivery_desc': 'Pay with cash when you receive your order',
      'pay_when_delivered': 'Pay when order is delivered',
      'card_payment': 'Card Payment',
      'card_payment_desc': 'Visa, Mastercard, Amex & other cards accepted',
      'credit_card': 'Credit Card',
      'credit_card_desc': 'Visa, MasterCard, American Express',
      'debit_card': 'Debit Card',
      'debit_card_desc': 'Local and international debit cards',
      
      // Order Summary
      'order_summary': 'Order Summary',
      'subtotal': 'Subtotal',
      'delivery_fee': 'Delivery Fee',
      'free': 'Free',
      'total': 'Total',
      'proceed_to_payment': 'Proceed to Payment',
      
      // Success Modal
      'orders_created': 'Orders Created!',
      'order_created': 'Order Created!',
      'code': 'Code',
      'total_amount': 'Total Amount',
      'continue_shopping': 'Continue Shopping',
      
      // Common
      'product': 'Product',
      'unknown_distributor': 'Unknown Distributor',
      'unknown_product': 'Unknown Product',
      'processing': 'Processing...',
      'your_cart_is_empty': 'Your cart is empty',
      'create_orders': 'Create Orders',
      
      // Dialogs
      'clear_cart': 'Clear Cart',
      'clear_cart_confirm': 'Are you sure you want to clear your cart?',
      'cancel': 'Cancel',
      'yes': 'Yes',
      'no': 'No',
      
      // Error Messages
      'please_login': 'Please log in again to continue',
      'network_error': 'Network error: Please check your connection',
      'cart_empty': 'Your cart is empty',
      'please_select_payment': 'Please select a payment method',
      'payment_failed': 'Payment failed',
      'invalid_order_id': 'Invalid order ID',
      'no_valid_items': 'No valid items found in cart',
      'unable_to_create_orders': 'Unable to create orders. Please check your connection and try again.',
      
      // Login Page - App Branding
      'smart_supply': 'Silsila',
      'chain_management': 'Supply Chain Platform',
      'welcome_back': 'Welcome Back',
      'sign_in_to_continue': 'Sign in to continue to your account',
      'email_address': 'Email Address',
      'password': 'Password',
      'sign_in': 'Sign In',
      'dont_have_account': "Don't have an account? ",
      'sign_up': 'Sign Up',
      'please_enter_email': 'Please enter your email',
      'please_enter_password': 'Please enter your password',
      'invalid_credentials': 'Invalid credentials',
      'unknown_user_role': 'Unknown user role',
      
      // Signup Page
      'welcome_to_silsila': 'Welcome to Silsila',
      'join_platform_description': 'Join our supply chain management platform and streamline your business operations',
      'get_started': 'Get Started',
      'already_have_account': 'Already have an account? ',
      'basic_information': 'Basic Information',
      'tell_us_about_yourself': 'Tell us about yourself',
      'full_name': 'Full Name',
      'your_full_name': 'Your full name',
      'confirm_password': 'Confirm Password',
      'please_confirm_password': 'Please confirm your password',
      'passwords_do_not_match': 'Passwords do not match',
      'password_min_length': 'Password must be at least 6 characters',
      'choose_your_role': 'Choose Your Role',
      'select_business_type': 'Select your business type',
      'supermarket': 'Supermarket',
      'supermarket_description': 'Retail store looking for suppliers',
      'distributor': 'Distributor',
      'distributor_description': 'Supplier providing products to retailers',
      'delivery_partner': 'Delivery Partner',
      'delivery_description': 'Delivery service provider',
      'profile_details': 'Profile Details',
      'complete_your_profile': 'Complete your profile',
      'store_name': 'Store Name',
      'your_store_name': 'Your store name',
      'store_address': 'Store Address',
      'enter_store_address': 'Enter your store address or select on map',
      'phone_number': 'Phone Number',
      'your_phone_number': 'Your phone number',
      'company_name': 'Company Name',
      'your_company_name': 'Your company name',
      'business_address': 'Business Address',
      'enter_business_address': 'Enter your business address or select on map',
      'business_phone': 'Business Phone',
      'your_business_phone': 'Your business phone',
      'enter_address': 'Enter your address or select on map',
      'vehicle_type': 'Vehicle Type',
      'vehicle_type_hint': 'e.g., Motorcycle, Car, Van',
      'continue_button': 'Continue',
      'back': 'Back',
      'create_account': 'Create Account',
      'store_name_required': 'Store name is required',
      'address_required': 'Address is required',
      'company_name_required': 'Company name is required',
      'full_name_required': 'Full name is required',
      
      // Map Picker
      'select_location': 'Select Location',
      'confirm_location': 'Confirm Location',
      'getting_address': 'Getting address...',
      'tap_map_select': 'Tap on map to select location',
      'current_location': 'Current Location',
      'failed_get_location': 'Failed to get current location',
      
      // Dashboard
      'dashboard': 'Dashboard',
      'welcome_back': 'Welcome Back',
      'total_orders': 'Total Orders',
      'pending_orders': 'Pending Orders',
      'total_products': 'Total Products',
      'low_stock_items': 'Low Stock Items',
      'total_revenue': 'Total Revenue',
      'quick_actions': 'Quick Actions',
      'browse_products': 'Browse Products',
      'view_orders': 'View Orders',
      'check_inventory': 'Check Inventory',
      'recent_activity': 'Recent Activity',
      'ai_suggestions': 'AI Suggestions',
      'view_all': 'View All',
      
      // Orders
      'orders': 'Orders',
      'all_orders': 'All Orders',
      'new_orders': 'New',
      'in_progress': 'In Progress',
      'completed': 'Completed',
      'cancelled': 'Cancelled',
      'order_id': 'Order ID',
      'order_status': 'Status',
      'order_date': 'Date',
      'order_total': 'Total',
      'order_items': 'Items',
      'view_details': 'View Details',
      'accept_order': 'Accept Order',
      'reject_order': 'Reject Order',
      'mark_completed': 'Mark as Completed',
      
      // Products/Inventory
      'products': 'Products',
      'inventory': 'Inventory',
      'add_product': 'Add Product',
      'product_name': 'Product Name',
      'product_price': 'Price',
      'product_stock': 'Stock',
      'product_category': 'Category',
      'search_products': 'Search products...',
      'no_products_found': 'No products found',
      'out_of_stock': 'Out of Stock',
      'in_stock': 'In Stock',
      'add_to_cart': 'Add to Cart',
      
      // Notifications
      'notifications': 'Notifications',
      'mark_all_read': 'Mark All as Read',
      'no_notifications': 'No notifications',
      
      // Profile
      'profile': 'Profile',
      'account_settings': 'Account Settings',
      'store_info': 'Store Information',
      'logout': 'Logout',
      'edit_profile': 'Edit Profile',
      'change_password': 'Change Password',
      'language_settings': 'Language',
      'theme_settings': 'Theme',
    },
    'ar': {
      // Cart Page
      'shopping_cart': 'عربة التسوق',
      'review_items': 'راجع منتجاتك',
      'items_in_cart': 'منتج في السلة',
      'from_distributor': 'من',
      'distributor': 'موزع',
      'distributors': 'موزعين',
      'order_will_be_created': 'سيتم إنشاء طلب',
      'separate_orders_will_be_created': 'سيتم إنشاء طلبات منفصلة',
      'multiple_distributors': 'عدة موزعين',
      'items_split_message': 'سيتم تقسيم منتجاتك إلى',
      'for_payment_delivery': 'طلبات منفصلة للدفع والتوصيل.',
      'items': 'منتجات',
      'item': 'منتج',
      'order': 'طلب',
      'from': 'من',
      'will_be_created': 'سيتم إنشاؤه',
      'in_cart': 'في السلة',
      
      // Payment Methods
      'select_payment_method': 'اختر طريقة الدفع',
      'no_payment_methods': 'لا توجد طرق دفع متاحة',
      'cash_on_delivery': 'الدفع عند الاستلام',
      'cash_on_delivery_desc': 'ادفع نقداً عند استلام طلبك',
      'pay_when_delivered': 'ادفع عند استلام الطلب',
      'card_payment': 'الدفع بالبطاقة',
      'card_payment_desc': 'فيزا، ماستركارد، أمريكان إكسبرس وبطاقات أخرى',
      'credit_card': 'بطاقة ائتمان',
      'credit_card_desc': 'فيزا، ماستركارد، أمريكان إكسبرس',
      'debit_card': 'بطاقة خصم',
      'debit_card_desc': 'بطاقات الخصم المحلية والدولية',
      
      // Order Summary
      'order_summary': 'ملخص الطلب',
      'subtotal': 'المجموع الفرعي',
      'delivery_fee': 'رسوم التوصيل',
      'free': 'مجاناً',
      'total': 'الإجمالي',
      'proceed_to_payment': 'المتابعة للدفع',
      
      // Success Modal
      'orders_created': 'تم إنشاء الطلبات!',
      'order_created': 'تم إنشاء الطلب!',
      'code': 'الرمز',
      'total_amount': 'المبلغ الإجمالي',
      'continue_shopping': 'متابعة التسوق',
      
      // Common
      'product': 'المنتج',
      'unknown_distributor': 'موزع غير معروف',
      'unknown_product': 'منتج غير معروف',
      'processing': 'جاري المعالجة...',
      'your_cart_is_empty': 'عربة التسوق فارغة',
      'create_orders': 'إنشاء الطلبات',
      
      // Dialogs
      'clear_cart': 'إفراغ السلة',
      'clear_cart_confirm': 'هل أنت متأكد من إفراغ عربة التسوق؟',
      'cancel': 'إلغاء',
      'yes': 'نعم',
      'no': 'لا',
      
      // Error Messages
      'please_login': 'الرجاء تسجيل الدخول مرة أخرى للمتابعة',
      'network_error': 'خطأ في الشبكة: يرجى التحقق من الاتصال',
      'cart_empty': 'عربة التسوق فارغة',
      'please_select_payment': 'الرجاء اختيار طريقة الدفع',
      'payment_failed': 'فشل الدفع',
      'invalid_order_id': 'معرف الطلب غير صالح',
      'no_valid_items': 'لم يتم العثور على عناصر صالحة في السلة',
      'unable_to_create_orders': 'تعذر إنشاء الطلبات. يرجى التحقق من الاتصال والمحاولة مرة أخرى.',
      
      // Login Page - App Branding
      'smart_supply': 'سلسلة',
      'chain_management': 'منصة سلسلة التوريد',
      'welcome_back': 'مرحباً بعودتك',
      'sign_in_to_continue': 'سجل الدخول للمتابعة إلى حسابك',
      'email_address': 'البريد الإلكتروني',
      'password': 'كلمة المرور',
      'sign_in': 'تسجيل الدخول',
      'dont_have_account': 'ليس لديك حساب؟ ',
      'sign_up': 'إنشاء حساب',
      'please_enter_email': 'الرجاء إدخال بريدك الإلكتروني',
      'please_enter_password': 'الرجاء إدخال كلمة المرور',
      'invalid_credentials': 'بيانات الدخول غير صحيحة',
      'unknown_user_role': 'دور المستخدم غير معروف',
      
      // Signup Page
      'welcome_to_silsila': 'مرحباً بك في سلسلة',
      'join_platform_description': 'انضم إلى منصة إدارة سلسلة التوريد لدينا وبسّط عمليات عملك',
      'get_started': 'ابدأ الآن',
      'already_have_account': 'لديك حساب بالفعل؟ ',
      'basic_information': 'المعلومات الأساسية',
      'tell_us_about_yourself': 'أخبرنا عن نفسك',
      'full_name': 'الاسم الكامل',
      'your_full_name': 'اسمك الكامل',
      'confirm_password': 'تأكيد كلمة المرور',
      'please_confirm_password': 'الرجاء تأكيد كلمة المرور',
      'passwords_do_not_match': 'كلمات المرور غير متطابقة',
      'password_min_length': 'يجب أن تكون كلمة المرور 6 أحرف على الأقل',
      'choose_your_role': 'اختر دورك',
      'select_business_type': 'اختر نوع عملك',
      'supermarket': 'سوبر ماركت',
      'supermarket_description': 'متجر بيع بالتجزئة يبحث عن موردين',
      'distributor': 'موزع',
      'distributor_description': 'مورد يقدم المنتجات لتجار التجزئة',
      'delivery_partner': 'شريك التوصيل',
      'delivery_description': 'مزود خدمة التوصيل',
      'profile_details': 'تفاصيل الملف الشخصي',
      'complete_your_profile': 'أكمل ملفك الشخصي',
      'store_name': 'اسم المتجر',
      'your_store_name': 'اسم متجرك',
      'store_address': 'عنوان المتجر',
      'enter_store_address': 'أدخل عنوان متجرك أو حدده على الخريطة',
      'phone_number': 'رقم الهاتف',
      'your_phone_number': 'رقم هاتفك',
      'company_name': 'اسم الشركة',
      'your_company_name': 'اسم شركتك',
      'business_address': 'عنوان العمل',
      'enter_business_address': 'أدخل عنوان عملك أو حدده على الخريطة',
      'business_phone': 'هاتف العمل',
      'your_business_phone': 'هاتف عملك',
      'enter_address': 'أدخل عنوانك أو حدده على الخريطة',
      'vehicle_type': 'نوع المركبة',
      'vehicle_type_hint': 'مثال: دراجة نارية، سيارة، شاحنة',
      'continue_button': 'متابعة',
      'back': 'رجوع',
      'create_account': 'إنشاء حساب',
      'store_name_required': 'اسم المتجر مطلوب',
      'address_required': 'العنوان مطلوب',
      'company_name_required': 'اسم الشركة مطلوب',
      'full_name_required': 'الاسم الكامل مطلوب',
      
      // Map Picker
      'select_location': 'حدد الموقع',
      'confirm_location': 'تأكيد الموقع',
      'getting_address': 'جاري الحصول على العنوان...',
      'tap_map_select': 'اضغط على الخريطة لتحديد الموقع',
      'current_location': 'الموقع الحالي',
      'failed_get_location': 'فشل الحصول على الموقع الحالي',
      
      // Dashboard
      'dashboard': 'لوحة التحكم',
      'welcome_back': 'مرحباً بعودتك',
      'total_orders': 'إجمالي الطلبات',
      'pending_orders': 'الطلبات المعلقة',
      'total_products': 'إجمالي المنتجات',
      'low_stock_items': 'منتجات قليلة المخزون',
      'total_revenue': 'إجمالي الإيرادات',
      'quick_actions': 'إجراءات سريعة',
      'browse_products': 'تصفح المنتجات',
      'view_orders': 'عرض الطلبات',
      'check_inventory': 'فحص المخزون',
      'recent_activity': 'النشاط الأخير',
      'ai_suggestions': 'اقتراحات الذكاء الاصطناعي',
      'view_all': 'عرض الكل',
      
      // Orders
      'orders': 'الطلبات',
      'all_orders': 'جميع الطلبات',
      'new_orders': 'جديد',
      'in_progress': 'قيد التنفيذ',
      'completed': 'مكتمل',
      'cancelled': 'ملغي',
      'order_id': 'رقم الطلب',
      'order_status': 'الحالة',
      'order_date': 'التاريخ',
      'order_total': 'المجموع',
      'order_items': 'العناصر',
      'view_details': 'عرض التفاصيل',
      'accept_order': 'قبول الطلب',
      'reject_order': 'رفض الطلب',
      'mark_completed': 'تمييز كمكتمل',
      
      // Products/Inventory
      'products': 'المنتجات',
      'inventory': 'المخزون',
      'add_product': 'إضافة منتج',
      'product_name': 'اسم المنتج',
      'product_price': 'السعر',
      'product_stock': 'المخزون',
      'product_category': 'الفئة',
      'search_products': 'ابحث عن منتجات...',
      'no_products_found': 'لم يتم العثور على منتجات',
      'out_of_stock': 'غير متوفر',
      'in_stock': 'متوفر',
      'add_to_cart': 'أضف إلى السلة',
      
      // Notifications
      'notifications': 'الإشعارات',
      'mark_all_read': 'تحديد الكل كمقروء',
      'no_notifications': 'لا توجد إشعارات',
      
      // Profile
      'profile': 'الملف الشخصي',
      'account_settings': 'إعدادات الحساب',
      'store_info': 'معلومات المتجر',
      'logout': 'تسجيل الخروج',
      'edit_profile': 'تعديل الملف الشخصي',
      'change_password': 'تغيير كلمة المرور',
      'language_settings': 'اللغة',
      'theme_settings': 'السمة',
    },
  };

  String translate(String key) {
    return _localizedValues[locale.languageCode]?[key] ?? key;
  }

  String get shoppingCart => translate('shopping_cart');
  String get reviewItems => translate('review_items');
  String get itemsInCart => translate('items_in_cart');
  String get fromDistributor => translate('from_distributor');
  String get distributor => translate('distributor');
  String get distributors => translate('distributors');
  String get orderWillBeCreated => translate('order_will_be_created');
  String get separateOrdersWillBeCreated => translate('separate_orders_will_be_created');
  String get multipleDistributors => translate('multiple_distributors');
  String get itemsSplitMessage => translate('items_split_message');
  String get forPaymentDelivery => translate('for_payment_delivery');
  String get items => translate('items');
  String get item => translate('item');
  String get order => translate('order');
  String get from => translate('from');
  String get willBeCreated => translate('will_be_created');
  String get inCart => translate('in_cart');
  
  String get selectPaymentMethod => translate('select_payment_method');
  String get noPaymentMethods => translate('no_payment_methods');
  String get cashOnDelivery => translate('cash_on_delivery');
  String get cashOnDeliveryDesc => translate('cash_on_delivery_desc');
  String get payWhenDelivered => translate('pay_when_delivered');
  String get cardPayment => translate('card_payment');
  String get cardPaymentDesc => translate('card_payment_desc');
  String get creditCard => translate('credit_card');
  String get creditCardDesc => translate('credit_card_desc');
  String get debitCard => translate('debit_card');
  String get debitCardDesc => translate('debit_card_desc');
  
  String get orderSummary => translate('order_summary');
  String get subtotal => translate('subtotal');
  String get deliveryFee => translate('delivery_fee');
  String get free => translate('free');
  String get total => translate('total');
  String get proceedToPayment => translate('proceed_to_payment');
  
  String get ordersCreated => translate('orders_created');
  String get orderCreated => translate('order_created');
  String get code => translate('code');
  String get totalAmount => translate('total_amount');
  String get continueShopping => translate('continue_shopping');
  
  String get product => translate('product');
  String get unknownDistributor => translate('unknown_distributor');
  String get unknownProduct => translate('unknown_product');
  String get processing => translate('processing');
  String get yourCartIsEmpty => translate('your_cart_is_empty');
  String get createOrders => translate('create_orders');
  
  String get clearCart => translate('clear_cart');
  String get clearCartConfirm => translate('clear_cart_confirm');
  String get cancel => translate('cancel');
  String get yes => translate('yes');
  String get no => translate('no');
  
  String get pleaseLogin => translate('please_login');
  String get networkError => translate('network_error');
  String get cartEmpty => translate('cart_empty');
  String get pleaseSelectPayment => translate('please_select_payment');
  String get paymentFailed => translate('payment_failed');
  String get invalidOrderId => translate('invalid_order_id');
  String get noValidItems => translate('no_valid_items');
  String get unableToCreateOrders => translate('unable_to_create_orders');
  
  String get smartSupply => translate('smart_supply');
  String get chainManagement => translate('chain_management');
  String get welcomeBack => translate('welcome_back');
  String get signInToContinue => translate('sign_in_to_continue');
  String get emailAddress => translate('email_address');
  String get password => translate('password');
  String get signIn => translate('sign_in');
  String get dontHaveAccount => translate('dont_have_account');
  String get signUp => translate('sign_up');
  String get pleaseEnterEmail => translate('please_enter_email');
  String get pleaseEnterPassword => translate('please_enter_password');
  String get invalidCredentials => translate('invalid_credentials');
  String get unknownUserRole => translate('unknown_user_role');
  
  bool get isRTL => locale.languageCode == 'ar';
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['en', 'ar'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
