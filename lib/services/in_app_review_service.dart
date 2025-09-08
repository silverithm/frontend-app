import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InAppReviewService {
  static final InAppReviewService _instance = InAppReviewService._internal();
  factory InAppReviewService() => _instance;
  InAppReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;
  
  // SharedPreferences 키
  static const String _keyHasRated = 'has_rated_app';
  static const String _keyInstallDate = 'app_install_date';
  static const String _keyLaunchCount = 'app_launch_count';
  static const String _keyLastReviewRequest = 'last_review_request_date';
  static const String _keyVacationApprovalCount = 'vacation_approval_count';
  
  // 리뷰 요청 조건
  static const int _minDaysAfterInstall = 2;
  static const int _minLaunchCount = 5;
  static const int _minVacationApprovals = 10;
  static const int _daysBetweenRequests = 30;
  
  /// 앱 설치 시 초기화
  Future<void> initializeInstallDate() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 이미 설치 날짜가 있으면 리턴
    if (prefs.containsKey(_keyInstallDate)) {
      return;
    }
    
    // 설치 날짜 저장
    final now = DateTime.now().toIso8601String();
    await prefs.setString(_keyInstallDate, now);
  }
  
  /// 앱 실행 횟수 증가
  Future<void> incrementLaunchCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_keyLaunchCount) ?? 0;
    await prefs.setInt(_keyLaunchCount, currentCount + 1);
  }
  
  /// 휴무 승인 횟수 증가
  Future<void> incrementVacationApprovalCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt(_keyVacationApprovalCount) ?? 0;
    await prefs.setInt(_keyVacationApprovalCount, currentCount + 1);
    
    // 10건 승인 후 자동으로 리뷰 요청 시도
    if ((currentCount + 1) % _minVacationApprovals == 0) {
      await requestReviewIfAppropriate();
    }
  }
  
  /// 리뷰 요청 조건 확인
  Future<bool> shouldRequestReview() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 이미 평가한 경우
    if (prefs.getBool(_keyHasRated) ?? false) {
      return false;
    }
    
    // 설치 날짜 확인
    final installDateStr = prefs.getString(_keyInstallDate);
    if (installDateStr == null) {
      return false;
    }
    
    final installDate = DateTime.parse(installDateStr);
    final daysSinceInstall = DateTime.now().difference(installDate).inDays;
    
    if (daysSinceInstall < _minDaysAfterInstall) {
      return false;
    }
    
    // 실행 횟수 확인
    final launchCount = prefs.getInt(_keyLaunchCount) ?? 0;
    if (launchCount < _minLaunchCount) {
      return false;
    }
    
    // 마지막 요청 날짜 확인
    final lastRequestStr = prefs.getString(_keyLastReviewRequest);
    if (lastRequestStr != null) {
      final lastRequest = DateTime.parse(lastRequestStr);
      final daysSinceLastRequest = DateTime.now().difference(lastRequest).inDays;
      
      if (daysSinceLastRequest < _daysBetweenRequests) {
        return false;
      }
    }
    
    return true;
  }
  
  /// 리뷰 가능 여부 확인
  Future<bool> isAvailable() async {
    try {
      return await _inAppReview.isAvailable();
    } catch (e) {
      print('[InAppReviewService] 리뷰 가능 여부 확인 실패: $e');
      return false;
    }
  }
  
  /// 리뷰 요청 (자동)
  Future<void> requestReviewIfAppropriate() async {
    // 조건 확인
    if (!await shouldRequestReview()) {
      print('[InAppReviewService] 리뷰 요청 조건 미충족');
      return;
    }
    
    // 리뷰 가능 여부 확인
    if (!await isAvailable()) {
      print('[InAppReviewService] 인앱 리뷰 사용 불가');
      return;
    }
    
    // 리뷰 요청
    await _requestReview();
  }
  
  /// 리뷰 요청 (수동 - 설정 페이지에서 호출)
  Future<void> requestReviewManually() async {
    try {
      // 리뷰 가능 여부 확인
      if (await isAvailable()) {
        // 리뷰 요청
        await _requestReview();
      } else {
        print('[InAppReviewService] 인앱 리뷰 사용 불가 - 스토어 페이지로 이동');
        await openStoreListing();
      }
    } catch (e) {
      print('[InAppReviewService] 리뷰 요청 중 오류: $e');
      // 오류 발생 시 스토어 페이지 열기 시도
      try {
        await openStoreListing();
      } catch (storeError) {
        print('[InAppReviewService] 스토어 페이지 열기도 실패: $storeError');
      }
    }
  }
  
  /// 실제 리뷰 요청
  Future<void> _requestReview() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 리뷰 요청
      await _inAppReview.requestReview();
      
      // 마지막 요청 날짜 저장
      await prefs.setString(_keyLastReviewRequest, DateTime.now().toIso8601String());
      
      print('[InAppReviewService] 리뷰 요청 완료');
    } catch (e) {
      print('[InAppReviewService] 리뷰 요청 실패: $e');
    }
  }
  
  /// 스토어 페이지 열기 (대체 방법)
  Future<void> openStoreListing() async {
    try {
      await _inAppReview.openStoreListing(
        appStoreId: '6747028185', // iOS App Store ID - 케어브이
      );
      
      // 평가 완료로 표시
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyHasRated, true);
      
      print('[InAppReviewService] 스토어 페이지 열기 완료');
    } catch (e) {
      print('[InAppReviewService] 스토어 페이지 열기 실패: $e');
    }
  }
  
  /// 평가 완료 표시 (사용자가 "다시 묻지 않기" 선택 시)
  Future<void> markAsRated() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasRated, true);
  }
  
  /// 디버그용: 저장된 데이터 초기화
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasRated);
    await prefs.remove(_keyInstallDate);
    await prefs.remove(_keyLaunchCount);
    await prefs.remove(_keyLastReviewRequest);
    await prefs.remove(_keyVacationApprovalCount);
    print('[InAppReviewService] 테스트를 위한 데이터 초기화 완료');
  }
  
  /// 디버그용: 현재 상태 출력
  Future<void> printDebugInfo() async {
    final prefs = await SharedPreferences.getInstance();
    
    print('[InAppReviewService] === 디버그 정보 ===');
    print('평가 완료: ${prefs.getBool(_keyHasRated) ?? false}');
    print('설치 날짜: ${prefs.getString(_keyInstallDate) ?? '없음'}');
    print('실행 횟수: ${prefs.getInt(_keyLaunchCount) ?? 0}');
    print('휴무 승인 횟수: ${prefs.getInt(_keyVacationApprovalCount) ?? 0}');
    print('마지막 요청: ${prefs.getString(_keyLastReviewRequest) ?? '없음'}');
    print('리뷰 요청 가능: ${await shouldRequestReview()}');
    print('인앱 리뷰 사용 가능: ${await isAvailable()}');
  }
}