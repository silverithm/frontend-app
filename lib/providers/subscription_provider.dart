import 'package:flutter/material.dart';
import '../models/subscription.dart';
import '../models/payment_failure.dart';
import '../services/api_service.dart';

class SubscriptionProvider with ChangeNotifier {
  Subscription? _subscription;
  bool _isLoading = false;
  String _errorMessage = '';

  // 결제 실패 관련 상태
  List<PaymentFailure> _paymentFailures = [];
  bool _isLoadingFailures = false;
  String _failuresErrorMessage = '';

  Subscription? get subscription => _subscription;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;

  // 결제 실패 관련 getter
  List<PaymentFailure> get paymentFailures => _paymentFailures;
  bool get isLoadingFailures => _isLoadingFailures;
  String get failuresErrorMessage => _failuresErrorMessage;
  bool get hasPaymentFailures => _paymentFailures.isNotEmpty;

  // 구독 상태 확인 메서드들
  bool get hasActiveSubscription => _subscription?.isActive ?? false;
  bool get needsSubscription => _subscription == null || !hasActiveSubscription;
  bool get hasUsedFreeSubscription => _subscription?.hasUsedFreeSubscription ?? false;
  bool get canUseFreeSubscription => !hasUsedFreeSubscription;

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  /// 구독 정보를 직접 설정 (관리자 로그인 응답에서 받은 데이터 사용)
  void setSubscription(Subscription? subscription) {
    _subscription = subscription;
    notifyListeners();
    print('[SubscriptionProvider] 구독 정보 직접 설정: ${subscription?.planDisplayName ?? '없음'}');
  }

