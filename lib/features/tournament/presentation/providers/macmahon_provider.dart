import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/tournament_enums.dart';
import '../../domain/entities/macmahon_entities.dart';
import '../../domain/entities/tournament_state.dart';
import '../../domain/repositories/i_tournament_repository.dart';
import '../../domain/usecases/calculate_standings_usecase.dart';
import '../../domain/usecases/generate_pairing_usecase.dart';
import '../../domain/usecases/record_result_usecase.dart';
import '../../domain/usecases/assign_groups_usecase.dart';
import '../../domain/usecases/advance_round_usecase.dart';
import '../../domain/usecases/undo_round_usecase.dart';
import '../../domain/usecases/manage_knockout_usecase.dart';
import '../../domain/services/pairing_service.dart';
import '../../domain/services/cost_matrix_builder.dart';
import '../../data/repositories/tournament_repository_impl.dart';

// ─── Providers ──────────────────────────────────────────

final tournamentRepositoryProvider = Provider<ITournamentRepository>(
  (ref) => TournamentRepositoryImpl(),
);

final calculateStandingsUseCaseProvider = Provider(
  (ref) => CalculateStandingsUseCase(),
);
final recordResultUseCaseProvider = Provider(
  (ref) => RecordResultUseCase(ref.read(calculateStandingsUseCaseProvider)),
);
final generatePairingUseCaseProvider = Provider(
  (ref) => GeneratePairingUseCase(PairingService()),
);
final assignGroupsUseCaseProvider = Provider((ref) => AssignGroupsUseCase());
final advanceRoundUseCaseProvider = Provider(
  (ref) => AdvanceRoundUseCase(ref.read(calculateStandingsUseCaseProvider)),
);
final undoRoundUseCaseProvider = Provider(
  (ref) => UndoRoundUseCase(ref.read(calculateStandingsUseCaseProvider)),
);
final manageKnockoutUseCaseProvider = Provider(
  (ref) => ManageKnockoutUseCase(
    PairingService(),
    ref.read(calculateStandingsUseCaseProvider),
  ),
);

final macmahonProvider = StateNotifierProvider<MacmahonNotifier, MacmahonState>(
  (ref) {
    return MacmahonNotifier(
      calculateStandingsUseCase: ref.read(calculateStandingsUseCaseProvider),
      recordResultUseCase: ref.read(recordResultUseCaseProvider),
      generatePairingUseCase: ref.read(generatePairingUseCaseProvider),
      assignGroupsUseCase: ref.read(assignGroupsUseCaseProvider),
      advanceRoundUseCase: ref.read(advanceRoundUseCaseProvider),
      undoRoundUseCase: ref.read(undoRoundUseCaseProvider),
      manageKnockoutUseCase: ref.read(manageKnockoutUseCaseProvider),
      repository: ref.read(tournamentRepositoryProvider),
    );
  },
);

// ─── Notifier ─────────────────────────────────────────────

class MacmahonNotifier extends StateNotifier<MacmahonState> {
  final CalculateStandingsUseCase _calculateStandingsUseCase;
  final RecordResultUseCase _recordResultUseCase;
  final GeneratePairingUseCase _generatePairingUseCase;
  final AssignGroupsUseCase _assignGroupsUseCase;
  final AdvanceRoundUseCase _advanceRoundUseCase;
  final UndoRoundUseCase _undoRoundUseCase;
  final ManageKnockoutUseCase _manageKnockoutUseCase;
  final ITournamentRepository _repository;

  MacmahonNotifier({
    required CalculateStandingsUseCase calculateStandingsUseCase,
    required RecordResultUseCase recordResultUseCase,
    required GeneratePairingUseCase generatePairingUseCase,
    required AssignGroupsUseCase assignGroupsUseCase,
    required AdvanceRoundUseCase advanceRoundUseCase,
    required UndoRoundUseCase undoRoundUseCase,
    required ManageKnockoutUseCase manageKnockoutUseCase,
    required ITournamentRepository repository,
  }) : _calculateStandingsUseCase = calculateStandingsUseCase,
       _recordResultUseCase = recordResultUseCase,
       _generatePairingUseCase = generatePairingUseCase,
       _assignGroupsUseCase = assignGroupsUseCase,
       _advanceRoundUseCase = advanceRoundUseCase,
       _undoRoundUseCase = undoRoundUseCase,
       _manageKnockoutUseCase = manageKnockoutUseCase,
       _repository = repository,
       super(
         MacmahonState(id: 'tour_${DateTime.now().millisecondsSinceEpoch}'),
       );

