import 'package:flutter_test/flutter_test.dart';
import 'package:macmahon/features/tournament/domain/entities/macmahon_player.dart';
import 'package:macmahon/core/services/cost_matrix_builder.dart';
import 'package:macmahon/core/services/pairing_service.dart';

void main() {
  group('CostMatrixBuilder 테스트', () {
    test('리매치는 절대 금지 비용(999999) 반환', () {
      final a = MacmahonPlayer(
        id: 'P1', name: '홍길동',
        initialMms: 4, currentMms: 4,
        opponents: {'P2'},
      );
      final b = MacmahonPlayer(
        id: 'P2', name: '김철수',
        initialMms: 4, currentMms: 4,
        opponents: {'P1'},
      );

      final cost = CostMatrixBuilder.calculateCost(a, b);
      expect(cost, equals(CostMatrixBuilder.kRematchPenalty));
    });

    test('같은 MMS 동점 매칭 비용 = 0 (안티그래비티 기록 없을 때)', () {
      final a = MacmahonPlayer(
        id: 'P1', name: '홍길동',
        initialMms: 4, currentMms: 4,
      );
      final b = MacmahonPlayer(
        id: 'P2', name: '김철수',
        initialMms: 4, currentMms: 4,
      );

      final cost = CostMatrixBuilder.calculateCost(a, b);
      expect(cost, equals(0.0));
    });

    test('MMS 2점 차이 → 비용 400 (2² × 100)', () {
      final a = MacmahonPlayer(
        id: 'P1', name: '홍길동',
        initialMms: 5, currentMms: 5,
      );
      final b = MacmahonPlayer(
        id: 'P2', name: '김철수',
        initialMms: 3, currentMms: 3,
      );

      final cost = CostMatrixBuilder.calculateCost(a, b);
      // MMS 차이 2점 → Float Down for A → 안티그래비티 없음 (firstFloat)
      expect(cost, equals(400.0));
    });

    test('[규칙 1] 직전 Float Down → 이번도 Float Down = 비용 1000 추가', () {
      final higher = MacmahonPlayer(
        id: 'P1', name: '高점수선수',
        initialMms: 5, currentMms: 5,
        floatHistory: [-1], // 직전 라운드 Float Down
      );
      final lower = MacmahonPlayer(
        id: 'P2', name: '低점수선수',
        initialMms: 4, currentMms: 4,
      );

      final cost = CostMatrixBuilder.calculateCost(higher, lower);
      // MMS 1점 차이: 100 + 안티그래비티 1000 = 1100
      expect(cost, equals(100.0 + CostMatrixBuilder.kAntigravityWeak));
    });

    test('[규칙 3] 2회 연속 Float Down → 이번도 Float Down = 절대 금지 비용', () {
      final higher = MacmahonPlayer(
        id: 'P1', name: '高점수선수',
        initialMms: 5, currentMms: 5,
        floatHistory: [-1, -1], // 2회 연속 Float Down
      );
      final lower = MacmahonPlayer(
        id: 'P2', name: '低점수선수',
        initialMms: 4, currentMms: 4,
      );

      final cost = CostMatrixBuilder.calculateCost(higher, lower);
      // 절대 금지 수준 비용
      expect(cost, greaterThanOrEqualTo(CostMatrixBuilder.kAntigravityAbsolute));
    });

    test('Top Bar 선수는 안티그래비티 페널티 제외', () {
      final topBar = MacmahonPlayer(
        id: 'P1', name: 'TopBar선수',
        initialMms: 5, currentMms: 5,
        isTopBar: true,
        floatHistory: [-1, -1], // 2회 연속 Float Down이지만 Top Bar
      );
      final lower = MacmahonPlayer(
        id: 'P2', name: '低점수선수',
        initialMms: 4, currentMms: 4,
      );

      final cost = CostMatrixBuilder.calculateCost(topBar, lower);
      // Top Bar → 안티그래비티 미적용 → 비용 100 (MMS 1점 차이만)
      expect(cost, equals(100.0));
    });
  });

  group('PairingService 통합 테스트', () {
    late PairingService service;

    setUp(() {
      service = PairingService();
    });

    test('짝수 선수 정상 페어링 — 부전승 없음', () {
      final players = [
        MacmahonPlayer(id: 'P1', name: 'A', initialMms: 4, currentMms: 4),
        MacmahonPlayer(id: 'P2', name: 'B', initialMms: 4, currentMms: 4),
        MacmahonPlayer(id: 'P3', name: 'C', initialMms: 3, currentMms: 3),
        MacmahonPlayer(id: 'P4', name: 'D', initialMms: 3, currentMms: 3),
      ];

      final result = service.generatePairing(players: players, round: 1);

      expect(result.pairs.length, equals(2));
      expect(result.byePlayer, isNull);
    });

    test('홀수 선수 → 부전승 1명 발생', () {
      final players = [
        MacmahonPlayer(id: 'P1', name: 'A', initialMms: 4, currentMms: 4),
        MacmahonPlayer(id: 'P2', name: 'B', initialMms: 4, currentMms: 4),
        MacmahonPlayer(id: 'P3', name: 'C', initialMms: 3, currentMms: 3),
      ];

      final result = service.generatePairing(players: players, round: 1);

      expect(result.pairs.length, equals(1));
      expect(result.byePlayer, isNotNull);
    });

    test('안티그래비티: 2회 연속 Float Down 선수는 Float Down 매칭 회피', () {
      // P1이 2회 연속 Float Down → P1은 이번 Float Down 불가
      final p1 = MacmahonPlayer(
        id: 'P1', name: '연속Down선수',
        initialMms: 5, currentMms: 5,
        floatHistory: [-1, -1], // 2회 연속 Float Down
      );
      final p2 = MacmahonPlayer(
        id: 'P2', name: '동점A',
        initialMms: 5, currentMms: 5,
      );
      final p3 = MacmahonPlayer(
        id: 'P3', name: '하위A',
        initialMms: 4, currentMms: 4,
      );
      final p4 = MacmahonPlayer(
        id: 'P4', name: '하위B',
        initialMms: 4, currentMms: 4,
      );

      final result = service.generatePairing(
        players: [p1, p2, p3, p4],
        round: 3,
      );

      // P1은 동점 매칭(P2)을 받아야 함 → Float Down 아님
      final p1Pair = result.pairs.firstWhere(
        (pair) => pair.black.id == 'P1' || pair.white.id == 'P1',
      );
      final p1Opponent =
          p1Pair.black.id == 'P1' ? p1Pair.white : p1Pair.black;

      // 안티그래비티에 의해 P1은 동점인 P2와 매칭되어야 함
      expect(p1Opponent.id, equals('P2'));
    });

    test('floatHistory가 applyPairingResult 후 업데이트됨', () {
      final players = [
        MacmahonPlayer(id: 'P1', name: 'A', initialMms: 4, currentMms: 4),
        MacmahonPlayer(id: 'P2', name: 'B', initialMms: 4, currentMms: 4),
      ];

      final result = service.generatePairing(players: players, round: 1);
      service.applyPairingResult(result);

      // 동점 매칭이므로 floatHistory에 0 추가
      expect(players[0].floatHistory.last, equals(0));
      expect(players[1].floatHistory.last, equals(0));
    });
  });
}
