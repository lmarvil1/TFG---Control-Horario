// Archivo generado por FlutterFire CLI, se crea cuando configuras Firebase en tu proyecto.
// ignore_for_file: type=lint → Ignora los avisos o errores relacionados con type en todo el archivo
// porque el código generado puede no seguir al 100% las reglas de estilo

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Clase que centraliza la configuración de Firebase para cada plataforma.
///
/// Este archivo es generado automáticamente por FlutterFire CLI y contiene
/// los parámetros necesarios para conectar la aplicación con el proyecto
/// de Firebase correspondiente.
///
/// No se recomienda modificar manualmente este archivo, ya que cualquier
/// cambio puede sobrescribirse al regenerarlo.
class DefaultFirebaseOptions {

  /// Devuelve la configuración de Firebase adecuada según la plataforma
  /// en la que se esté ejecutando la aplicación.
  ///
  /// - Web → configuración específica web
  /// - Android / iOS / macOS / Windows → configuración nativa correspondiente
  /// - Linux → no soportado, requiere configuración adicional
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
        return macos;
      case TargetPlatform.windows:
        return windows;
      case TargetPlatform.linux:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for linux - '
          'you can reconfigure this by running the FlutterFire CLI again.',
        );
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  /// Configuración de Firebase para entorno web.
  /// Incluye autenticación, almacenamiento y mensajería.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCuUYGdt-5fh_uq8iHgHUnuDO12j8FucLs',
    appId: '1:593161257656:web:c80e329933e8caa2852a4d',
    messagingSenderId: '593161257656',
    projectId: 'tfg-controlhorario',
    authDomain: 'tfg-controlhorario.firebaseapp.com',
    storageBucket: 'tfg-controlhorario.firebasestorage.app',
  );

  /// Configuración de Firebase para dispositivos Android.
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAq3HvQAVY5spnFjOwD_mT_9NXpLvgdQ4M',
    appId: '1:593161257656:android:db7ba208220732d3852a4d',
    messagingSenderId: '593161257656',
    projectId: 'tfg-controlhorario',
    storageBucket: 'tfg-controlhorario.firebasestorage.app',
  );

  /// Configuración de Firebase para dispositivos iOS.
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyAFK39BewXNzl8fCxXPNDo7Ssm6Az7TpzY',
    appId: '1:593161257656:ios:c0254561ad9da62f852a4d',
    messagingSenderId: '593161257656',
    projectId: 'tfg-controlhorario',
    storageBucket: 'tfg-controlhorario.firebasestorage.app',
    iosBundleId: 'com.example.tfgApp',
  );

  /// Configuración de Firebase para macOS.
  /// Comparte configuración con iOS al tratarse del mismo ecosistema Apple.
  static const FirebaseOptions macos = FirebaseOptions(
    apiKey: 'AIzaSyAFK39BewXNzl8fCxXPNDo7Ssm6Az7TpzY',
    appId: '1:593161257656:ios:c0254561ad9da62f852a4d',
    messagingSenderId: '593161257656',
    projectId: 'tfg-controlhorario',
    storageBucket: 'tfg-controlhorario.firebasestorage.app',
    iosBundleId: 'com.example.tfgApp',
  );

  /// Configuración de Firebase para entorno Windows.
  /// Utiliza parámetros similares a la configuración web.
  static const FirebaseOptions windows = FirebaseOptions(
    apiKey: 'AIzaSyCuUYGdt-5fh_uq8iHgHUnuDO12j8FucLs',
    appId: '1:593161257656:web:1283068392280d26852a4d',
    messagingSenderId: '593161257656',
    projectId: 'tfg-controlhorario',
    authDomain: 'tfg-controlhorario.firebaseapp.com',
    storageBucket: 'tfg-controlhorario.firebasestorage.app',
  );

}