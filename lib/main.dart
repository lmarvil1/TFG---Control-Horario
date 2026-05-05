import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'firebase_options.dart';
import 'app/router_page.dart';

/// Punto de entrada principal de la aplicación.
/// Se encarga de inicializar los servicios necesarios antes de lanzar la UI.
void main() async {
  // Asegura la correcta inicialización de los bindings de Flutter
  // antes de realizar operaciones asíncronas en el arranque.
  WidgetsFlutterBinding.ensureInitialized();

  // Inicialización de Firebase con la configuración específica de la plataforma.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Instancia de acceso a Firestore.
  final db = FirebaseFirestore.instance;

  try {
    if (kIsWeb) {
      try {
        // En entorno web se intenta habilitar la persistencia offline
        // con sincronización entre pestañas.
        await db.enablePersistence(
          const PersistenceSettings(synchronizeTabs: true),
        );
      } catch (_) {
        // En web puede fallar si hay múltiples pestañas abiertas o por restricciones del navegador.
        // No se interrumpe la ejecución de la aplicación.
      }
    } else {
      // En móviles se configura la persistencia local
      // con tamaño de caché ilimitado para mejorar el acceso offline.
      db.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }
  } catch (_) {
    // Se captura cualquier error en la configuración offline
    // para evitar bloquear el arranque de la aplicación.
  }

  // Lanzamiento de la aplicación principal.
  runApp(const MyApp());
}

/// Widget raíz de la aplicación.
/// Define la configuración global de MaterialApp.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      // Título de la aplicación
      title: 'Control Horario',

      // Eliminación del banner de debug en entorno de desarrollo
      debugShowCheckedModeBanner: false,

      // Configuración de idioma por defecto (español - España)
      locale: const Locale('es', 'ES'),

      // Idiomas soportados por la aplicación
      supportedLocales: const [
        Locale('es', 'ES'),
      ],

      // Delegados necesarios para la localización de widgets de Flutter
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Configuración del tema visual de la aplicación
      theme: ThemeData(
        useMaterial3: true,
      ),

      // Página inicial que gestiona la navegación según estado de la app
      home: const RouterPage(),
    );
  }
}