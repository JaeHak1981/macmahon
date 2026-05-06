import '../../../../core/constants/tournament_enums.dart';
import '../entities/macmahon_entities.dart';
import '../entities/tournament_state.dart';
import '../services/pairing_service.dart';

class GeneratePairingUseCase {
  final PairingService _pairingService;

  GeneratePairingUseCase(this._pairingService);

  Future<MacmahonState> execute({
    required MacmahonState state,
    bool isSequentialForR1 = false,
  }) async {
    final sectionPlayers = state.currentSectionPlayers;
    if (sectionPlayers.isEmpty) {
      return state.copyWith(errorMessage: '선수가 없습니다.');
    }

    try {
      PairingResult result;
      final currentRound = state.currentRound;
      final format = state.format;
      final currentData = state.currentSectionData;

      if (format == TournamentFormat.undecided) {
        return state.copyWith(errorMessage: '대회 방식을 먼저 설정해 주세요.');
      }

      // 1. 대진 생성
      if (format == TournamentFormat.league || (format == TournamentFormat.leagueAndKnockout && currentData.stage == 1)) {
        if (currentData.groupCount > 1) {
          result = _pairingService.generateGroupLeaguePairing(
              players: sectionPlayers, round: currentRound);
        } else {
          result = _pairingService.generateAllLeagueMatches(players: sectionPlayers);
        }
      } else if (format == TournamentFormat.knockout || (format == TournamentFormat.leagueAndKnockout && currentData.stage == 2)) {
        // 본선 생존자 계산 로직 (여기에 포함하거나 다른 UseCase로 분리 가능)
        final survivors = _getKnockoutSurvivors(sectionPlayers, currentData.history);
        result = _pairingService.generateKnockoutPairing(players: survivors, round: currentRound);
      } else {
        if (currentRound == 1 && isSequentialForR1) {
          result = _generateSequentialPairing(sectionPlayers);
        } else {
          result = await Future(() => _pairingService.generatePairing(players: sectionPlayers, round: currentRound));
        }
      }

      // 2. 대진 기록 반영 (Immutable하게 선수들 업데이트)
      final updatedSectionPlayers = _applyPairingToPlayers(sectionPlayers, result);
      
      // 3. 상태 업데이트
      final Map<String, MacmahonPlayer> updateMap = {
        for (final p in updatedSectionPlayers) p.id: p
      };
      final allPlayers = state.players.map((p) => updateMap[p.id] ?? p).toList();

      final newSectionData = Map<String, SectionData>.from(state.sectionData);
      newSectionData[state.selectedSection] = currentData.copyWith(currentPairing: result);
      
      return state.copyWith(
        sectionData: newSectionData,
        players: allPlayers,
        errorMessage: null,
      );
    } catch (e) {
      return state.copyWith(errorMessage: '페어링 오류: $e');
    }
  }

  /// 순차 대진 생성 (1라운드용)
  PairingResult _generateSequentialPairing(List<MacmahonPlayer> players) {
    final workingList = List<MacmahonPlayer>.from(players);
    final pairs = <MacmahonPair>[];
    MacmahonPlayer? bye;
    if (workingList.length % 2 != 0) bye = workingList.removeLast();
    for (int i = 0; i < workingList.length; i += 2) {
      pairs.add(MacmahonPair(black: workingList[i], white: workingList[i + 1], cost: 0));
    }
    return PairingResult(pairs: pairs, round: 1, byePlayers: bye != null ? [bye] : []);
  }

  /// 대진 결과를 선수들의 기록에 반영 (Immutable)
  List<MacmahonPlayer> _applyPairingToPlayers(List<MacmahonPlayer> players, PairingResult result) {
    final Map<String, MacmahonPlayer> playerMap = {for (final p in players) p.id: p};
    
    for (final pair in result.pairs) {
      final b = playerMap[pair.black.id]!;
      final w = playerMap[pair.white.id]!;
      
      playerMap[b.id] = b.copyWith(
        opponents: {...b.opponents, w.id},
        floatHistory: [...b.floatHistory, pair.blackFloatResult],
      );
      playerMap[w.id] = w.copyWith(
        opponents: {...w.opponents, b.id},
        floatHistory: [...w.floatHistory, pair.whiteFloatResult],
      );
    }

    if (result.byePlayer != null) {
      final bye = playerMap[result.byePlayer!.id]!;
      playerMap[bye.id] = bye.copyWith(
        floatHistory: [...bye.floatHistory, 0],
      );
    }

    return playerMap.values.toList();
  }

  /// 본선 생존자 추출 (Provider에 있던 로직 이관)
  List<MacmahonPlayer> _getKnockoutSurvivors(List<MacmahonPlayer> players, List<PairingResult> history) {
    if (history.isEmpty) return players;
    final lastRound = history.last;
    final survivors = <MacmahonPlayer>[];

    for (final pair in lastRound.pairs) {
      if (pair.winnerId != null) {
        survivors.add(players.firstWhere((p) => p.id == pair.winnerId));
      }
    }
    for (final bye in lastRound.byePlayers) {
      survivors.add(players.firstWhere((p) => p.id == bye.id));
    }
    return survivors;
  }
}
