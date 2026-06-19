import 'package:flutter_test/flutter_test.dart';
import 'package:macmahon/features/tournament/domain/entities/macmahon_entities.dart';
import 'package:macmahon/features/tournament/domain/services/cost_matrix_builder.dart';
import 'package:macmahon/features/tournament/domain/services/pairing_service.dart';

void main() {
  group('CostMatrixBuilder 테스트', () {
    test('리매치는 패널티(10000) 추가', () {
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
      expect(cost, greaterThanOrEqualTo(10000.0));
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

    test('MMS 2점 차이 → 비용 200 (2 × 100)', () {
      final a = MacmahonPlayer(
        id: 'P1', name: '홍길동',
        initialMms: 5, currentMms: 5,
      );
      final b = MacmahonPlayer(
        id: 'P2', name: '김철수',
        initialMms: 3, currentMms: 3,
      );

      final cost = CostMatrixBuilder.calculateCost(a, b);
      expect(cost, equals(200.0));
    });

    test('직전 Float Down 선수가 하위 선수와 매칭 시 보상 적용 (-20)', () {
      final lower = MacmahonPlayer(
        id: 'P1', name: '低점수선수',
        initialMms: 4, currentMms: 4,
        floatHistory: [-1], // 직전 Float Down
      );
      final higher = MacmahonPlayer(
        id: 'P2', name: '高점수선수',
        initialMms: 5, currentMms: 5,
      );

      final cost = CostMatrixBuilder.calculateCost(lower, higher);
      // MMS 1점 차이 100 - 보상 20 = 80
      expect(cost, equals(80.0));
    });

    test('2회 연속 Float Down → 이번도 Float Down = 패널티 500 추가', () {
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
      // MMS 1점 차이 100 + 패널티 500 = 600
      expect(cost, equals(600.0));
    });

    test('Top Bar 선수는 안티그래비티 패널티 제외', () {
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

    test('이미 부전승을 한 선수는 다음 라운드에서 부전승이 되지 않음 (중복 부전승 방지)', () {
      final p1 = MacmahonPlayer(id: 'P1', name: 'A', initialMms: 4, currentMms: 4);
      final p2 = MacmahonPlayer(id: 'P2', name: 'B', initialMms: 4, currentMms: 4);
      final p3 = MacmahonPlayer(
        id: 'P3', name: 'C',
        initialMms: 4, currentMms: 4,
        opponents: {'__dummy__'}, // P3는 이미 부전승을 했음
      );

      final result = service.generatePairing(
        players: [p1, p2, p3],
        round: 2,
      );

      // P3는 이미 부전승을 했으므로, 이번 부전승(byePlayer)은 P1 또는 P2여야 하고 P3는 아니어야 한다.
      expect(result.byePlayer!.id, isNot(equals('P3')));
      expect(result.pairs.length, equals(1));
      // P3는 페어 중 한 명으로 매칭되어야 한다.
      final p3Matched = result.pairs.any((pair) => pair.black.id == 'P3' || pair.white.id == 'P3');
      expect(p3Matched, isTrue);
    });

    test('9명 홀수 진행 시 매 라운드 부전승 선수가 교체됨 (부전 쏠림 현상 해결)', () {
      List<MacmahonPlayer> players = List.generate(
        9,
        (i) => MacmahonPlayer(
          id: 'P${i + 1}',
          name: 'Player ${i + 1}',
          initialMms: 4,
          currentMms: 4,
        ),
      );

      final Set<String> byePlayerIds = {};

      for (int round = 1; round <= 4; round++) {
        final result = service.generatePairing(players: players, round: round);
        final byePlayer = result.byePlayer;
        expect(byePlayer, isNotNull);
        
        // 부전승 선수가 기존에 부전승을 한 적이 없는지 확인
        expect(byePlayerIds.contains(byePlayer!.id), isFalse);
        byePlayerIds.add(byePlayer.id);

        // 다음 라운드를 위해 시뮬레이션: 부전승 기록 업데이트
        players = players.map((p) {
          if (p.id == byePlayer.id) {
            return p.copyWith(
              opponents: {...p.opponents, '__dummy__'},
            );
          }
          return p;
        }).toList();
      }

      // 4라운드 동안 총 4명의 서로 다른 부전승 선수가 나왔어야 함
      expect(byePlayerIds.length, equals(4));
    });
  });
}
