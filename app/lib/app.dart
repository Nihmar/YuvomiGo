import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yuvomigo/features/theme/theme_controller.dart';
import 'package:yuvomigo/router.dart';

/// Root widget dell'app: gestisce il router e i temi (light/dark).
final class YuvomiGoApp extends ConsumerWidget {
  const YuvomiGoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final seed = Color(ref.watch(themeControllerProvider));

    return MaterialApp.router(
      title: 'YuvomiGo',
      debugShowCheckedModeBanner: false,
      // UI e server di riferimento sono in italiano: la localizzazione serve
      // soprattutto per le date (DateFormat con locale 'it').
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: seed)),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: seed,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
