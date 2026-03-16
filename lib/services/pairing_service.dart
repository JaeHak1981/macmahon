import '../models/macmahon_pair.dart';
import '../models/macmahon_player.dart';
import 'cost_matrix_builder.dart';
import 'hungarian_solver.dart';

/// 맥마흔 시스템 페어링 비즈니스 로직
///
/// 담당:
///   - 홀수 선수 처리 (더미 선수 추가)
///   - 비용 행렬 생성 위임 (CostMatrixBuilder)
///   - 최적 매칭 계산 (HungarianSolver)
///   - 결과 정리 및 floatResult 적용
class PairingService {
  /// 주어진 선수 목록에 대해 최적 페어링을 수행합니다.
  ///
  /// [players]: 현재 라운드에 참가하는 선수 목록
  /// [round]: 현재 라운드 번호
  ///
  /// 반환: [PairingResult] — 대진 목록 + 부전승 선수
  PairingResult generatePairing({
    required List<MacmahonPlayer> players,
    required int round,
  }) {
    if (players.isEmpty) {
      return PairingResult(pairs: [], round: round);
    }

    // ── 1. 선수 정렬 (MMS 내림차순) ───────────────────────────
    final List<MacmahonPlayer> workingList = List.from(players);
    workingList.sort((a, b) => b.currentMms.compareTo(a.currentMms));

    // ── 2. 홀수 선수 처리: 더미 선수 추가 ───────────────────────
    if (workingList.length % 2 != 0) {
      final dummy = _createDummyPlayer(workingList);
      workingList.add(dummy);
      // 더미 추가 후 다시 정렬 (더미가 가장 아래로 가도록)
      workingList.sort((a, b) => b.currentMms.compareTo(a.currentMms));
    }

    final int n = workingList.length;
    final int m = n ~/ 2;

    // ── 3. 이분 매칭(Bipartite) 할당을 위한 리스트 분할 ─────────────
    // [0, 2, 4...] 인덱스와 [1, 3, 5...] 인덱스로 분할하여
    // 최대한 가까운 순위끼리 매칭되도록 보장하면서 모든 선수가 짝을 찾게 합니다.
    final List<MacmahonPlayer> leftSide = [];
    final List<MacmahonPlayer> rightSide = [];
    for (int i = 0; i < n; i++) {
      if (i % 2 == 0) {
        leftSide.add(workingList[i]);
      } else {
        rightSide.add(workingList[i]);
      }
    }

    // ── 4. 비용 행렬 생성 (m x m) ─────────────────────────────
    final costMatrix = List.generate(
      m,
      (i) => List.generate(m, (j) => CostMatrixBuilder.calculateCost(leftSide[i], rightSide[j])),
    );

    // ── 5. 헝가리안 알고리즘으로 최적 매칭 계산 ─────────────────
    final matchedIndices = HungarianSolver.solve(costMatrix);

    // ── 6. 결과 정리 ─────────────────────────────────────────────
    final List<MacmahonPair> pairs = [];
    MacmahonPlayer? byePlayer;

    for (final (i, j) in matchedIndices) {
      final playerA = leftSide[i];
      final playerB = rightSide[j];

      // 더미 선수와 매칭된 경우 → 부전승 처리
      if (playerA.id == _kDummyId) {
        byePlayer = playerB;
        continue;
      }
      if (playerB.id == _kDummyId) {
        byePlayer = playerA;
        continue;
      }

      // 흑/백 배정: MMS 높은 선수가 흑번
      final MacmahonPlayer black;
      final MacmahonPlayer white;
      if (playerA.currentMms >= playerB.currentMms) {
        black = playerA;
        white = playerB;
      } else {
        black = playerB;
        white = playerA;
      }

      pairs.add(MacmahonPair(
        black: black,
        white: white,
        cost: costMatrix[i][j],
      ));
    }

    return PairingResult(
      pairs: pairs,
      round: round,
      byePlayer: byePlayer,
    );
  }

  /// 페어링 결과를 선수 데이터에 반영합니다.
  ///
  /// 대진표가 확정된 후 호출하여 floatHistory와 opponents를 업데이트합니다.
  /// 실제 승패 처리는 게임 종료 후 별도로 처리해야 합니다.
  void applyPairingResult(PairingResult result) {
    for (final pair in result.pairs) {
      // 상대 기록 추가
      pair.black.addOpponent(pair.white.id);
      pair.white.addOpponent(pair.black.id);

      // floatHistory에 이번 라운드 결과 추가 (점수 변화는 게임 결과 후 적용)
      pair.black.floatHistory.add(pair.blackFloatResult);
      pair.white.floatHistory.add(pair.whiteFloatResult);
    }

    // 부전승 선수: Float 0으로 기록
    result.byePlayer?.floatHistory.add(0);
  }

  // ── 내부 유틸리티 ─────────────────────────────────────────

  static const String _kDummyId = '__dummy__';

  /// 홀수 선수 상황에서 더미 선수를 생성합니다.
  /// 더미 선수는 가장 낮은 MMS를 가지도록 설정하여
  /// CostMatrixBuilder가 가장 낮은 점수대 선수와 매칭하도록 유도합니다.
  MacmahonPlayer _createDummyPlayer(List<MacmahonPlayer> players) {
    final lowestMms =
        players.map((p) => p.currentMms).reduce((a, b) => a < b ? a : b);
    return MacmahonPlayer(
      id: _kDummyId,
      name: 'BYE',
      initialMms: lowestMms - 1,
      currentMms: lowestMms - 1,
    );
  }
}
