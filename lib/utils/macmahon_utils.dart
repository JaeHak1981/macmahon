import 'dart:math' as math;

/// 맥마흔 시스템 유틸리티
class MacmahonUtils {
  /// 선수 인원에 따른 추천 라운드 수를 계산합니다.
  ///
  /// [playerCount]: 전체 참가자 수
  /// [topBarCount]: Top Bar(우승 가능권)에 속한 선수 수 (선택 사항)
  ///
  /// 계산 원리:
  /// 1. 기본적으로 $2^R \ge N$을 만족하는 최소 라운드 $R = \lceil \log_2(N) \rceil$을 기준으로 합니다.
  /// 2. Top Bar가 설정된 경우, Top Bar 인원 내에서 유일한 우승자를 가릴 수 있도록 계산합니다.
  /// 3. 맥마흔 시스템은 스위스 리그보다 효율적이므로, 인원이 많아도 적절한 대국 수를 보장합니다.
  static int calculateRecommendedRounds(int playerCount, {int? topBarCount}) {
    if (playerCount <= 1) return 0;
    
    // 기준이 되는 인원 (Top Bar가 있으면 Top Bar 기준, 없으면 전체 인원 기준)
    final int targetN = topBarCount ?? playerCount;
    
    // log2(N) 계산
    int rounds = (math.log(targetN) / math.log(2)).ceil();
    
    // 최소 라운드 보정
    // - 2~3명: 1~2라운드
    // - 4~8명: 최소 3라운드 (변수 고려)
    // - 그 이상: 계산값 유지
    if (targetN >= 4 && rounds < 3) {
      rounds = 3;
    }

    // 인원 대비 최대 라운드 제한 (너무 많은 라운드는 체력적/시간적 문제 발생)
    // 일반적으로 대규모 대회도 5~7라운드 내외로 진행됨
    if (rounds > 10) rounds = 10;
    
    return rounds;
  }
}
