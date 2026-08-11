import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/tournament_state.dart';
import '../../domain/repositories/i_tournament_repository.dart';
import 'macmahon_provider.dart';

class TournamentHistoryNotifier
    extends StateNotifier<AsyncValue<List<MacmahonState>>> {
  final ITournamentRepository _repository;

  TournamentHistoryNotifier({required ITournamentRepository repository})
    : _repository = repository,
      super(const AsyncValue.loading()) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final history = await _repository.getTournaments();
      state = AsyncValue.data(history.reversed.toList());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> deleteTournament(String id) async {
    try {
      await _repository.deleteTournament(id);
      await loadHistory();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final tournamentHistoryProvider =
    StateNotifierProvider<
      TournamentHistoryNotifier,
      AsyncValue<List<MacmahonState>>
    >(
      (ref) => TournamentHistoryNotifier(
        repository: ref.read(tournamentRepositoryProvider),
      ),
    );
