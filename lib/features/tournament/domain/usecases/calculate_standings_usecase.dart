import '../../../../core/constants/tournament_enums.dart';
import '../entities/macmahon_entities.dart';
import '../entities/tournament_state.dart';

class CalculateStandingsUseCase {
  /// 전체 상태를 바탕으로 순위를 재계산합니다.
  MacmahonState execute(MacmahonState state) {
    final currentData = state.currentSectionData;
    final isLeague = state.format == TournamentFormat.league ||
        (state.format == TournamentFormat.leagueAndKnockout &&
            state.stage == 1);

    List<MacmahonPlayer> updatedSectionPlayers;
    if (isLeague) {
      final allPairs = [...currentData.history.expand((h) => h.pairs)];
      if (currentData.currentPairing != null) {
        allPairs.addAll(currentData.currentPairing!.pairs);
      }
      updatedSectionPlayers = calculateLeagueStandings(allPairs, state.currentSectionPlayers);
    } else {
      final List<PairingResult> allResults = [...currentData.history];
      if (currentData.currentPairing != null) {
        allResults.add(currentData.currentPairing!);
      }
      final replayed =
          calculatePlayersFromHistory(allResults, state.currentSectionPlayers, state.format, state.stage);
      updatedSectionPlayers = calculateTieBreakers(replayed, state.players);
    }

    // 전역 선수 명단 업데이트
    final Map<String, MacmahonPlayer> updateMap = {
      for (final p in updatedSectionPlayers) p.id: p
    };
    
    return state.copyWith(
      players: state.players.map((p) => updateMap[p.id] ?? p).toList(),
    );
  }

  /// 리그전 순위 계산
  List<MacmahonPlayer> calculateLeagueStandings(
    List<MacmahonPair> allPairs, 
    List<MacmahonPlayer> sectionPlayers,
  ) {
    final Map<String, _LeagueStat> stats = {
      for (final p in sectionPlayers) p.id: _LeagueStat(),
    };

    for (final pair in allPairs) {
      if (!pair.isResultEntered) continue;
      final bId = pair.black.id;
      final wId = pair.white.id;
      if (!stats.containsKey(bId) || !stats.containsKey(wId)) continue;

      if (pair.winnerId == bId) {
        stats[bId]!.wins++;
        stats[bId]!.defeated.add(wId);
        stats[wId]!.losses++;
      } else if (pair.winnerId == wId) {
        stats[wId]!.wins++;
        stats[wId]!.defeated.add(bId);
        stats[bId]!.losses++;
      } else {
        stats[bId]!.draws++;
        stats[wId]!.draws++;
      }
    }

    return sectionPlayers.map((p) {
      final s = stats[p.id] ?? _LeagueStat();
      final score = s.wins * 1.0 + s.draws * 0.5;
      return p.copyWith(
        currentMms: score,
        wins: s.wins,
        losses: s.losses,
        draws: s.draws,
        defeatedOpponents: s.defeated,
        sos: 0.0,
        sodos: 0.0,
        cumulativeScore: 0.0,
        floatHistory: [],
        opponents: s.defeated.toSet(),
        results: [],
      );
    }).toList();
  }

  /// 타이브레이커(SOS, SODOS, SOSOS) 계산
  List<MacmahonPlayer> calculateTieBreakers(
    List<MacmahonPlayer> sectionPlayers, 
    List<MacmahonPlayer> allPlayers,
  ) {
    final Map<String, MacmahonPlayer> idMap = {
      for (final p in allPlayers) p.id: p
    };
    // 현재 섹션 선수들의 최신 상태로 덮어쓰기
    for (final p in sectionPlayers) {
      idMap[p.id] = p;
    }

    // 1차: SOS, SODOS 계산
    final List<MacmahonPlayer> step1Players = sectionPlayers.map((p) {
      double sos = 0;
      for (final oId in p.opponents) {
        final o = idMap[oId];
        if (o != null && o.id != p.id) sos += o.currentMms;
      }
      double sodos = 0;
      for (final dId in p.defeatedOpponents) {
        final o = idMap[dId];
        if (o != null && o.id != p.id) sodos += o.currentMms;
      }
      return p.copyWith(sos: sos, sodos: sodos);
    }).toList();

    // idMap에 업데이트된 SOS 값 반영
    for (final p in step1Players) {
      idMap[p.id] = p;
    }

    // 2차: SOSOS 계산
    return step1Players.map((p) {
      double sosos = 0;
      for (final oId in p.opponents) {
        final o = idMap[oId];
        if (o != null && o.id != p.id) sosos += o.sos;
      }
      return p.copyWith(sosos: sosos);
    }).toList();
  }

