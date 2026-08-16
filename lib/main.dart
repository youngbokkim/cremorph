import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'data/supabase_service.dart';
import 'ui/app_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The app is dark-only, matching the original soil palette.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.soil,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  // Never blocks startup: when Supabase is unreachable or unconfigured the app
  // still runs against the 18 bundled morphs.
  await SupabaseService.instance.initialise();

  runApp(const ProviderScope(child: CrehooniApp()));
}

class CrehooniApp extends StatelessWidget {
  const CrehooniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CREHOONI — 크레스티드게코 모프',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
      builder: (context, child) {
        // Clamp text scaling so the dense result cards stay readable.
        final scale = MediaQuery.textScalerOf(
          context,
        ).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: scale),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
