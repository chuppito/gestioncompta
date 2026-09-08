import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'services/store.dart';
import 'services/auth_service.dart';
import 'screens/root_screen.dart';
import 'screens/login_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('fr_FR', null);

  await Hive.initFlutter();
  await Hive.openBox("db");

  Store.I;

  bool firebaseOk = true;
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (e) {
    // L'app reste utilisable hors connexion même si Firebase n'est pas
    // encore configuré (voir firebase_options.dart) ou si le réseau est
    // indisponible : la comptabilité locale continue de fonctionner.
    firebaseOk = false;
    debugPrint("Firebase indisponible : $e");
  }

  if (firebaseOk && AuthService.isLoggedIn) {
    try {
      await Store.I.syncOnLogin();
    } catch (e) {
      debugPrint("Erreur synchro au démarrage : $e");
    }
  }

  runApp(App(firebaseOk: firebaseOk));
}

class App extends StatelessWidget {
  final bool firebaseOk;
  const App({super.key, required this.firebaseOk});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "Gestion Compta",
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: kBackground,
        colorScheme: ColorScheme.fromSeed(
          seedColor: kPrimary,
          primary: kPrimary,
          secondary: kSecondary,
          surface: kBackground,
        ),
      ),
      locale: const Locale('fr', 'FR'),
      supportedLocales: const [
        Locale('fr', 'FR'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: (firebaseOk && !AuthService.isLoggedIn)
          ? const LoginScreen()
          : const RootScreen(),
    );
  }
}