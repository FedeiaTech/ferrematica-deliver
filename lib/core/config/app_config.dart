/// App-wide configuration resolved from compile-time environment values
/// (`--dart-define-from-file=dart_define.json`). Never hardcode secrets here.
final class AppConfig {
  const AppConfig({required this.supabaseUrl, required this.supabaseAnonKey});

  /// Builds config from `String.fromEnvironment`, populated at build time via
  /// `--dart-define-from-file=dart_define.json` (see `dart_define.example.json`).
  ///
  /// No maps/geocoding/directions key is needed: the delivery feature is
  /// backed by OpenStreetMap-based services (`flutter_map` tiles, Nominatim
  /// geocoding, OSRM directions), none of which require an API key.
  factory AppConfig.fromEnvironment() => const AppConfig(
    supabaseUrl: String.fromEnvironment('SUPABASE_URL'),
    supabaseAnonKey: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );

  final String supabaseUrl;
  final String supabaseAnonKey;

  /// True when the required backend credentials are present.
  bool get isValid => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
