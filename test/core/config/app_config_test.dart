import 'package:ferrematica_express/core/config/app_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig', () {
    test('isValid is true when supabase credentials are present', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        mapsApiKey: 'maps-key',
      );

      expect(config.isValid, isTrue);
    });

    test('isValid is false when supabaseUrl is empty', () {
      const config = AppConfig(
        supabaseUrl: '',
        supabaseAnonKey: 'anon-key',
        mapsApiKey: 'maps-key',
      );

      expect(config.isValid, isFalse);
    });

    test('isValid is false when supabaseAnonKey is empty', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: '',
        mapsApiKey: 'maps-key',
      );

      expect(config.isValid, isFalse);
    });

    test('isValid ignores an empty mapsApiKey', () {
      const config = AppConfig(
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon-key',
        mapsApiKey: '',
      );

      expect(config.isValid, isTrue);
    });

    test('fromEnvironment builds a config with empty defaults when no '
        'dart-define values are provided', () {
      final config = AppConfig.fromEnvironment();

      expect(config, isA<AppConfig>());
      expect(config.isValid, isFalse);
    });
  });
}
