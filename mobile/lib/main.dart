import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/app_state.dart';
import 'core/theme.dart';
import 'features/auth/welcome_screen.dart';
import 'features/home/parent_shell.dart';
import 'features/splash/splash_screen.dart';
import 'features/volunteer/volunteer_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ar');
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  final state = AppState()..boot();
  runApp(ChangeNotifierProvider.value(value: state, child: const AtmaenApp()));
}

class AtmaenApp extends StatelessWidget {
  const AtmaenApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'اطمئن',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const _Root(),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final Widget page;
    if (!s.ready) {
      page = const SplashScreen();
    } else if (!s.loggedIn) {
      page = const WelcomeScreen();
    } else if (s.user!.isVolunteer) {
      page = const VolunteerShell();
    } else {
      page = const ParentShell();
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: page);
  }
}
