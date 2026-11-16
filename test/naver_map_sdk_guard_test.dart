import 'package:flutter_test/flutter_test.dart';
import 'package:campingcar_roadmap/config/app_config.dart';

void main() {
  test('Naver native map stays disabled until SDK initialization completes', () {
    expect(AppConfig.naverMapReady.value, isFalse);
    expect(AppConfig.naverMapEnabled, isFalse);

    AppConfig.markNaverMapInitialized();
    expect(AppConfig.naverMapReady.value, isTrue);
    expect(
      AppConfig.naverMapEnabled,
      AppConfig.naverMapClientId.trim().isNotEmpty,
    );

    // An authorization callback can arrive after initialization returns.
    // The native map must then be removed, and cannot be re-enabled.
    AppConfig.markNaverMapUnavailable();
    expect(AppConfig.naverMapReady.value, isFalse);
    expect(AppConfig.naverMapEnabled, isFalse);
    AppConfig.markNaverMapInitialized();
    expect(AppConfig.naverMapReady.value, isFalse);
  });
}
