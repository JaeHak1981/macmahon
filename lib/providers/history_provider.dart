import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'macmahon_provider.dart';
import '../services/storage_service.dart';

/// 저장된 전체 대회 기록을 관리하는 Provider
class TournamentHistoryNotifier extends StateNotifier<AsyncValue<List<MacmahonState>>> {
  final StorageService _storageService;

  TournamentHistoryNotifier({StorageService? storageService})
      : _storageService = storageService ?? StorageService(),
        super(const AsyncValue.loading()) {
    loadHistory();
  }

  /// 전체 기록 불러오기
  Future<void> loadHistory() async {
    state = const AsyncValue.loading();
    try {
      final history = await _storageService.getTournaments();
      // 최신 기록이 위로 오도록 정렬 (필요시)
      state = AsyncValue.data(history.reversed.toList());
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// 기록 삭제
  Future<void> deleteTournament(String name, String date) async {
    try {
      await _storageService.deleteTournament(name, date);
      await loadHistory();
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }
}

final tournamentHistoryProvider =
    StateNotifierProvider<TournamentHistoryNotifier, AsyncValue<List<MacmahonState>>>(
        (ref) => TournamentHistoryNotifier());
