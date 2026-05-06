import '../entities/macmahon_entities.dart';
import '../entities/tournament_state.dart';
import 'calculate_standings_usecase.dart';

class RecordResultUseCase {
  final CalculateStandingsUseCase _calculateStandings;

  RecordResultUseCase(this._calculateStandings);

  /// 특정 경기의 결과를 기록하고 전체 순위를 업데이트합니다.
  MacmahonState execute({
    required MacmahonState state,
    required String playerAId,
    required String playerBId,
    String? winnerId,
  }) {
    final currentData = state.currentSectionData;
    bool anyUpdated = false;

    // 1. 현재 대진 업데이트
    PairingResult? newCurrentPairing = currentData.currentPairing;
    if (newCurrentPairing != null) {
      final newPairs = newCurrentPairing.pairs.map((p) {
        if (((p.black.id == playerAId && p.white.id == playerBId) ||
                (p.black.id == playerBId && p.white.id == playerAId))) {
          anyUpdated = true;
          return p.setResult(winnerId);
        }
        return p;
      }).toList();
      newCurrentPairing = newCurrentPairing.copyWith(pairs: newPairs);
    }

    // 2. 히스토리 업데이트
    final newHistory = currentData.history.map((round) {
      bool foundInRound = false;
      final newPairs = round.pairs.map((p) {
        if (((p.black.id == playerAId && p.white.id == playerBId) ||
                (p.black.id == playerBId && p.white.id == playerAId))) {
          foundInRound = true;
          anyUpdated = true;
          return p.setResult(winnerId);
        }
        return p;
      }).toList();
      return foundInRound ? round.copyWith(pairs: newPairs) : round;
    }).toList();

    if (!anyUpdated) return state;

    // 3. 상태 업데이트
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      currentPairing: newCurrentPairing,
      history: newHistory,
    );

    final updatedState = state.copyWith(sectionData: newSectionData);

    // 4. 순위 재계산 및 반환
    return _calculateStandings.execute(updatedState);
  }
}
