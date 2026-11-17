// ignore: constant_identifier_names
enum AppMode { LIVE, DEV }

class AppData {
  AppData._();

  static AppMode appMode = AppMode.DEV;

  static const supabaseHost = 'tausaxdgodekmtztklzx.supabase.co';
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_p8jIDzuWs4-SlDXLfGzgfQ_ShqSF03Q',
  );
  static const phoneOtpEnabled = false;
  static const googleWebClientId = String.fromEnvironment(
    'GOOGLE_WEB_CLIENT_ID',
    defaultValue: '870716675157-0mjbng7b7pgoh4opav695mcbkruajl7h.apps.googleusercontent.com',
  );
  static const googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
  );

  static String schemaFor(AppMode mode) => switch (mode) {
    AppMode.DEV => 'klubby_dev',
    AppMode.LIVE => 'public',
  };
}
