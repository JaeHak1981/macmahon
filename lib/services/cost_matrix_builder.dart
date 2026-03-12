import '../models/macmahon_player.dart';

/// 안티그래비티 페어링 시스템의 비용(Cost) 행렬 생성기
///
/// 비용 설계 원칙:
///   - 같은 MMS 동점 매칭          → 비용 0 (이상적)
///   - MMS n점 차이               → n² × 100 (기하급수 증가)
///   - 안티그래비티 위반 (1회 연속) → +1,000
///   - 안티그래비티 위반 (2회 연속) → +999,999 (절대 금지 수준)
///   - 리매치 (재대결)             → +999,999 (절대 금지)
class CostMatrixBuilder {
  // ─── 페널티 상수 ────────────────────────────────────────────
  static const double kMmsPenaltyFactor = 100.0; // MMS 차이 기본 계수
  static const double kAntigravityWeak = 1000.0; // 1회 연속 안티그래비티 위반
  static const double kAntigravityAbsolute = 999999.0; // 2회 연속 float → 절대 금지
  static const double kRematchPenalty = 999999.0; // 리매치 절대 금지
  // ────────────────────────────────────────────────────────────

  /// 선수 리스트로부터 n×n 비용 행렬을 생성합니다.
  ///
  /// costMatrix[i][j]: 선수 i와 선수 j 간의 페어링 비용
  /// i == j인 경우 자기 자신 대결 → 무한대 비용
  static List<List<double>> build(List<MacmahonPlayer> players) {
    final n = players.length;
    final matrix = List.generate(
      n,
      (_) => List.filled(n, 0.0),
    );

    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if (i == j) {
          matrix[i][j] = double.infinity;
          continue;
        }
        matrix[i][j] = calculateCost(players[i], players[j]);
      }
    }
    return matrix;
  }

  /// 두 선수 간의 페어링 비용을 계산합니다.
  ///
  /// [a]: 선수 A
  /// [b]: 선수 B
  /// 반환값: 낮을수록 이상적인 매칭
  static double calculateCost(MacmahonPlayer a, MacmahonPlayer b) {
    double cost = 0.0;

    // ── 1. 리매치 절대 금지 ────────────────────────────────────
    // 이미 대결한 상대라면 사실상 불가능한 비용 부여
    if (a.hasPlayedAgainst(b.id) || b.hasPlayedAgainst(a.id)) {
      return kRematchPenalty;
    }

    // ── 2. MMS 점수 차이 페널티 (n² × 100) ────────────────────
    // 점수 차이가 클수록 기하급수적으로 비용 증가
    final double mmsDiff = (a.currentMms - b.currentMms).abs();
    cost += mmsDiff * mmsDiff * kMmsPenaltyFactor;

    // ── 3. 안티그래비티 페널티 ────────────────────────────────
    // Top Bar 이상 선수는 안티그래비티 제외
    if (!a.isTopBar && !b.isTopBar) {
      // 이 페어링에서 각 선수의 예상 float 결과 계산
      final int aFloat = _predictFloat(a, b);
      final int bFloat = _predictFloat(b, a);

      // 선수 A 안티그래비티 검사
      cost += _antigravityPenalty(player: a, predictedFloat: aFloat);

      // 선수 B 안티그래비티 검사
      cost += _antigravityPenalty(player: b, predictedFloat: bFloat);
    }

    return cost;
  }

  /// 매칭 시 해당 선수의 예상 float 방향 계산
  /// self.currentMms > opponent.currentMms → Float Down(-1)
  /// self.currentMms < opponent.currentMms → Float Up(+1)
  /// 동점 → 0
  static int _predictFloat(MacmahonPlayer self, MacmahonPlayer opponent) {
    if (self.currentMms > opponent.currentMms) return -1;
    if (self.currentMms < opponent.currentMms) return 1;
    return 0;
  }

  /// 안티그래비티 페널티 계산
  ///
  /// [player]: 검사 대상 선수
  /// [predictedFloat]: 이번 라운드 예상 float 결과
  ///
  /// 규칙 3: 2회 연속 Float Down → 절대 금지 수준 페널티
  /// 규칙 1: 직전이 Float Down이고 이번도 Float Down → 강한 페널티
  /// 규칙 2: 직전이 Float Up이고 이번도 Float Up → 강한 페널티
  static double _antigravityPenalty({
    required MacmahonPlayer player,
    required int predictedFloat,
  }) {
    // 동점 매칭은 페널티 없음
    if (predictedFloat == 0) return 0.0;

    // [규칙 3] 2회 연속 Float Down → 이번도 Float Down이면 절대 금지
    if (player.isConsecutiveFloatDown && predictedFloat == -1) {
      return kAntigravityAbsolute;
    }

    // [규칙 1] 직전이 Float Down이고 이번도 Float Down → 강한 페널티
    if (player.wasFloatDown && predictedFloat == -1) {
      return kAntigravityWeak;
    }

    // [규칙 2] 직전이 Float Up이고 이번도 Float Up → 강한 페널티
    if (player.wasFloatUp && predictedFloat == 1) {
      return kAntigravityWeak;
    }

    return 0.0;
  }
}
