{{flutter_js}}
{{flutter_build_config}}

// Do not register Flutter's service worker. The first Pages deploy went out
// without Supabase keys; a worker would keep serving that offline bundle.
_flutter.loader.load();
