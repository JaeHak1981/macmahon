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
    
    // 1. 전체 인원 기준 최소 라운드 (log2 N)
    int roundsByTotal = (math.log(playerCount) / math.log(2)).ceil();
    if (playerCount >= 4 && roundsByTotal < 3) roundsByTotal = 3;

    if (topBarCount == null) return roundsByTotal;

    // 2. Top Bar 기준 라운드 (Top Bar 내에서 우승자를 가리기 위한 최소 라운드)
    int roundsByTopBar = (math.log(topBarCount) / math.log(2)).ceil();
    
    // 3. 두 기준 중 더 긴 라운드를 선택하여 전체 대회의 질을 보장
    return math.max(roundsByTotal, roundsByTopBar);
  }
}
