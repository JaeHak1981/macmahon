/// 헝가리안 알고리즘 (Hungarian Algorithm) — 최소 비용 최적 매칭
///
/// 시간복잡도: O(n³)
/// 용도: 비용 행렬에서 전체 비용 합이 최소가 되는 완전 매칭을 찾는다.
///
/// 참고: 이 구현은 짝수 n을 전제로 합니다.
/// 홀수 선수의 경우 PairingService 레이어에서 더미 선수를 추가하여 처리합니다.
class HungarianSolver {
  /// 비용 행렬 [costMatrix]에서 최소 비용 완전 매칭 인덱스 쌍을 반환합니다.
  ///
  /// 반환값: [(i, j), ...] 형태의 매칭 쌍 리스트
  /// 각 선수 인덱스는 정확히 1번씩만 등장합니다.
  static List<(int, int)> solve(List<List<double>> costMatrix) {
    final int n = costMatrix.length;
    assert(n % 2 == 0, '헝가리안 알고리즘은 짝수 크기 행렬이 필요합니다.');

    // ── 헝가리안 알고리즘 구현 ────────────────────────────────
    // 표준 헝가리안 알고리즘 (Kuhn-Munkres)
    // potential[i]: row i의 포텐셜 값
    // potential[n + j]: column j의 포텐셜 값
    final List<double> u = List.filled(n + 1, 0.0); // row 포텐셜
    final List<double> v = List.filled(n + 1, 0.0); // col 포텐셜
    final List<int> p = List.filled(n + 1, 0); // p[j] = i: column j에 매칭된 row
    final List<int> way = List.filled(n + 1, 0); // 역추적용

    for (int i = 1; i <= n; i++) {
      p[0] = i;
      int j0 = 0;
      final List<double> minVal = List.filled(n + 1, double.infinity);
      final List<bool> used = List.filled(n + 1, false);

      do {
        used[j0] = true;
        final int i0 = p[j0];
        double delta = double.infinity;
        int j1 = -1;

        for (int j = 1; j <= n; j++) {
          if (!used[j]) {
            // 비용 행렬은 0-indexed, 여기서 (i0-1, j-1) 사용
            final double cur = costMatrix[i0 - 1][j - 1] - u[i0] - v[j];
            if (cur < minVal[j]) {
              minVal[j] = cur;
              way[j] = j0;
            }
            if (minVal[j] < delta) {
              delta = minVal[j];
              j1 = j;
            }
          }
        }

        for (int j = 0; j <= n; j++) {
          if (used[j]) {
            u[p[j]] += delta;
            v[j] -= delta;
          } else {
            minVal[j] -= delta;
          }
        }
        j0 = j1;
      } while (p[j0] != 0);

      do {
        final int j1 = way[j0];
        p[j0] = p[j1];
        j0 = j1;
      } while (j0 != 0);
    }

    // ── 결과 추출 ─────────────────────────────────────────────
    // p[j] = i 관계에서 매칭 쌍 (i-1, j-1) 추출 (0-indexed 변환)
    // 중복 없이 쌍으로 변환
    final List<(int, int)> result = [];
    final Set<int> matched = {};

    for (int j = 1; j <= n; j++) {
      final int i = p[j];
      if (i == 0) continue;
      final int row = i - 1;
      final int col = j - 1;
      if (!matched.contains(row) && !matched.contains(col)) {
        result.add((row, col));
        matched.add(row);
        matched.add(col);
      }
    }

    return result;
  }
}
