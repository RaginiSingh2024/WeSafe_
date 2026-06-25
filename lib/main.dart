import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:womensafteyhackfair/firebase_options.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:womensafteyhackfair/Dashboard/Dashboard.dart';
import 'package:womensafteyhackfair/Dashboard/DashWidgets/WeSafeToast.dart';
import 'package:womensafteyhackfair/Dashboard/Splsah/Splash.dart';
import 'package:womensafteyhackfair/Dashboard/Auth/LoginScreen.dart';
import 'package:womensafteyhackfair/background_services.dart';
import 'package:womensafteyhackfair/constants.dart';
import 'package:workmanager/workmanager.dart';



void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  if (!kIsWeb) {
    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: (service) {},
      ),
    );
  }
  if (!kIsWeb) {
    Workmanager().initialize(
      callbackDispatcher,
    );
  }
  
  SystemChrome.setPreferredOrientations(
      [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]).then((_) {
    runApp(MyApp());
  });
}

class MyApp extends StatelessWidget {
 

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WeSafe',
      navigatorKey: WeSafeToast.navigatorKey,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: AppColors.background,
        fontFamily: GoogleFonts.poppins().fontFamily,
        primaryColor: AppColors.primary,
        colorScheme: ColorScheme.light(
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: AppColors.cardSurface,
          background: AppColors.background,
        ),
      ),
      home: FutureBuilder<Map<String, bool>>(
          future: checkAppStatus(),
          builder: (context, AsyncSnapshot<Map<String, bool>> snap) {
            if (snap.hasData) {
              final openedBefore = snap.data!["openedBefore"] ?? false;
              final isLoggedIn = snap.data!["isLoggedIn"] ?? false;
              if (openedBefore) {
                return isLoggedIn ? Dashboard() : LoginScreen();
              } else {
                return Splash();
              }
            } else {
              return Container(
                color: Colors.white,
              );
            }
          }),
    );
  }

  Future<Map<String, bool>> checkAppStatus() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool openedBefore = prefs.getBool("appOpenedBefore") ?? false;
    bool isLoggedIn = prefs.getBool("is_logged_in") ?? false;
    if (!openedBefore) {
      prefs.setBool("appOpenedBefore", true);
    }
    return {
      "openedBefore": openedBefore,
      "isLoggedIn": isLoggedIn,
    };
  }
}
