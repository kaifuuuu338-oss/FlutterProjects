import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:my_first_app/core/localization/app_localizations.dart';
import 'package:my_first_app/core/localization/locale_provider.dart';
import 'package:my_first_app/core/navigation/app_route_observer.dart';
import 'package:my_first_app/core/theme/app_theme.dart';
import 'package:my_first_app/core/utils/problem_a_lms_service.dart';
import 'package:my_first_app/services/local_db_service.dart';
import 'package:my_first_app/services/sync_service.dart';
import 'package:my_first_app/screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProblemALmsService.instance.initialize();

  // Initialize local app cache - skip on web
  if (!kIsWeb) {
    final localDb = LocalDBService();
    await localDb.initialize();

    // Start connectivity listener to auto-sync pending screenings
    final sync = SyncService(localDb);
    sync.listenForConnectivityChanges();
    await sync.syncPendingData();
  }

  final localeProvider = LocaleProvider();
  await localeProvider.loadSavedLocale();
  runApp(
    ChangeNotifierProvider.value(
      value: localeProvider,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    return MaterialApp(
      title: 'AI ECD Screening App',
      onGenerateTitle: (context) => AppLocalizations.of(context).t('app_name'),
      theme: AppTheme.lightTheme(),
      debugShowCheckedModeBanner: false,
      locale: localeProvider.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorObservers: [routeObserver],
      home: const SplashScreen(),
    );
  }
}
