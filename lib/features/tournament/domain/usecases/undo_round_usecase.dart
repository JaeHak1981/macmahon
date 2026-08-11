import '../../../../core/constants/tournament_enums.dart';
import '../entities/tournament_state.dart';
import 'calculate_standings_usecase.dart';

class UndoRoundUseCase {
  final CalculateStandingsUseCase _calculateStandingsUseCase;

  UndoRoundUseCase(this._calculateStandingsUseCase);

  MacmahonState execute(MacmahonState state) {
    final currentData = state.currentSectionData;
    if (currentData.history.isEmpty) return state;

    final restoredPairing = currentData.history.last;
    final newHistory = currentData.history.sublist(
      0,
      currentData.history.length - 1,
    );

    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      history: newHistory,
      currentRound: newHistory.length + 1,
      currentPairing: restoredPairing,
    );

    final newState = state.copyWith(sectionData: newSectionData);
    return _calculateStandingsUseCase.execute(newState);
  }
}
