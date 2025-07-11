import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/vacation_provider.dart';
import 'providers/company_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/app_version_provider.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/analytics_service.dart';
import 'services/fcm_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM 백그라운드 메시지 핸들러 설정
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // iOS에서 APNS 토큰 초기화 대기
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    await Future.delayed(Duration(milliseconds: 2000)); // 2초 대기
  }

  // Analytics 서비스 초기화
  AnalyticsService().initialize();

  // 저장소 서비스 초기화
  await StorageService().init();

  // FCM 서비스 초기화
  await FCMService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => VacationProvider()),
        ChangeNotifierProvider(create: (_) => CompanyProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => AppVersionProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            title: 'Frontend App',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: appProvider.isDarkMode
                    ? Brightness.dark
                    : Brightness.light,
              ),
              useMaterial3: true,
            ),
            home: const AuthWrapper(),
            debugShowCheckedModeBanner: false,
            navigatorObservers: [AnalyticsService().observer],
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    // 앱 시작 시 버전 체크 및 로그인 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // ApiService에 글로벌 context 설정
      ApiService().setGlobalContext(context);
      
      // 앱 버전 체크
      final appVersionProvider = context.read<AppVersionProvider>();
      await appVersionProvider.checkAppVersion();
      
      // 버전 체크 후 로그인 상태 확인
      if (!appVersionProvider.forceUpdate) {
        context.read<AuthProvider>().checkAuthStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, AppVersionProvider>(
      builder: (context, authProvider, appVersionProvider, child) {
        // 버전 체크 중이거나 로딩 중일 때 스플래시 화면 표시
        if (!appVersionProvider.isVersionChecked || authProvider.isLoading) {
          return Scaffold(
            backgroundColor: Colors.blue.shade50,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.calendar_month,
                    size: 80,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '휴무 관리 시스템',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '앱을 초기화하고 있습니다...',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 32),
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Colors.blue.shade600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 업데이트가 필요한 경우 업데이트 다이얼로그 표시
        if (appVersionProvider.needsUpdate && !appVersionProvider.forceUpdate && !_dialogShown) {
          // 선택적 업데이트 - 다이얼로그를 한 번만 표시
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !_dialogShown) {
              _dialogShown = true;
              showDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: Colors.black.withOpacity(0.5),
                builder: (context) => UpdateDialog(
                  currentVersion: appVersionProvider.currentVersion,
                  latestVersion: appVersionProvider.latestVersion,
                  updateMessage: appVersionProvider.updateMessage,
                  forceUpdate: appVersionProvider.forceUpdate,
                ),
              ).then((_) {
                _dialogShown = false;
              });
            }
          });
        }

        // 강제 업데이트가 필요한 경우 업데이트 화면만 표시
        if (appVersionProvider.forceUpdate) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: UpdateDialog(
                  currentVersion: appVersionProvider.currentVersion,
                  latestVersion: appVersionProvider.latestVersion,
                  updateMessage: appVersionProvider.updateMessage,
                  forceUpdate: true,
                ),
              ),
            ),
          );
        }

        // 로그인 상태에 따라 화면 분기 (항상 백그라운드 화면 렌더링)
        Widget backgroundScreen;
        if (authProvider.isLoggedIn) {
          backgroundScreen = const MainScreen();
        } else {
          backgroundScreen = const LoginScreen();
        }

        return backgroundScreen;
      },
    );
  }
}
