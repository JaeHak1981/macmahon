import '../entities/tournament_state.dart';

abstract class ITournamentRepository {
  Future<List<MacmahonState>> getTournaments();
  Future<void> saveTournament(MacmahonState state);
  Future<void> deleteTournament(String id);
}
