import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

class StorageMethod {

  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  uploadImageToStorage(String childName, Uint8List file, bool isPost) async {
    Reference ref = _storage.ref().child(childName).child(_auth.currentUser!.uid);
    UploadTask uploadTask = ref.putData(file);
    TaskSnapshot snap = await uploadTask;
    String downloadurl = await snap.ref.getDownloadURL();
    return downloadurl;
  }

  Future<String> uploadFile(String folderPath, String fileName, Uint8List fileBytes) async {
    Reference ref = _storage.ref().child(folderPath).child(fileName);
    UploadTask uploadTask = ref.putData(fileBytes);
    TaskSnapshot snap = await uploadTask;
    String downloadUrl = await snap.ref.getDownloadURL();
    return downloadUrl;
  }
}