  // 구독 정보 로드
  Future<bool> loadSubscription() async {
    try {
      setLoading(true);
      clearError();

      print('[SubscriptionProvider] 구독 정보 로드 시작');

      final response = await ApiService().getMySubscription();
      print('[SubscriptionProvider] API 응답 전체: $response');

      // 백엔드가 직접 SubscriptionResponseDTO를 반환하므로 success/data 구조가 아님
      if (response.containsKey('id') || response.containsKey('planName')) {
        print('[SubscriptionProvider] API 응답 data: $response');
        _subscription = Subscription.fromJson(response);
        print('[SubscriptionProvider] 구독 정보 로드 성공: ${_subscription?.planDisplayName}');
        print('[SubscriptionProvider] 구독 상태: ${_subscription?.status}');
        print('[SubscriptionProvider] 구독 활성: ${_subscription?.isActive}');
        print('[SubscriptionProvider] 구독 만료일: ${_subscription?.endDate}');
        notifyListeners();
        return true;
      } else {
        print('[SubscriptionProvider] 구독 정보 없음 - response: $response');
        _subscription = null;
        notifyListeners();
        return false;
      }
    } catch (e) {
      print('[SubscriptionProvider] 구독 정보 로드 실패: $e');
      print('[SubscriptionProvider] 오류 상세: ${e.toString()}');

      // 404 에러 (구독 없음)는 정상적인 상황
      if (e.toString().contains('404') || e.toString().contains('No subscription found')) {
        print('[SubscriptionProvider] 404 오류 - 구독 없음으로 처리');
        _subscription = null;
        notifyListeners();
        return false;
      }

      setError('구독 정보를 불러오는데 실패했습니다: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 무료 구독 생성
  Future<bool> createFreeSubscription() async {
    try {
      setLoading(true);
      clearError();

      print('[SubscriptionProvider] 무료 구독 생성 시작');

      // 이미 무료 구독을 사용했는지 확인
      if (hasUsedFreeSubscription) {
        setError('무료 체험은 한 번만 사용 가능합니다');
        return false;
      }

      final response = await ApiService().createFreeSubscription();
      print('[SubscriptionProvider] 무료 구독 생성 API 응답: $response');

      // 백엔드가 직접 구독 데이터를 반환하므로 success 필드 확인 대신 데이터 존재 확인
      if (response.containsKey('id') || response.containsKey('status')) {
        print('[SubscriptionProvider] 무료 구독 생성 성공');

        // 구독 정보 다시 로드
        await loadSubscription();
        return true;
      } else {
        final errorMsg = response['message'] ?? '무료 구독 생성에 실패했습니다';
        print('[SubscriptionProvider] 무료 구독 생성 실패: $errorMsg');
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      print('[SubscriptionProvider] 무료 구독 생성 실패: $e');
      setError('무료 구독 생성에 실패했습니다: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 유료 구독 생성
  Future<bool> createPaidSubscription({
    required SubscriptionType planType,
    required PaymentType paymentType,
    required String authKey,
    required int amount,
    required String planName,
  }) async {
    try {
      setLoading(true);
      clearError();

      print('[SubscriptionProvider] 유료 구독 생성 시작: ${planType.name}');

      final response = await ApiService().createSubscription(
        planType: planType.name,
        paymentType: paymentType.name,
        authKey: authKey,
        amount: amount,
        planName: planName,
      );
      print('[SubscriptionProvider] 유료 구독 생성 API 응답: $response');

      // 백엔드가 직접 구독 데이터를 반환하므로 success 필드 확인 대신 데이터 존재 확인
      if (response.containsKey('id') || response.containsKey('status')) {
        print('[SubscriptionProvider] 유료 구독 생성 성공');

        // 구독 정보 다시 로드
        await loadSubscription();
        return true;
      } else {
        final errorMsg = response['message'] ?? '구독 생성에 실패했습니다';
        print('[SubscriptionProvider] 유료 구독 생성 실패: $errorMsg');
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      print('[SubscriptionProvider] 유료 구독 생성 실패: $e');
      setError('구독 생성에 실패했습니다: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 구독 취소
  Future<bool> cancelSubscription() async {
    try {
      setLoading(true);
      clearError();

      print('[SubscriptionProvider] 구독 취소 시작');

      final response = await ApiService().cancelSubscription();
      print('[SubscriptionProvider] 구독 취소 API 응답: $response');

      // 백엔드가 직접 구독 데이터를 반환하므로 success 필드 확인 대신 데이터 존재 확인  
      if (response.containsKey('id') || response.containsKey('status')) {
        print('[SubscriptionProvider] 구독 취소 성공');

        // 구독 정보 다시 로드
        await loadSubscription();
        return true;
      } else {
        final errorMsg = response['message'] ?? '구독 취소에 실패했습니다';
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      print('[SubscriptionProvider] 구독 취소 실패: $e');
      setError('구독 취소에 실패했습니다: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 구독 활성화
  Future<bool> activateSubscription() async {
    try {
      setLoading(true);
      clearError();

      print('[SubscriptionProvider] 구독 활성화 시작');

      final response = await ApiService().activateSubscription();
      print('[SubscriptionProvider] 구독 활성화 API 응답: $response');

      // 백엔드가 직접 구독 데이터를 반환하므로 success 필드 확인 대신 데이터 존재 확인
      if (response.containsKey('id') || response.containsKey('status')) {
        print('[SubscriptionProvider] 구독 활성화 성공');

        // 구독 정보 다시 로드
        await loadSubscription();
        return true;
      } else {
        final errorMsg = response['message'] ?? '구독 활성화에 실패했습니다';
        setError(errorMsg);
        return false;
      }
    } catch (e) {
      print('[SubscriptionProvider] 구독 활성화 실패: $e');
      setError('구독 활성화에 실패했습니다: $e');
      return false;
    } finally {
      setLoading(false);
    }
  }

  // 구독 상태에 따른 액세스 권한 확인
  bool canAccessFeature() {
    if (_subscription == null) return false;
    return _subscription!.isActive;
  }

  // 구독 만료까지 남은 일수
  int getDaysRemaining() {
    return _subscription?.daysRemaining ?? 0;
  }

  // 구독 상태 메시지
  String getSubscriptionStatusMessage() {
    if (_subscription == null) {
      return '구독이 필요합니다';
    }

    if (_subscription!.isActive) {
      final daysRemaining = getDaysRemaining();
      if (_subscription!.isFree) {
        return '무료 체험 $daysRemaining일 남음';
      } else {
        return '${_subscription!.planDisplayName} 활성';
      }
    } else if (_subscription!.isExpired) {
      return '구독이 만료되었습니다';
    } else if (_subscription!.isCancelled) {
      return '구독이 취소되었습니다';
    } else {
      return '구독이 비활성 상태입니다';
    }
  }

  // 디버그용 구독 정보 출력
  void debugPrintSubscription() {
    print('[SubscriptionProvider] === 구독 정보 ===');
    print('[SubscriptionProvider] 구독 존재: ${_subscription != null}');
    if (_subscription != null) {
      print('[SubscriptionProvider] 플랜: ${_subscription!.planDisplayName}');
      print('[SubscriptionProvider] 상태: ${_subscription!.statusDisplayName}');
      print('[SubscriptionProvider] 활성: ${_subscription!.isActive}');
      print('[SubscriptionProvider] 만료일: ${_subscription!.endDate}');
      print('[SubscriptionProvider] 남은 일수: ${_subscription!.daysRemaining}');
      print('[SubscriptionProvider] 무료 사용 여부: ${_subscription!.hasUsedFreeSubscription}');
    }
    print('[SubscriptionProvider] =================');
  }

  // 결제 실패 정보 로드
  Future<bool> loadPaymentFailures({
    int page = 0,
    int size = 10,
  }) async {
    try {
      _isLoadingFailures = true;
      _failuresErrorMessage = '';
      notifyListeners();

      print('[SubscriptionProvider] 결제 실패 정보 로드 시작');

      final response = await ApiService().getPaymentFailures(
        page: page,
        size: size,
      );

      print('[SubscriptionProvider] 결제 실패 API 응답: $response');

      // 페이지 형태의 응답 처리
      if (response.containsKey('content')) {
        final paymentFailurePage = PaymentFailurePage.fromJson(response);
        _paymentFailures = paymentFailurePage.content;
        print('[SubscriptionProvider] 결제 실패 정보 로드 성공: ${_paymentFailures.length}개');
      } else {
        // 빈 배열 또는 직접 배열 형태의 응답
        _paymentFailures = [];
        print('[SubscriptionProvider] 결제 실패 정보 없음');
      }

      notifyListeners();
      return true;
    } catch (e) {
      print('[SubscriptionProvider] 결제 실패 정보 로드 실패: $e');

      // 404 에러 (결제 실패 없음)는 정상적인 상황
      if (e.toString().contains('404') || e.toString().contains('not found')) {
        print('[SubscriptionProvider] 404 오류 - 결제 실패 없음으로 처리');
        _paymentFailures = [];
        notifyListeners();
        return true;
      }

      _failuresErrorMessage = '결제 실패 정보를 불러오는데 실패했습니다: $e';
      notifyListeners();
      return false;
    } finally {
      _isLoadingFailures = false;
      notifyListeners();
    }
  }

  // 결제 실패 에러 메시지 초기화
  void clearFailuresError() {
    _failuresErrorMessage = '';
    notifyListeners();
  }
}