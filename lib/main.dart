import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'services/config_service.dart';
import 'services/notification_service.dart';
import 'viewmodels/app_config_viewmodel.dart';
import 'views/pages/consent_page.dart';
import 'views/pages/age_verification_page.dart';
import 'views/pages/auth_page.dart';
import 'views/pages/pin_lock_page.dart';
import 'views/pages/glitch_page.dart';
import 'services/sync_service.dart';

void setupFirebaseEmulatorsForLinux() {
  if (Platform.isLinux) {
    print('🐧 Обнаружена Linux платформа — подключаюсь к эмуляторам Firebase');
    FirebaseAuth.instance.useAuthEmulator('localhost', 9099);
    FirebaseFirestore.instance.useFirestoreEmulator('localhost', 8080);
    print('✅ Firebase теперь работает через локальные эмуляторы на Linux');
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  await ConfigService.initialize();
  await NotificationService.initialize();
  SyncService().initialize();

  final token = await FirebaseMessaging.instance.getToken();
  print('═══════════════════════════════════════════════════════════');
  print('🔑 ВАШ FCM ТОКЕН:');
  print(token);
  print('═══════════════════════════════════════════════════════════');
  
  runApp(const TelegraphApp());
}

class TelegraphApp extends StatelessWidget {
  const TelegraphApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AppConfigViewModel(),
        ),
      ],
      child: Consumer<AppConfigViewModel>(
        builder: (context, conf, child) {
          return MaterialApp(
            title: 'Telegraph',
            debugShowCheckedModeBanner: false,
            themeMode: conf.themeMode,
            theme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: conf.accentColor,
              brightness: Brightness.light,
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorSchemeSeed: conf.accentColor,
              brightness: Brightness.dark,
              scaffoldBackgroundColor: Colors.black,
              appBarTheme: const AppBarTheme(backgroundColor: Colors.black),
            ),
            home: const AppInitializer(),
          );
        },
      ),
    );
  }
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  bool? _hasConsent;
  bool? _isAgeVerified;
  
  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasConsent = prefs.getBool('user_consent_v1') ?? false;
      _isAgeVerified = prefs.getBool('age_verified_v1') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_hasConsent == null || _isAgeVerified == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_isAgeVerified == false) {
      return const AgeVerificationPage();
    }
    
    if (_hasConsent == false) {
      return const ConsentPage();
    }

    // Без SecureApplication - просто проверяем PIN и авторизацию
    return Consumer<AppConfigViewModel>(
      builder: (context, auth, _) {
        if (auth.userId.isEmpty) {
          return const AuthPage();
        }
        
        // Если есть PIN-код и он не введён - показываем PIN Lock
        if (auth.pinCode != null && auth.pinCode!.isNotEmpty) {
          return const PinLockScreen();
        }
        
        if (!auth.isEmailVerified) {
          return _buildVerificationUI(context, auth);
        }
        
        return const GlitchScreen();
      },
    );
  }

  Widget _buildVerificationUI(BuildContext context, AppConfigViewModel conf) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline, size: 80, color: conf.accentColor),
              const SizedBox(height: 24),
              const Text(
                "ПОДТВЕРДИТЕ ПОЧТУ",
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                "Мы отправили письмо на ваш email. Пожалуйста, перейдите по ссылке в письме.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => conf.checkEmailVerificationStatus(),
                style: ElevatedButton.styleFrom(backgroundColor: conf.accentColor),
                child: const Text("Я ПОДТВЕРДИЛ", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () async {
                  await conf.resendVerification();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Письмо отправлено повторно")),
                    );
                  }
                },
                child: const Text("Отправить письмо еще раз", style: TextStyle(color: Colors.white54)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => conf.logout(),
                child: const Text("Сменить данные", style: TextStyle(color: Colors.redAccent)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}