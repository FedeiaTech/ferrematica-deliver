/// App-wide configuration resolved from compile-time environment values
/// (`--dart-define-from-file=dart_define.json`). Never hardcode secrets here.
final class AppConfig {
  const AppConfig({
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.mapsApiKey,
  });

  /// Builds config from `String.fromEnvironment`, populated at build time via
  /// `--dart-define-from-file=dart_define.json` (see `dart_define.example.json`).
  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
    mapsApiKey: String.fromEnvironment('GOOGLE_MAPS_API_KEY'),
  );

  final String supabaseUrl;
  final String supabaseAnonKey;
  final String mapsApiKey;

  /// True when the required backend credentials are present. `mapsApiKey`
  /// is intentionally excluded: native Maps config can fail independently
  /// and is validated at the platform layer instead.
  bool get isValid => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
