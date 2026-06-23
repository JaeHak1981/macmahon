import '../entities/macmahon_entities.dart';

class CostMatrixBuilder {
  /// 두 선수 간의 매칭 비용을 계산합니다.
  static double calculateCost(MacmahonPlayer a, MacmahonPlayer b) {
    if (a.id == '__dummy__' || b.id == '__dummy__') {
      final realPlayer = a.id == '__dummy__' ? b : a;
      if (realPlayer.opponents.contains('__dummy__')) {
        return 100000;
      }
      // 부전승(더미와의 매칭) 시 점수가 높을수록 매칭 비용을 비싸게 설정하여
      // 헝가리안 알고리즘이 점수가 가장 낮은 선수에게 우선적으로 부전승을 주도록 유도
      return realPlayer.currentMms * 1000;
    }

    double cost = 0;

    // 1. MMS 점수 차이 (가장 기본 비용)
    // 점수 차이가 많이 날수록 높은 비용 부여
    final double mmsDiff = (a.currentMms - b.currentMms).abs();
    cost += mmsDiff * 10000;

    // 2. 리매치 방지 (매우 높은 패널티)
    if (a.hasPlayedAgainst(b.id)) {
      cost += 1000000;
    }

    // 3. 플로팅 보상 (직전 라운드 플로팅 결과 고려)
    // 직전 라운드에 Float Down(-1) 했으면 이번엔 Float Up(+1) 하려는 경향
    if (a.wasFloatDown) {
      // a가 b보다 점수가 낮으면 Float Up이므로 유리함 (비용 감소)
      if (a.currentMms < b.currentMms) cost -= 20;
    }
    if (b.wasFloatDown) {
      if (b.currentMms < a.currentMms) cost -= 20;
    }

    // 4. 연속 플로팅 방지 (연속 Float Down 패널티)
    if (a.isConsecutiveFloatDown && a.currentMms > b.currentMms && !a.isTopBar) {
      cost += 500;
    }
    if (b.isConsecutiveFloatDown && b.currentMms > a.currentMms && !b.isTopBar) {
      cost += 500;
    }

    return cost;
  }
}
