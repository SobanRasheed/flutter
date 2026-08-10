import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'core/theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  // GoogleSignIn 7.x requires explicit initialization on mobile.
  // On web, we use FirebaseAuth.signInWithPopup() instead to
  // avoid DWDS hang / client-ID issues.
  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize();
  }

  runApp(const DocFlowApp());
}

class DocFlowApp extends StatelessWidget {
  const DocFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DocFlow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
