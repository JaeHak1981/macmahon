import 'package:flutter_test/flutter_test.dart';
import 'package:macmahon/features/tournament/domain/entities/macmahon_entities.dart';
import 'package:macmahon/features/tournament/domain/entities/tournament_state.dart';
import 'package:macmahon/features/tournament/domain/usecases/calculate_standings_usecase.dart';
import 'package:macmahon/core/constants/tournament_enums.dart';

void main() {
  late CalculateStandingsUseCase useCase;

  setUp(() {
    useCase = CalculateStandingsUseCase();
  });

  group('CalculateStandingsUseCase - League', () {
    test('should calculate correct wins and score for league', () {
      final player1 = MacmahonPlayer(id: '1', name: 'Player 1', section: 'A', initialMms: 0.0, currentMms: 0.0);
      final player2 = MacmahonPlayer(id: '2', name: 'Player 2', section: 'A', initialMms: 0.0, currentMms: 0.0);
      
      final pair = MacmahonPair(
        black: player1,
        white: player2,
        winnerId: '1',
        isResultEntered: true,
        cost: 0,
      );

      final state = MacmahonState(
        id: 'test',
        selectedSection: 'A',
        sectionData: {
          'A': SectionData(
            format: TournamentFormat.league,
            currentPairing: PairingResult(round: 1, pairs: [pair]),
          ),
        },
        players: [player1, player2],
      );

      final newState = useCase.execute(state);
      final updatedPlayer1 = newState.players.firstWhere((p) => p.id == '1');
      final updatedPlayer2 = newState.players.firstWhere((p) => p.id == '2');

      expect(updatedPlayer1.wins, 1);
      expect(updatedPlayer1.currentMms, 1.0);
      expect(updatedPlayer2.wins, 0);
      expect(updatedPlayer2.losses, 1);
      expect(updatedPlayer2.currentMms, 0.0);
    });
  });
}
