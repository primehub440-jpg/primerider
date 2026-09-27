import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        return web;
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: "AIzaSyCbrjBr26TRwTfpysgSVtWELzmRU5OHTAs",
    authDomain: "primehub-5ef30.firebaseapp.com",
    projectId: "primehub-5ef30",
    storageBucket: "primehub-5ef30.firebasestorage.app",
    messagingSenderId: "240271247560",
    appId: "1:240271247560:web:d1270355198d09d7dfd",
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: "AIzaSyCbrjBr26TRwTfpysgSVtWELzmRU5OHTAs",
    appId: "1:240271247560:android:d1270355198d09d7dfd",
    messagingSenderId: "240271247560",
    projectId: "primehub-5ef30",
    storageBucket: "primehub-5ef30.firebasestorage.app",
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: "AIzaSyCbrjBr26TRwTfpysgSVtWELzmRU5OHTAs",
    appId: "1:240271247560:ios:d1270355198d09d7dfd",
    messagingSenderId: "240271247560",
    projectId: "primehub-5ef30",
    storageBucket: "primehub-5ef30.firebasestorage.app",
  );
}