// lib/services/config_service.dart

class ConfigService {
  // Простые константы вместо Remote Config
  static const String adminEmail = 'anvistanb17@gmail.com';
  static const int minAge = 18;
  static const bool enableProfanityFilter = true;
  static const bool enableLinkFilter = true;
  static const bool enablePhoneFilter = true;
  static const bool enableEmailFilter = true;
  static const int maxMessageLength = 1000;
  static const String appVersion = '1.0.0';
  
  static String getAdminEmail() => adminEmail;
  static int getMinAge() => minAge;
  static bool isProfanityFilterEnabled() => enableProfanityFilter;
  static bool isLinkFilterEnabled() => enableLinkFilter;
  static bool isPhoneFilterEnabled() => enablePhoneFilter;
  static bool isEmailFilterEnabled() => enableEmailFilter;
  static String getAppVersion() => appVersion;
  static int getMaxMessageLength() => maxMessageLength;
  
  // Пустой метод для совместимости
  static Future<void> initialize() async {
    print("✅ ConfigService инициализирован");
  }
}