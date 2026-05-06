import 'package:flutter_test/flutter_test.dart';
import 'package:macmahon/features/tournament/domain/entities/macmahon_player.dart';
import 'package:macmahon/features/tournament/presentation/providers/macmahon_provider.dart';
import 'package:macmahon/core/utils/macmahon_utils.dart';

void main() {
  group('성능 및 무한 루프 검증 테스트', () {
    test('200명 선수 및 순환 대진 상황에서 순위 계산 검증', () {
      // 1. 선수 생성 (200명)
      final players = List.generate(200, (i) => MacmahonPlayer(
        id: 'p$i',
        name: '선수$i',
        section: '일반부',
        initialMms: 40.0 - (i % 10),
        currentMms: 40.0 - (i % 10),
      ));

      // 2. 순환 승패 관계 강제 설정 (A->B, B->C, C->A)
      // p0 이 p1 을 이김, p1 이 p2 를 이김, p2 가 p0 을 이김
      players[0].defeatedOpponents.add('p1');
      players[1].opponents.add('p0');
      
      players[1].defeatedOpponents.add('p2');
      players[2].opponents.add('p1');
      
      players[2].defeatedOpponents.add('p0');
      players[0].opponents.add('p2');

      final sorted = <MacmahonPlayer>[];
      final ranks = <String, int>{};

      final stopwatch = Stopwatch()..start();
      
      // 3. 순위 계산 수행
      MacmahonUtils.computeStandings(
        players, 
        TournamentFormat.macmahon, 
        sorted, 
        ranks,
        useHeadToHead: true,
      );
      
      stopwatch.stop();
      
      print('순위 계산 소요 시간: ${stopwatch.elapsedMilliseconds}ms');
      
      expect(sorted.length, 200);
      expect(stopwatch.elapsedMilliseconds, lessThan(100), reason: '순위 계산이 너무 느립니다.');
    });

    test('임의의 대량 승패 기록 적용 시 연산 속도 검증', () {
      final players = List.generate(100, (i) => MacmahonPlayer(
        id: 'p$i',
        name: '선수$i',
        section: '일반부',
        initialMms: 30.0,
        currentMms: 30.0,
      ));

      // 임의로 승리 기록 추가
      for (int i = 0; i < 100; i++) {
        for (int j = 0; j < 5; j++) {
          final opponentIdx = (i + j + 1) % 100;
          players[i].defeatedOpponents.add('p$opponentIdx');
          players[i].wins++;
          players[i].currentMms += 1.0;
        }
      }

      final sorted = <MacmahonPlayer>[];
      final ranks = <String, int>{};

      final stopwatch = Stopwatch()..start();
      MacmahonUtils.computeStandings(players, TournamentFormat.macmahon, sorted, ranks);
      stopwatch.stop();

      print('대량 데이터 정렬 소요 시간: ${stopwatch.elapsedMilliseconds}ms');
      expect(stopwatch.elapsedMilliseconds, lessThan(50));
    });
  });
}