  // ── 데이터 관리 ──────────────────────────────────────────

  Future<void> saveCurrentTournament() async {
    if (state.tournamentName.isEmpty) return;
    await _repository.saveTournament(state);
  }

  void loadState(MacmahonState loadedState) {
    state = loadedState;
    // 로드 직후 재계산 필요 시 수행
    _recomputeStandings();
  }

  // ── 대회 설정 ────────────────────────────────────────────

  void updateTournamentInfo({
    String? name,
    String? date,
    String? location,
    List<String>? sections,
  }) {
    Map<String, SectionData>? newSectionData;
    String? firstSection;

    if (sections != null) {
      newSectionData = {for (var s in sections) s: const SectionData()};
      firstSection = sections.isNotEmpty ? sections.first : '';
    }

    final updatedPlayers = state.players.map((p) {
      if (sections != null && !sections.contains(p.section)) {
        return p.copyWith(section: firstSection ?? '일반부');
      }
      return p;
    }).toList();

    state = state.copyWith(
      tournamentName: name,
      tournamentDate: date,
      tournamentLocation: location,
      sectionData: newSectionData,
      selectedSection: firstSection,
      players: updatedPlayers,
    );
  }

  void selectSection(String sectionName) {
    if (!state.sectionData.containsKey(sectionName)) {
      final newSectionData = Map<String, SectionData>.from(state.sectionData);
      newSectionData[sectionName] = const SectionData();
      state = state.copyWith(
        sectionData: newSectionData,
        selectedSection: sectionName,
      );
    } else {
      state = state.copyWith(selectedSection: sectionName);
    }
  }

  void addSection(String sectionName) {
    if (!state.sectionData.containsKey(sectionName)) {
      final newSectionData = Map<String, SectionData>.from(state.sectionData);
      newSectionData[sectionName] = const SectionData();
      state = state.copyWith(sectionData: newSectionData);
      saveCurrentTournament();
    }
  }

  void removeSection(String sectionName) {
    if (state.sectionData.containsKey(sectionName)) {
      final newSectionData = Map<String, SectionData>.from(state.sectionData);
      newSectionData.remove(sectionName);

      // 해당 부의 선수들도 삭제
      final remainingPlayers = state.players
          .where((p) => p.section != sectionName)
          .toList();

      String? newSelected = state.selectedSection;
      if (newSelected == sectionName) {
        newSelected = newSectionData.keys.isNotEmpty
            ? newSectionData.keys.first
            : null;
      }

      state = state.copyWith(
        sectionData: newSectionData,
        selectedSection: newSelected,
        players: remainingPlayers,
      );
      saveCurrentTournament();
    }
  }

  void updateSectionSettings({
    TournamentFormat? format,
    LeagueType? leagueType,
    int? qualifierCount,
    int? groupCount,
    int? qualifiersPerGroup,
    bool? useHeadToHead,
  }) {
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = state.currentSectionData.copyWith(
      format: format,
      leagueType: leagueType,
      qualifierCount: qualifierCount,
      groupCount: groupCount,
      qualifiersPerGroup: qualifiersPerGroup,
      useHeadToHead: useHeadToHead,
      stage: (format == TournamentFormat.knockout)
          ? 2
          : (format == TournamentFormat.league
                ? 1
                : state.currentSectionData.stage),
    );
    state = state.copyWith(sectionData: newSectionData);
    saveCurrentTournament();
  }

  void updateBracketStyle(BracketStyle style) {
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = state.currentSectionData.copyWith(
      bracketStyle: style,
    );
    state = state.copyWith(sectionData: newSectionData);
    saveCurrentTournament();
  }

  // ── 선수 관리 ────────────────────────────────────────────

  void addPlayer(MacmahonPlayer player) {
    state = state.copyWith(players: [...state.players, player]);
    saveCurrentTournament();
  }

