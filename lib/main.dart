import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'theme/app_colors.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'localization/shadcn_fallback_localizations_delegate.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/vacation_provider.dart';
import 'providers/company_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/app_version_provider.dart';
import 'providers/admin_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/notice_provider.dart';
import 'providers/approval_provider.dart';
import 'providers/chat_provider.dart';
import 'providers/dispatch_provider.dart';
import 'providers/schedule_provider.dart';
import 'services/storage_service.dart';
import 'services/api_service.dart';
import 'services/analytics_service.dart';
import 'services/fcm_service.dart';
import 'services/in_app_review_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';
import 'utils/admin_utils.dart';
import 'widgets/update_dialog.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 환경 변수 로드 (안전하게 처리)
  try {
    await dotenv.load(fileName: ".env");
    print('[ENV] .env 파일 로드 성공');
  } catch (e) {
    print('[ENV] .env 파일 로드 실패: $e');
    print('[ENV] 기본값으로 계속 진행...');
  }

  // Firebase 초기화
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // FCM 백그라운드 메시지 핸들러 설정
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // 검토용 스크린샷 캡처 실행(SHOT_MODE) — 시스템 권한 팝업으로 부팅이
  // 멈추지 않게 알림 초기화·APNs 대기를 건너뛴다 (일반 빌드에는 영향 없음)
  const bool isScreenshotRun = bool.fromEnvironment('SHOT_MODE');

  // iOS에서 APNS 토큰 초기화 대기
  if (!isScreenshotRun && defaultTargetPlatform == TargetPlatform.iOS) {
    await Future.delayed(Duration(milliseconds: 2000)); // 2초 대기
  }

  // Analytics 서비스 초기화
  AnalyticsService().initialize();

  // 저장소 서비스 초기화
  await StorageService().init();

  // FCM 서비스 초기화
  if (!isScreenshotRun) {
    await FCMService().initialize();
  }
  
  // 인앱 리뷰 서비스 초기화
  await InAppReviewService().initializeInstallDate();
  await InAppReviewService().incrementLaunchCount();

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
        ChangeNotifierProvider(create: (_) => AdminProvider()),
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) => NoticeProvider()),
        ChangeNotifierProvider(create: (_) => ApprovalProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => DispatchProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return shadcn.ShadcnApp(
            navigatorKey: FCMService.navigatorKey,
            title: 'Frontend App',
            // shadcn 위젯도 앱 테마(Seed 그레이 + 케어브이 틸)와 색을 맞춘다
            theme: shadcn.ThemeData(
              colorScheme: shadcn.ColorSchemes.lightZinc.copyWith(
                primary: () => const Color(0xFF20C997),
                primaryForeground: () => const Color(0xFFFFFFFF),
                ring: () => const Color(0xFF20C997),
                foreground: () => const Color(0xFF1A1C20),
                cardForeground: () => const Color(0xFF1A1C20),
                popoverForeground: () => const Color(0xFF1A1C20),
                secondary: () => const Color(0xFFF3F4F5),
                secondaryForeground: () => const Color(0xFF1A1C20),
                muted: () => const Color(0xFFF3F4F5),
                mutedForeground: () => const Color(0xFF868B94),
                accent: () => const Color(0xFFF3F4F5),
                accentForeground: () => const Color(0xFF1A1C20),
                border: () => const Color(0xFFDCDEE3),
                input: () => const Color(0xFFDCDEE3),
              ),
              radius: 0.5,
            ),
            darkTheme: shadcn.ThemeData(
              colorScheme: shadcn.ColorSchemes.darkZinc.copyWith(
                primary: () => const Color(0xFF20C997),
                primaryForeground: () => const Color(0xFFFFFFFF),
                ring: () => const Color(0xFF20C997),
              ),
              radius: 0.5,
            ),
            themeMode: appProvider.isDarkMode
                ? shadcn.ThemeMode.dark
                : shadcn.ThemeMode.light,
            home: const AuthWrapper(),
            navigatorObservers: [AnalyticsService().observer],
            localizationsDelegates: const [
              ShadcnFallbackLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('ko', 'KR'),
              Locale('en', 'US'),
            ],
            locale: const Locale('ko', 'KR'),
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
      // (FCM 알림 이동은 더 이상 이 context를 캐싱하지 않고, ShadcnApp에 물린
      // FCMService.navigatorKey로 직접 처리한다 — 화면 스택이 바뀌어도 안전하다)
      ApiService().setGlobalContext(context);

      // 앱 버전 체크
      final appVersionProvider = context.read<AppVersionProvider>();
      await appVersionProvider.checkAppVersion();

      context.read<AuthProvider>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthProvider, AppVersionProvider>(
      builder: (context, authProvider, appVersionProvider, child) {
        // 버전 체크 또는 인증 체크가 완료되지 않았을 때
        if (!appVersionProvider.isVersionChecked ||
            !authProvider.isInitialized) {
          return Scaffold(
            backgroundColor: AppColors.black,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 이름은 글자로 쓴다 — 'app_icon_with_text_3.png'에는 이름이 들어있지 않고
                  // 넓은 빈 캔버스에 마크만 얹혀 있어, 정사각형 상자에 맞추면 작게 쪼그라든다.
                  Image.asset(
                    'assets/images/app_icon.png',
                    width: 120,
                    height: 120,
                    semanticLabel: '케어브이',
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '케어브이',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                ],
              ),
            ),
          );
        }

        // 로그인되지 않은 경우에만 로그인 화면으로 이동
        if (!authProvider.isLoggedIn) {
          print('[AuthWrapper] 로그인되지 않음 - 로그인 화면 표시');
          return const LoginScreen();
        }

        // 업데이트가 필요한 경우 업데이트 다이얼로그 표시
        if (appVersionProvider.needsUpdate &&
            !appVersionProvider.forceUpdate &&
            !_dialogShown) {
          // 선택적 업데이트 - 다이얼로그를 한 번만 표시
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !_dialogShown) {
              _dialogShown = true;
              showDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: AppColors.black.withValues(alpha: 0.5),
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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && !_dialogShown) {
              _dialogShown = true;
              showDialog(
                context: context,
                barrierDismissible: false,
                barrierColor: AppColors.black.withValues(alpha: 0.5),
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

        // 로그인 상태에 따라 화면 분기 (항상 백그라운드 화면 렌더링)
        Widget backgroundScreen;
        if (authProvider.isLoggedIn) {
          print('[AuthWrapper] 로그인된 사용자 정보:');
          print('[AuthWrapper] - 이름: ${authProvider.currentUser?.name}');
          print('[AuthWrapper] - 역할: ${authProvider.currentUser?.role}');
          print(
            '[AuthWrapper] - 회사: ${authProvider.currentUser?.company?.name}',
          );
          print(
            '[AuthWrapper] - canAccessAdminPages: ${AdminUtils.canAccessAdminPages(authProvider.currentUser)}',
          );

          // 모든 사용자는 동일한 MainScreen을 사용 (역할에 따른 네비게이션은 MainScreen 내부에서 처리)
          print(
            '[AuthWrapper] 메인 화면 표시 (역할: ${authProvider.currentUser?.role})',
          );
          backgroundScreen = const MainScreen();
        } else {
          backgroundScreen = const LoginScreen();
        }

        return backgroundScreen;
      },
    );
  }
}
