class AppConfig {
  // Base URL for API endpoints
  static const String baseUrl = 'http://10.0.2.2:5000';
  
  // Alternative URLs for different environments
  static const String localUrl = 'http://localhost:5000';
  static const String productionUrl = 'https://your-production-url.com';
  
  // Socket.IO configuration
  static const String socketUrl = baseUrl;
  
  // API version
  static const String apiVersion = 'v1';
  
  // Timeout configurations
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  
  // App information
  static const String appName = 'Smart Supply Chain';
  static const String appVersion = '1.0.0';
  
  // Environment settings
  static const bool isProduction = false;
  static const bool enableLogging = true;
  
  // Get the appropriate base URL based on environment
  static String get currentBaseUrl {
    if (isProduction) {
      return productionUrl;
    }
    return baseUrl;
  }
}
