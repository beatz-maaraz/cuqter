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
        apiKey: "AIzaSyBOvtzNFHyoCeq8pZZ_JdaG0dmd4a1DPHs",
        authDomain: "cuqter-2fa01.firebaseapp.com",
        databaseURL: "https://cuqter-2fa01-default-rtdb.firebaseio.com",
        projectId: "cuqter-2fa01",
        storageBucket: "cuqter-2fa01.firebasestorage.app",
        messagingSenderId: "921725231252",
        appId: "1:921725231252:web:a2dbfa0c97694cbf299481",
        measurementId: "G-5TKLZ0RS2M"
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

