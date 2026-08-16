/// Supabase connection settings.
///
/// Values are injected at build time so no secret ever lands in git:
///
/// ```sh
/// flutter run \
///   --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///   --dart-define=SUPABASE_ANON_KEY=eyJhb...
/// ```
///
/// The anon key is safe to ship in a client bundle — row level security is what
/// protects the data. See `supabase/migrations/` for the policies.
abstract final class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// When false the app still runs, but only with the 18 bundled morphs: no
  /// community reference photos, no uploads, no CLIP re-ranking.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Storage bucket holding community reference photos.
  static const photoBucket = 'reference-photos';

  /// Edge function that turns an image into a CLIP embedding. Optional — when it
  /// is not deployed, identification falls back to on-device colour analysis.
  static const clipFunction = 'clip-embed';

  /// Longest edge (px) an uploaded photo is downscaled to before leaving the
  /// device. Matches `fileToDataUrl(file, maxSize = 720)` in the web version.
  static const uploadMaxEdge = 720;

  /// JPEG quality for uploads, matching the web version's `0.84`.
  static const uploadJpegQuality = 84;
}
