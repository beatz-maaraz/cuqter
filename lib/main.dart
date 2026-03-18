import 'package:cuqter/Account/login.dart';
import 'package:cuqter/Screen/homepage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
Future <void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    await Firebase.initializeApp(
      options: const FirebaseOptions(
        apiKey: "AIzaSyDUjB57C5noLmLlTbXm88rtppyVscWvRSY",
        authDomain: "cuqter-d0951.firebaseapp.com",
        projectId: "cuqter-d0951",
        storageBucket: "cuqter-d0951.firebasestorage.app",
        messagingSenderId: "772950552143",
        appId: "1:772950552143:web:39c4c8492e51054ff3843a"
      ),
    );
  } else {
    await Firebase.initializeApp();
  }
    runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return  MaterialApp(
      home: Scaffold(
        body: StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(), 
          builder:(context, snapshot) {
            if (snapshot.connectionState == ConnectionState.active){
              if (snapshot.hasData){
                return Homepage();
                // return Responsiveout(Phonepages: Phonepages(), Webpage: Webpage(),);
              }
              else if (snapshot.hasError){
                return Center(child: Text('Error: ${snapshot.error}'),); 
              }
            }
            if (snapshot.connectionState == ConnectionState.waiting){
              return CircularProgressIndicator();
            }
            return Loginpage();
          },
        ),
      ),
    );
  }
}

