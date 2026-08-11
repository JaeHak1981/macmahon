import '../../../../core/constants/tournament_enums.dart';
import '../entities/tournament_state.dart';
import 'calculate_standings_usecase.dart';

class AdvanceRoundUseCase {
  final CalculateStandingsUseCase _calculateStandings;

  AdvanceRoundUseCase(this._calculateStandings);

  MacmahonState execute(MacmahonState state) {
    final currentPairing = state.currentPairing;
    if (currentPairing == null) return state;

    final currentData = state.currentSectionData;
    final updatedHistory = [...currentData.history, currentPairing];

    final isFinished =
        state.format == TournamentFormat.league ||
        (state.format == TournamentFormat.leagueAndKnockout &&
            currentData.stage == 1);

    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      history: updatedHistory,
      currentRound: updatedHistory.length + 1,
      clearCurrentPairing: true,
      isFinished: isFinished,
    );

    final updatedState = state.copyWith(sectionData: newSectionData);

    // 라운드 종료 후 순위 재계산
    return _calculateStandings.execute(updatedState);
  }
}
