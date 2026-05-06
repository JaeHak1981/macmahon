import 'package:flutter_test/flutter_test.dart';
import 'package:macmahon/core/services/security_service.dart';

void main() {
  group('SecurityService Tests', () {
    test('expirationDate should be set to 2026-12-31', () {
      expect(SecurityService.expirationDate.year, 2026);
      expect(SecurityService.expirationDate.month, 12);
      expect(SecurityService.expirationDate.day, 31);
    });

    test('isExpired should return false for current time (if before 2026-12-31)', () {
      // NOTE: 이 테스트는 현재 시스템 시간이 2026년 12월 31일 이전일 때만 통과합니다.
      // 현재 시간이 이미 지난 미래라면 true를 반환해야 합니다.
      final now = DateTime.now();
      if (now.isBefore(SecurityService.expirationDate)) {
        expect(SecurityService.isExpired(), isFalse);
      } else {
        expect(SecurityService.isExpired(), isTrue);
      }
    });

    // DateTime.now()를 모킹하는 라이브러리(clock 등)를 쓰지 않는 한, 
    // 정적 메서드인 SecurityService.isExpired()의 임의 시간 테스트는 제한적입니다.
    // 하지만 상수가 올바르게 설정되었는지는 위에서 확인했습니다.
  });
}
