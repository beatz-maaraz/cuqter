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
    required String username,
    required String email,
    required String password,
    String profilepic = '',
    String? cloudinaryPublicId,
  }) async {
    String res = "Some error occurred";
    try {
      if (name.isNotEmpty && username.isNotEmpty && email.isNotEmpty && password.isNotEmpty) {
        // Check if username is already taken
        final QuerySnapshot usernameResult = await _firestore
            .collection('users')
            .where('username', isEqualTo: username.trim().toLowerCase())
            .get();
        if (usernameResult.docs.isNotEmpty) {
          return "Username is already taken.";
        }

        // Check if email is already in use
        final QuerySnapshot emailResult = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim().toLowerCase())
            .get();
        if (emailResult.docs.isNotEmpty) {
          return "Email is already in use.";
        }

        UserCredential cred = await _auth.createUserWithEmailAndPassword(
            email: email.trim(), password: password);

        model.user _user = model.user(
          name: name.trim(),
          email: email.trim().toLowerCase(),
          password: password,
          uid: cred.user!.uid,
          username: username.trim().toLowerCase(),
          profilepic: profilepic,
        );

        Map<String, dynamic> userData = _user.toJson();
        if (cloudinaryPublicId != null) {
          userData['cloudinary_public_id'] = cloudinaryPublicId;
        }

        await _firestore.collection('users').doc(cred.user!.uid).set(userData);
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

  Future<String> loginuser({required String emailOrUsername, required String password,}) async {
    String res = "Some error occurred";
    try {
      if (emailOrUsername.isNotEmpty && password.isNotEmpty) {
        String email = emailOrUsername.trim();
        
        // If it's a username (no '@'), retrieve associated email from Firestore
        if (!email.contains('@')) {
          final QuerySnapshot result = await _firestore
              .collection('users')
              .where('username', isEqualTo: email.toLowerCase())
              .limit(1)
              .get();
          if (result.docs.isEmpty) {
            return "Username not found.";
          }
          email = (result.docs.first.data() as Map<String, dynamic>)['email'] ?? '';
        }

        await _auth.signInWithEmailAndPassword(
            email: email, password: password.trim());
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

  Future<String> resetPassword({required String email}) async {
    String res = "Some error occurred";
    try {
      if (email.isNotEmpty) {
        final QuerySnapshot emailResult = await _firestore
            .collection('users')
            .where('email', isEqualTo: email.trim().toLowerCase())
            .get();

        if (emailResult.docs.isEmpty) {
          return "This email is not registered.";
        }

        await _auth.sendPasswordResetEmail(email: email.trim());
        res = "success";
      } else {
        res = "Please enter your email.";
      }
    } on FirebaseAuthException catch (err) {
      if (err.code == 'user-not-found') {
        res = "No user found for that email.";
      } else if (err.code == 'invalid-email') {
        res = "The email is badly formatted.";
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