  void updatePlayer(MacmahonPlayer updatedPlayer) {
    state = state.copyWith(
      players: state.players
          .map((p) => p.id == updatedPlayer.id ? updatedPlayer : p)
          .toList(),
    );
    saveCurrentTournament();
  }

  void updatePlayerGroup(String playerId, String? groupId) {
    state = state.copyWith(
      players: state.players
          .map((p) => p.id == playerId ? p.copyWith(groupId: groupId) : p)
          .toList(),
    );
    saveCurrentTournament();
  }

  void removePlayer(String playerId) {
    state = state.copyWith(
      players: state.players.where((p) => p.id != playerId).toList(),
    );
    saveCurrentTournament();
  }

  void addPlayers(List<MacmahonPlayer> players) {
    state = state.copyWith(players: [...state.players, ...players]);
    saveCurrentTournament();
  }

  void addSamplePlayers(int count) {
    final List<MacmahonPlayer> samples = [];
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    for (int i = 1; i <= count; i++) {
      samples.add(
        MacmahonPlayer(
          id: 'sample_${timestamp}_$i',
          name: '선수 $i',
          section: state.selectedSection,
          initialMms: 0.0,
          currentMms: 0.0,
        ),
      );
    }
    addPlayers(samples);
  }

  // ── 비즈니스 로직 (Use Cases) ─────────────────────────────

  Future<void> generatePairing({bool isSequentialForR1 = false}) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    final newState = await _generatePairingUseCase.execute(
      state: state,
      isSequentialForR1: isSequentialForR1,
    );
    state = newState.copyWith(isLoading: false);
    saveCurrentTournament();
  }

  void recordResult({
    required String blackId,
    required String whiteId,
    String? winnerId,
  }) {
    state = _recordResultUseCase.execute(
      state: state,
      playerAId: blackId,
      playerBId: whiteId,
      winnerId: winnerId,
    );
    saveCurrentTournament();
  }

  void autoAssignGroups() {
    state = _assignGroupsUseCase.execute(state);
    saveCurrentTournament();
  }

  void advanceRound() {
    state = _advanceRoundUseCase.execute(state);
    saveCurrentTournament();
  }

  void cancelCurrentPairing() {
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = state.currentSectionData.copyWith(
      clearCurrentPairing: true,
    );
    state = state.copyWith(sectionData: newSectionData);
    saveCurrentTournament();
  }

  void resetCurrentSection() {
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = const SectionData();
    state = state.copyWith(sectionData: newSectionData);
    _recomputeStandings();
    saveCurrentTournament();
  }

  void recordResultByPlayers(
    String playerAId,
    String playerBId,
    String? winnerId,
  ) {
    recordResult(blackId: playerAId, whiteId: playerBId, winnerId: winnerId);
  }

  void startKnockoutStage(List<String> qualifierIds) {
    final currentData = state.currentSectionData;
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      stage: 2,
      currentRound: 1,
      clearCurrentPairing: true,
      knockoutQualifiers: qualifierIds,
    );
    state = state.copyWith(sectionData: newSectionData);
    _recomputeStandings();
    saveCurrentTournament();
  }

  void undoLastRound() {
    state = _undoRoundUseCase.execute(state);
    saveCurrentTournament();
  }

  void toggleTournamentStatus() {
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = state.currentSectionData.copyWith(
      isFinished: !state.currentSectionData.isFinished,
    );
    state = state.copyWith(sectionData: newSectionData);
    saveCurrentTournament();
  }

  void _recomputeStandings() {
    state = _calculateStandingsUseCase.execute(state);
  }

  Future<void> generateManualPairing(
    List<MacmahonPlayer> orderedPlayers,
  ) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      state = _manageKnockoutUseCase.generateManualPairing(
        state: state,
        orderedPlayers: orderedPlayers,
      );
      await saveCurrentTournament();
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '대진 확정 오류: $e');
    }
  }

  Future<void> resetKnockoutStage() async {
    state = _manageKnockoutUseCase.resetKnockoutStage(state);
    await saveCurrentTournament();
  }

  Future<void> startNewTournament() async {
    if (state.tournamentName.isNotEmpty) await saveCurrentTournament();
    state = MacmahonState(id: 'tour_${DateTime.now().millisecondsSinceEpoch}');
  }
}
