import 'dart:math' as math;
import '../../features/tournament/domain/entities/macmahon_entities.dart';
import '../constants/tournament_enums.dart';

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
    
    return roundsByTopBar;
  }

  /// 순환 동률(3-way tie 등)을 올바르게 처리하며 공동 순위까지 계산하여 정렬된 선수 목록과 순위 맵을 생성합니다.
  static void computeStandings(
    List<MacmahonPlayer> players,
    TournamentFormat format,
    List<MacmahonPlayer> outSorted,
    Map<String, int> outRanks, {
    bool useHeadToHead = true,
  }) {
    // 1. 그룹별 분리
    final groups = <String, List<MacmahonPlayer>>{};
    for (var p in players) {
      final gId = p.groupId ?? "";
      groups.putIfAbsent(gId, () => []).add(p);
    }

    final isLeague = format == TournamentFormat.league || format == TournamentFormat.leagueAndKnockout;
    final sortedGroupIds = groups.keys.toList()..sort();

    for (var gId in sortedGroupIds) {
      final groupPlayers = groups[gId]!;

      // 1차: MMS 기준으로 그룹핑 (동률 판별의 기준점)
      final mmsGroups = <double, List<MacmahonPlayer>>{};
      for (var p in groupPlayers) {
        mmsGroups.putIfAbsent(p.currentMms, () => []).add(p);
      }

      final sortedMms = mmsGroups.keys.toList()..sort((a, b) => b.compareTo(a));
      int currentRank = 1;

      for (var mms in sortedMms) {
        final tiedPlayers = mmsGroups[mms]!;

        // 2차: 승자승 적용 여부에 따라 동률 그룹 내 Internal Wins 계산
        final internalWins = <String, int>{};
        if (useHeadToHead) {
          for (var p in tiedPlayers) {
            int wins = 0;
            for (var opp in tiedPlayers) {
              if (p.id != opp.id && p.defeatedOpponents.contains(opp.id)) {
                wins++;
              }
            }
            internalWins[p.id] = wins;
          }
        } else {
          for (var p in tiedPlayers) {
            internalWins[p.id] = 0; // 승자승 미적용 시 동률 유지
          }
        }

        // 3차: 다중 조건 정렬 (내부 승수 -> SODOS -> SOS -> 누진점수 -> 초기 서열 -> 총 승수)
        tiedPlayers.sort((a, b) {
          final wA = internalWins[a.id]!;
          final wB = internalWins[b.id]!;
          if (wA != wB) return wB.compareTo(wA);

          final sodosCmp = b.sodos.compareTo(a.sodos);
          if (sodosCmp != 0) return sodosCmp;

          if (!isLeague) {
            final sosCmp = b.sos.compareTo(a.sos);
            if (sosCmp != 0) return sosCmp;

            final cumCmp = b.cumulativeScore.compareTo(a.cumulativeScore);
            if (cumCmp != 0) return cumCmp;
          }

          final initCmp = b.initialMms.compareTo(a.initialMms);
          if (initCmp != 0) return initCmp;

          return b.wins.compareTo(a.wins);
        });

        // 4차: 최종 순위 부여 (모든 조건이 동일하면 공동 순위 부여)
        if (tiedPlayers.isNotEmpty) {
          int subRank = currentRank;
          outRanks[tiedPlayers[0].id] = subRank;
          outSorted.add(tiedPlayers[0]);

          for (int i = 1; i < tiedPlayers.length; i++) {
            final prev = tiedPlayers[i - 1];
            final curr = tiedPlayers[i];

            bool isSame = internalWins[curr.id] == internalWins[prev.id] &&
                curr.sodos == prev.sodos &&
                curr.initialMms == prev.initialMms &&
                curr.wins == prev.wins;

            if (!isLeague) {
              isSame = isSame && curr.sos == prev.sos && curr.cumulativeScore == prev.cumulativeScore;
            }

            if (!isSame) {
              subRank = currentRank + i; // 공동 순위일 경우 건너뛰고, 다르면 순위 하락
            }
            outRanks[curr.id] = subRank;
            outSorted.add(curr);
          }
        }
        currentRank += tiedPlayers.length;
      }
    }
  }

  /// 라운드 번호를 토너먼트 명칭(8강, 4강 등)으로 변환합니다.
  static String getRoundName({
    required int currentRound,
    required int totalRounds,
    required TournamentFormat format,
    required int playerCount,
    int stage = 1, // 단계 정보 추가
  }) {
    // 1. 순수 리그전이거나 혼합 방식의 예선 단계(stage 1)인 경우
    if (format == TournamentFormat.league || stage == 1) {
      return '$currentRound라운드';
    }
    
    // 2. 토너먼트인 경우 (knockout 또는 stage 2)
    final remainingRounds = totalRounds - currentRound;
    
    if (remainingRounds == 0) return '결승전';
    if (remainingRounds == 1) return '준결승(4강)';
    
    // 남은 라운드 수에 따른 강수 계산 (2^(남은라운드+1))
    final stageNum = math.pow(2, remainingRounds + 1).toInt();
    return '$stageNum강전';
  }
}
