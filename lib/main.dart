import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/vacation_provider.dart';
import 'providers/company_provider.dart';
import 'services/storage_service.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 저장소 서비스 초기화
  await StorageService().init();

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
  @override
  void initState() {
    super.initState();
    // 앱 시작 시 로그인 상태 확인
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().checkAuthStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        // 로딩 중일 때 스플래시 화면 표시
        if (authProvider.isLoading) {
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

        // 로그인 상태에 따라 화면 분기
        if (authProvider.isLoggedIn) {
          return const MainScreen();
        } else {
          return const LoginScreen();
        }
      },
    );
  }
}
