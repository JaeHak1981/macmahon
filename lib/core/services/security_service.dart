import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 앱의 사용 기간 및 보안 관련 로직을 담당하는 서비스
class SecurityService {
  /// 만료 날짜 설정 (예: 2026년 12월 31일)
  static final DateTime expirationDate = DateTime(2026, 12, 31);

  /// 현재 시간이 만료 날짜를 지났는지 확인합니다.
  static bool isExpired() {
    final now = DateTime.now();
    return now.isAfter(expirationDate);
  }

  /// 남은 일수를 계산합니다. (UI 표시용)
  static int getRemainingDays() {
    final now = DateTime.now();
    if (isExpired()) return 0;
    return expirationDate.difference(now).inDays;
  }
}

final securityServiceProvider = Provider((ref) => SecurityService());
