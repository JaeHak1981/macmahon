import '../../domain/entities/macmahon_entities.dart';
import '../../domain/entities/tournament_state.dart';
import '../../domain/services/pairing_service.dart';
import '../../../../core/constants/tournament_enums.dart';
import 'calculate_standings_usecase.dart';

class ManageKnockoutUseCase {
  final PairingService _pairingService;
  final CalculateStandingsUseCase _calculateStandingsUseCase;

  ManageKnockoutUseCase(this._pairingService, this._calculateStandingsUseCase);

  MacmahonState generateManualPairing({
    required MacmahonState state,
    required List<MacmahonPlayer> orderedPlayers,
  }) {
    final result = _pairingService.generateKnockoutPairingManual(
      orderedPlayers: orderedPlayers,
      round: 1,
    );

    final currentData = state.currentSectionData;
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      currentPairing: result,
      stage: 2,
      currentRound: 1,
      knockoutQualifiers: orderedPlayers.map((p) => p.id).toList(),
    );

    final newState = state.copyWith(sectionData: newSectionData);
    return _calculateStandingsUseCase.execute(newState);
  }

  MacmahonState resetKnockoutStage(MacmahonState state) {
    final currentData = state.currentSectionData;
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      stage: 1,
      clearCurrentPairing: true,
      knockoutQualifiers: [],
    );
    
    final newState = state.copyWith(sectionData: newSectionData);
    return _calculateStandingsUseCase.execute(newState);
  }
}
