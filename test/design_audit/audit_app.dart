// lib/main.dart 의 MyApp 과 같은 앱 뿌리(테마·로컬라이제이션·프로바이더 14개)를 그대로 옮긴 것.
// 달라진 점은 단 하나 — ChatProvider 대신 소켓을 열지 않는 AuditChatProvider 를 쓴다
// (wss://silverithm.site 로 실제 접속하지 않기 위해). main.dart 가 바뀌면 여기도 맞춰 고친다.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:frontend_app/localization/shadcn_fallback_localizations_delegate.dart';
import 'package:frontend_app/main.dart' show AuthWrapper;
import 'package:frontend_app/providers/admin_provider.dart';
import 'package:frontend_app/providers/app_provider.dart';
import 'package:frontend_app/providers/app_version_provider.dart';
import 'package:frontend_app/providers/approval_provider.dart';
import 'package:frontend_app/providers/auth_provider.dart';
import 'package:frontend_app/providers/chat_provider.dart';
import 'package:frontend_app/providers/company_provider.dart';
import 'package:frontend_app/providers/dispatch_provider.dart';
import 'package:frontend_app/providers/notice_provider.dart';
import 'package:frontend_app/providers/notification_provider.dart';
import 'package:frontend_app/providers/schedule_provider.dart';
import 'package:frontend_app/providers/subscription_provider.dart';
import 'package:frontend_app/providers/vacation_provider.dart';
import 'package:frontend_app/providers/work_task_provider.dart';
import 'package:frontend_app/services/analytics_service.dart';
import 'package:frontend_app/services/fcm_service.dart';
import 'package:frontend_app/theme/app_colors.dart';
import 'package:frontend_app/theme/app_theme.dart';
import 'package:frontend_app/theme/app_typography.dart';
import 'package:frontend_app/theme/text_scale.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// 소켓을 열지 않고 "연결됨"으로 보이는 ChatProvider.
class AuditChatProvider extends ChatProvider {
  @override
  Future<void> connectWebSocket() async {}
  @override
  void ensureConnected() {}
  @override
  bool get isConnected => true;
}

const _appTypography = shadcn.Typography.geist(
  sans: TextStyle(fontFamily: AppTypography.fontFamilySans),
  mono: TextStyle(fontFamily: AppTypography.fontFamilySans),
);

class AuditMyApp extends StatelessWidget {
  const AuditMyApp({super.key});

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
        ChangeNotifierProvider<ChatProvider>(create: (_) => AuditChatProvider()),
        ChangeNotifierProvider(create: (_) => ScheduleProvider()),
        ChangeNotifierProvider(create: (_) => DispatchProvider()),
        ChangeNotifierProvider(create: (_) => WorkTaskProvider()),
      ],
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return shadcn.ShadcnApp(
            navigatorKey: FCMService.navigatorKey,
            title: 'Frontend App',
            builder: (context, child) {
              final systemScale = MediaQuery.textScalerOf(context).scale(1.0);
              final scale = effectiveTextScale(systemScale, appProvider.textSize);
              final theme = Theme.of(context);
              return MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: Theme(
                  data: AppTheme.withAppChrome(theme.copyWith(
                    textTheme: theme.textTheme.apply(fontFamily: AppTypography.fontFamilySans),
                    primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: AppTypography.fontFamilySans),
                  )),
                  child: DefaultTextStyle.merge(
                    style: const TextStyle(fontFamily: AppTypography.fontFamilySans),
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              );
            },
            theme: shadcn.ThemeData(
              colorScheme: shadcn.ColorSchemes.lightZinc.copyWith(
                primary: () => AppColors.careTeal,
                primaryForeground: () => const Color(0xFFFFFFFF),
                ring: () => AppColors.careTeal,
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
              typography: _appTypography,
            ),
            darkTheme: shadcn.ThemeData(
              colorScheme: shadcn.ColorSchemes.darkZinc.copyWith(
                primary: () => AppColors.careTeal,
                primaryForeground: () => const Color(0xFFFFFFFF),
                ring: () => AppColors.careTeal,
              ),
              radius: 0.5,
              typography: _appTypography,
            ),
            themeMode: appProvider.isDarkMode ? shadcn.ThemeMode.dark : shadcn.ThemeMode.light,
            home: const AuthWrapper(),
            navigatorObservers: [AnalyticsService().observer],
            localizationsDelegates: const [
              ShadcnFallbackLocalizationsDelegate(),
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ko', 'KR'), Locale('en', 'US')],
            locale: const Locale('ko', 'KR'),
          );
        },
      ),
    );
  }
}
