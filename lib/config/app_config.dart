import 'package:flutter/foundation.dart';

class AppConfig {
  // Supabase publishable key is designed for client-side apps. These defaults
  // make the test build connect immediately; production builds can override
  // them with --dart-define.
  static const _defaultSupabaseUrl = 'https://xlpwxkcxpxorrmkgzhft.supabase.co';
  static const _defaultSupabaseKey = 'sb_publishable_E-G6sdyrAhJ9f92WLREBxw_778vlCi3';

  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: _defaultSupabaseUrl,
  );
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: _defaultSupabaseKey,
  );

  static bool get serverEnabled => supabaseUrl.isNotEmpty && supabaseKey.isNotEmpty;

  static const naverMapClientId = String.fromEnvironment('NAVER_MAP_CLIENT_ID', defaultValue: '');
  // Never mount a native NaverMap until FlutterNaverMap().init completes.
  // The native SDK reports [800] when the view is created without a client ID.
  static final ValueNotifier<bool> naverMapReady = ValueNotifier<bool>(false);
  static bool naverMapFailed = false;
  static bool get naverMapEnabled =>
      naverMapClientId.trim().isNotEmpty &&
      naverMapReady.value &&
      !naverMapFailed;

  static void markNaverMapInitialized() {
    if (!naverMapFailed) naverMapReady.value = true;
  }

  static void markNaverMapUnavailable() {
    naverMapFailed = true;
    naverMapReady.value = false;
  }

  static const packageName = 'kr.co.campingcarroadmap.app';
  static const appName = '캠핑카족 로드맵';
}
