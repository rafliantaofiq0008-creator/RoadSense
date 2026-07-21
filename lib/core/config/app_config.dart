class AppConfig {
  static const double potholeThreshold = 5.0; // Example threshold

  static const String authRedirectScheme = 'id.roadsense.app';
  static const String authRedirectHost = 'login-callback';
  static const String authRedirectUrl =
      '$authRedirectScheme://$authRedirectHost';
}
