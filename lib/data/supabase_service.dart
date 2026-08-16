import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config.dart';

/// Owns the Supabase connection and the anonymous session the app relies on.
///
/// Contributing a reference photo needs an identity so row level security can
/// scope deletes, but requiring a login for a hobby app is friction users will
/// not pay. Anonymous sign-in gives every install a durable `auth.uid()` that
/// Supabase persists locally, with no sign-up screen.
class SupabaseService {
  SupabaseService._();

  static final instance = SupabaseService._();

  bool _initialised = false;

  /// Whether a usable Supabase connection exists. When false the app runs in
  /// offline mode: the 18 bundled morphs work, community features do not.
  bool get isAvailable => _initialised && AppConfig.hasSupabase;

  SupabaseClient get client => Supabase.instance.client;

  String? get userId => isAvailable ? client.auth.currentUser?.id : null;

  /// Reason the connection is unavailable, for display in the UI.
  String? unavailableReason;

  Future<void> initialise() async {
    if (!AppConfig.hasSupabase) {
      unavailableReason =
          'Supabase 설정이 없어 오프라인 모드로 실행합니다. 내장 도감 18종은 그대로 쓸 수 있습니다.';
      debugPrint(
        'CREHOONI: SUPABASE_URL / SUPABASE_ANON_KEY not provided — '
        'running offline. See README for --dart-define usage.',
      );
      return;
    }

    try {
      await Supabase.initialize(
        url: AppConfig.supabaseUrl,
        // Named `anon key` in the dashboard; the SDK calls it the publishable
        // key. Either the legacy JWT or the newer `sb_publishable_...` key works.
        publishableKey: AppConfig.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
        ),
      );
      _initialised = true;
      await _ensureSession();
    } catch (error, stack) {
      unavailableReason = '서버에 연결하지 못했습니다. 오프라인 모드로 실행합니다.';
      debugPrint('CREHOONI: Supabase init failed — $error\n$stack');
    }
  }

  /// Signs in anonymously when there is no session yet.
  ///
  /// A failure here is not fatal: reads are public, so the gallery and
  /// identification still work; only uploads need the session.
  Future<void> _ensureSession() async {
    if (client.auth.currentSession != null) return;
    try {
      await client.auth.signInAnonymously();
    } catch (error) {
      debugPrint('CREHOONI: anonymous sign-in failed — $error');
      unavailableReason =
          '익명 로그인에 실패해 사진 공유는 사용할 수 없습니다. '
          'Supabase 대시보드에서 Anonymous sign-in을 켜 주세요.';
    }
  }

  /// Ensures a session exists before a write, retrying sign-in if needed.
  Future<String?> requireUserId() async {
    if (!isAvailable) return null;
    if (client.auth.currentUser == null) await _ensureSession();
    return client.auth.currentUser?.id;
  }
}
