import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cuqter/modules/user.dart' as model;
// import 'package:cuqter/resources/storage_method.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';


class AuthMethod {

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> signUpUser({
    required String name,
    required String email,
    required String password,
  }) async {
    String res = "Some error occurred";
    try {
      if (name.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
            email: email, password: password);

            model.user _user = model.user(
              name: name,
              email: email,
              password: password,
              uid: cred.user!.uid,
              profilepic: '',
            );

            await _firestore.collection('users').doc(cred.user!.uid).set(
              _user.toJson(),
            );
            res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } on FirebaseAuthException catch (err) {
      if (err.code == 'invalid-email') {
        res = 'The email is badly formatted.';
      } else if (err.code == 'weak-password') {
        res = 'Password should be at least 6 characters.';
      } else if (err.code == 'email-already-in-use') {
        res = 'The account already exists for that email.';
      } else {
         res = err.message ?? "An error occurred";
      }
      if (kDebugMode) {
        print(err.toString());
      }
    } catch (err) {
      res = err.toString();
      if (kDebugMode) {
        print(err.toString());
      }
    }
    return res;
  }

  Future<String> loginuser({required String email,required String password,}) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        res = "success";
      } else {
        res = "Please enter all the fields";
      }
    } on FirebaseAuthException catch (err) {
      if (err.code == 'user-not-found') {
        res = "No user found for that email.";
      } else if (err.code == 'wrong-password') {
        res = "Wrong password provided.";
      } else if (err.code == 'invalid-credential') {
        res = "Wrong email or password provided.";
      } else {
        res = err.message ?? "An error occurred";
      }
      if (kDebugMode) {
        print(err.toString());
      }
    } catch (err) {
      res = err.toString();
      if (kDebugMode) {
        print(err.toString());
      }
    }
    return res;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<DocumentSnapshot> getUserDetails() async {
    User currentUser = _auth.currentUser!;
    DocumentSnapshot snap = await _firestore.collection('users').doc(currentUser.uid).get();
    return snap;
  }
}