  /// 히스토리를 바탕으로 선수들의 상태(승무패, MMS 등)를 복원/계산
  List<MacmahonPlayer> calculatePlayersFromHistory(
    List<PairingResult> history, 
    List<MacmahonPlayer> sectionPlayers,
    TournamentFormat format,
    int stage,
  ) {
    final isLeagueBase = format == TournamentFormat.league || 
                        (format == TournamentFormat.leagueAndKnockout && stage == 1);

    final Map<String, MacmahonPlayer> playerMap = {
      for (final p in sectionPlayers)
        p.id: p.copyWith(
          currentMms: isLeagueBase ? 0.0 : p.initialMms,
          wins: 0,
          losses: 0,
          draws: 0,
          opponents: {},
          defeatedOpponents: {},
          floatHistory: [],
          cumulativeScore: 0.0,
          results: [],
        )
    };

    for (final roundResult in history) {
      for (final pair in roundResult.pairs) {
        final b = playerMap[pair.black.id];
        final w = playerMap[pair.white.id];
        if (b == null || w == null) continue;

        // 상대 기록 추가 (가변 Set이 아니므로 새로 생성)
        playerMap[b.id] = b.copyWith(
          opponents: {...b.opponents, w.id},
          floatHistory: [...b.floatHistory, pair.blackFloatResult],
        );
        playerMap[w.id] = w.copyWith(
          opponents: {...w.opponents, b.id},
          floatHistory: [...w.floatHistory, pair.whiteFloatResult],
        );
        
        final updatedB = playerMap[b.id]!;
        final updatedW = playerMap[w.id]!;

        if (pair.winnerId == b.id) {
          playerMap[b.id] = updatedB.copyWith(
            wins: updatedB.wins + 1,
            currentMms: updatedB.currentMms + 1.0,
            defeatedOpponents: {...updatedB.defeatedOpponents, w.id},
            results: [...updatedB.results, 'W'],
          );
          playerMap[w.id] = updatedW.copyWith(
            losses: updatedW.losses + 1,
            results: [...updatedW.results, 'L'],
          );
        } else if (pair.winnerId == w.id) {
          playerMap[w.id] = updatedW.copyWith(
            wins: updatedW.wins + 1,
            currentMms: updatedW.currentMms + 1.0,
            defeatedOpponents: {...updatedW.defeatedOpponents, b.id},
            results: [...updatedW.results, 'W'],
          );
          playerMap[b.id] = updatedB.copyWith(
            losses: updatedB.losses + 1,
            results: [...updatedB.results, 'L'],
          );
        } else if (pair.isResultEntered) {
          playerMap[b.id] = updatedB.copyWith(
            draws: updatedB.draws + 1,
            currentMms: updatedB.currentMms + 0.5,
            results: [...updatedB.results, 'D'],
          );
          playerMap[w.id] = updatedW.copyWith(
            draws: updatedW.draws + 1,
            currentMms: updatedW.currentMms + 0.5,
            results: [...updatedW.results, 'D'],
          );
        }
      }
      for (final byePlayer in roundResult.byePlayers) {
        final bye = playerMap[byePlayer.id];
        if (bye != null) {
          playerMap[bye.id] = bye.copyWith(
            currentMms: bye.currentMms + 1.0,
            wins: bye.wins + 1,
            floatHistory: [...bye.floatHistory, 0],
            opponents: {...bye.opponents, '__dummy__'},
            results: [...bye.results, 'W'], // 부전승도 일단 'W'로 처리하거나 'B'로 할 수 있음. 기세 흐름상 'W'가 좋음.
          );
        }
      }
      // 누진 점수 업데이트
      for (final id in playerMap.keys) {
        final p = playerMap[id]!;
        playerMap[id] = p.copyWith(
          cumulativeScore: p.cumulativeScore + p.currentMms,
        );
      }
    }
    return playerMap.values.toList();
  }
}

/// 리그전 순위 계산용 임시 통계 저장 클래스
class _LeagueStat {
  int wins = 0;
  int losses = 0;
  int draws = 0;
  Set<String> defeated = {};
}
