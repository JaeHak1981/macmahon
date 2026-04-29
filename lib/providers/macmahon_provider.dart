import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/macmahon_pair.dart';
import '../models/macmahon_player.dart';
import '../services/pairing_service.dart';
import '../services/storage_service.dart';
import '../utils/macmahon_utils.dart';

// ─── 대회 방식 및 진행 단계 ────────────────────────────

enum TournamentFormat {
  macmahon, // 맥마흔 (스위스 리그 변형)
  league,   // 풀리그 (Round-robin)
  knockout,  // 토너먼트 (Single Elimination)
  doubleElimination, // 더블 일리미네이션
  leagueAndKnockout, // 풀리그 + 토너먼트
}

enum LeagueType {
  normal,            // 일반 풀리그
  doubleElimination, // 더블 일리미네이션
}

// ─── 부(Section)별 상태 클래스 ──────────────────────────────

class SectionData {
  final List<PairingResult> history;
  final PairingResult? currentPairing;
  final int currentRound;
  final bool isFinished;
  final TournamentFormat format;
  final LeagueType leagueType;
  final int stage; // 1: 예선, 2: 본선
  final int qualifierCount;
  final int groupCount;

  const SectionData({
    this.history = const [],
    this.currentPairing,
    this.currentRound = 1,
    this.isFinished = false,
    this.format = TournamentFormat.macmahon,
    this.leagueType = LeagueType.normal,
    this.stage = 1,
    this.qualifierCount = 4,
    this.groupCount = 1,
  });

  SectionData copyWith({
    List<PairingResult>? history,
    dynamic currentPairing = _sentinel,
    int? currentRound,
    bool? isFinished,
    TournamentFormat? format,
    LeagueType? leagueType,
    int? stage,
    int? qualifierCount,
    int? groupCount,
  }) {
    return SectionData(
      history: history ?? this.history,
      currentPairing: currentPairing == _sentinel ? this.currentPairing : currentPairing as PairingResult?,
      currentRound: currentRound ?? this.currentRound,
      isFinished: isFinished ?? this.isFinished,
      format: format ?? this.format,
      leagueType: leagueType ?? this.leagueType,
      stage: stage ?? this.stage,
      qualifierCount: qualifierCount ?? this.qualifierCount,
      groupCount: groupCount ?? this.groupCount,
    );
  }

  static const _sentinel = Object();

  Map<String, dynamic> toJson() => {
    'history': history.map((h) => h.toJson()).toList(),
    'currentPairing': currentPairing?.toJson(),
    'currentRound': currentRound,
    'isFinished': isFinished,
    'format': format.index,
    'leagueType': leagueType.index,
    'stage': stage,
    'qualifierCount': qualifierCount,
    'groupCount': groupCount,
  };

  factory SectionData.fromJson(Map<String, dynamic> json, List<MacmahonPlayer> allPlayers) {
    return SectionData(
      history: (json['history'] as List? ?? []).map((h) => PairingResult.fromJson(h, allPlayers)).toList(),
      currentPairing: json['currentPairing'] != null ? PairingResult.fromJson(json['currentPairing'], allPlayers) : null,
      currentRound: (json['currentRound'] as num?)?.toInt() ?? 1,
      isFinished: json['isFinished'] as bool? ?? false,
      format: TournamentFormat.values[(json['format'] as num?)?.toInt() ?? 0],
      leagueType: LeagueType.values[(json['leagueType'] as num?)?.toInt() ?? 0],
      stage: (json['stage'] as num?)?.toInt() ?? 1,
      qualifierCount: (json['qualifierCount'] as num?)?.toInt() ?? 4,
      groupCount: (json['groupCount'] as num?)?.toInt() ?? 1,
    );
  }
}

// ─── 전체 상태 클래스 ──────────────────────────────────────

class MacmahonState {
  final String id;
  final List<MacmahonPlayer> players;
  final Map<String, SectionData> sectionData; // 부별 데이터
  final String selectedSection; // 현재 선택된 부
  final String tournamentName;
  final String tournamentDate;
  final String tournamentLocation;
  final bool isLoading;
  final String? errorMessage;

  const MacmahonState({
    required this.id,
    this.players = const [],
    this.sectionData = const {'일반부': SectionData()},
    this.selectedSection = '일반부',
    this.tournamentName = '새 대회',
    this.tournamentDate = '',
    this.tournamentLocation = '',
    this.isLoading = false,
    this.errorMessage,
  });

  SectionData get currentSectionData => sectionData[selectedSection] ?? const SectionData();
  List<MacmahonPlayer> get currentSectionPlayers => players.where((p) => p.section == selectedSection).toList();
  TournamentFormat get format => currentSectionData.format;
  int get currentRound => currentSectionData.currentRound;
  List<PairingResult> get history => currentSectionData.history;
  PairingResult? get currentPairing => currentSectionData.currentPairing;
  List<MacmahonPair> get currentPairs => currentPairing?.pairs ?? [];
  MacmahonPlayer? get byePlayer => currentPairing?.byePlayer;
  int get stage => currentSectionData.stage;
  List<String> get sections => sectionData.keys.toList();
  int get recommendedRounds {
    final playersForSection = currentSectionPlayers;
    final topBarCount = playersForSection.where((p) => p.isTopBar).length;
    return MacmahonUtils.calculateRecommendedRounds(
      playersForSection.length,
      topBarCount: topBarCount > 0 ? topBarCount : null,
    );
  }
  bool get isFinished => currentSectionData.isFinished;

  MacmahonState copyWith({
    String? id,
    List<MacmahonPlayer>? players,
    Map<String, SectionData>? sectionData,
    String? selectedSection,
    String? tournamentName,
    String? tournamentDate,
    String? tournamentLocation,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MacmahonState(
      id: id ?? this.id,
      players: players ?? this.players,
      sectionData: sectionData ?? this.sectionData,
      selectedSection: selectedSection ?? this.selectedSection,
      tournamentName: tournamentName ?? this.tournamentName,
      tournamentDate: tournamentDate ?? this.tournamentDate,
      tournamentLocation: tournamentLocation ?? this.tournamentLocation,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'players': players.map((p) => p.toJson()).toList(),
    'sectionData': sectionData.map((k, v) => MapEntry(k, v.toJson())),
    'selectedSection': selectedSection,
    'tournamentName': tournamentName,
    'tournamentDate': tournamentDate,
    'tournamentLocation': tournamentLocation,
  };

  factory MacmahonState.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List).map((p) => MacmahonPlayer.fromJson(p)).toList();
    final sectionData = (json['sectionData'] as Map<String, dynamic>? ?? {}).map(
      (k, v) => MapEntry(k, SectionData.fromJson(v as Map<String, dynamic>, players)),
    );
    return MacmahonState(
      id: json['id'] as String,
      players: players,
      sectionData: sectionData,
      selectedSection: json['selectedSection'] as String? ?? '일반부',
      tournamentName: json['tournamentName'] as String? ?? '새 대회',
      tournamentDate: json['tournamentDate'] as String? ?? '',
      tournamentLocation: json['tournamentLocation'] as String? ?? '',
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────

class MacmahonNotifier extends StateNotifier<MacmahonState> {
  final PairingService _pairingService = PairingService();
  final StorageService _storageService = StorageService();

  MacmahonNotifier() : super(MacmahonState(id: 'tour_${DateTime.now().millisecondsSinceEpoch}'));

  void loadState(MacmahonState loadedState) => state = loadedState;

  Future<void> saveCurrentTournament() async => await _storageService.saveTournament(state);

  void updateTournamentInfo({
    String? name,
    String? date,
    String? location,
    List<String>? sections,
  }) {
    Map<String, SectionData>? newSectionData;
    String? firstSection;
    
    if (sections != null && sections.isNotEmpty) {
      newSectionData = {
        for (var s in sections) s: const SectionData(),
      };
      firstSection = sections.first;
    }

    state = state.copyWith(
      tournamentName: name,
      tournamentDate: date,
      tournamentLocation: location,
      sectionData: newSectionData,
      selectedSection: firstSection,
    );
  }

  void selectSection(String sectionName) {
    if (!state.sectionData.containsKey(sectionName)) {
      final newSectionData = Map<String, SectionData>.from(state.sectionData);
      newSectionData[sectionName] = const SectionData();
      state = state.copyWith(sectionData: newSectionData, selectedSection: sectionName);
    } else {
      state = state.copyWith(selectedSection: sectionName);
    }
  }

  void addSection(String sectionName) {
    if (sectionName.isEmpty) return;
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[sectionName] = const SectionData();
    state = state.copyWith(sectionData: newSectionData, selectedSection: sectionName);
    saveCurrentTournament();
  }

  void updateSectionSettings({TournamentFormat? format, LeagueType? leagueType, int? qualifierCount, int? groupCount}) {
    final currentSection = state.selectedSection;
    final currentData = state.currentSectionData;
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[currentSection] = currentData.copyWith(
      format: format,
      leagueType: leagueType,
      qualifierCount: qualifierCount,
      groupCount: groupCount,
    );
    state = state.copyWith(sectionData: newSectionData);
    saveCurrentTournament();
  }

  void addPlayer(MacmahonPlayer player) {
    state = state.copyWith(players: [...state.players, player]);
  }

  void addPlayers(List<MacmahonPlayer> newPlayers) {
    state = state.copyWith(players: [...state.players, ...newPlayers]);
  }

  void addSamplePlayers(int count) {
    if (count <= 0) return;

    final List<String> baseNames = [
      '신진서', '박정환', '변상일', '신민준', '김명훈', '강동윤', '원성진', '김지석',
      '최정', '조한승', '안국현', '이지현', '한승주', '설현준', '최철한', '강승민'
    ];
    
    final List<MacmahonPlayer> samples = [];
    final currentSection = state.selectedSection;
    final now = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < count; i++) {
      String name = (i < baseNames.length) ? baseNames[i] : '선수 ${i + 1}';
      
      samples.add(MacmahonPlayer(
        id: 'sample_${i}_$now',
        name: name,
        section: currentSection,
        initialMms: 0,
        currentMms: 0,
        isTopBar: i < (count ~/ 4).clamp(1, 8), // 약 25%를 Top Bar로 설정 (최대 8명)
      ));
    }
    addPlayers(samples);
    saveCurrentTournament();
  }

  void updatePlayer(MacmahonPlayer updatedPlayer) {
    state = state.copyWith(
      players: state.players.map((p) => p.id == updatedPlayer.id ? updatedPlayer : p).toList(),
    );
  }

  void removePlayer(String playerId) {
    state = state.copyWith(players: state.players.where((p) => p.id != playerId).toList());
  }

  void updatePlayerName(String playerId, String newName) {
    if (newName.trim().isEmpty) return;
    state = state.copyWith(
      players: state.players.map((p) => p.id == playerId ? p.copyWith(name: newName.trim()) : p).toList(),
    );
  }

  Future<void> generatePairing({bool isSequentialForR1 = false}) async {
    final sectionPlayers = state.currentSectionPlayers;
    if (sectionPlayers.isEmpty) {
      state = state.copyWith(errorMessage: '선수가 없습니다.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      PairingResult result;
      final currentRound = state.currentRound;
      final format = state.format;
      final currentData = state.currentSectionData;

      if (format == TournamentFormat.league || (format == TournamentFormat.leagueAndKnockout && currentData.stage == 1)) {
        List<MacmahonPlayer> players = sectionPlayers;
        // 조 배정 로직 (1라운드 시작 시)
        if (currentRound == 1 && currentData.groupCount > 1) {
          if (players.every((p) => p.groupId == null)) {
            players = _assignGroups(players, currentData.groupCount);
            _updatePlayersInState(players);
          }
        }

        if (currentData.groupCount > 1) {
          result = _pairingService.generateGroupLeaguePairing(players: players, round: currentRound);
        } else {
          result = _pairingService.generateLeaguePairing(players: players, round: currentRound);
        }
      } else if (format == TournamentFormat.knockout || (format == TournamentFormat.leagueAndKnockout && currentData.stage == 2)) {
        final survivors = _getKnockoutSurvivors(sectionPlayers, currentData.history);
        result = _pairingService.generateKnockoutPairing(players: survivors, round: currentRound);
      } else {
        if (currentRound == 1 && isSequentialForR1) {
          final workingList = List<MacmahonPlayer>.from(sectionPlayers);
          final pairs = <MacmahonPair>[];
          MacmahonPlayer? bye;
          if (workingList.length % 2 != 0) bye = workingList.removeLast();
          for (int i = 0; i < workingList.length; i += 2) {
            pairs.add(MacmahonPair(black: workingList[i], white: workingList[i + 1], cost: 0));
          }
          result = PairingResult(pairs: pairs, round: 1, byePlayer: bye);
        } else {
          result = await Future(() => _pairingService.generatePairing(players: sectionPlayers, round: currentRound));
        }
      }

      _pairingService.applyPairingResult(result);
      final newSectionData = Map<String, SectionData>.from(state.sectionData);
      newSectionData[state.selectedSection] = currentData.copyWith(currentPairing: result);
      state = state.copyWith(sectionData: newSectionData, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '페어링 오류: $e');
    }
  }

  void recordResult({required String blackId, required String whiteId, String? winnerId}) {
    if (state.currentPairing == null) return;
    final updatedPairs = state.currentPairing!.pairs.map((p) {
      if (p.black.id == blackId && p.white.id == whiteId) return p.copyWith(winnerId: winnerId, isResultEntered: true);
      return p;
    }).toList();
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = state.currentSectionData.copyWith(
      currentPairing: state.currentPairing!.copyWith(pairs: updatedPairs),
    );
    state = state.copyWith(sectionData: newSectionData);
  }

  void advanceRound() {
    if (state.currentPairing == null) return;
    final currentData = state.currentSectionData;
    final updatedHistory = [...currentData.history, currentData.currentPairing!];
    final replayedPlayers = _calculatePlayersFromHistory(updatedHistory, state.currentSectionPlayers);
    _updatePlayersInState(replayedPlayers);
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      history: updatedHistory,
      currentRound: updatedHistory.length + 1,
      currentPairing: null,
    );
    state = state.copyWith(sectionData: newSectionData);
    computeTieBreakers();
    saveCurrentTournament();
  }

  void undoLastRound() {
    final currentData = state.currentSectionData;
    if (currentData.history.isEmpty) return;
    final restoredPairing = currentData.history.last;
    final newHistory = currentData.history.sublist(0, currentData.history.length - 1);
    final replayedPlayers = _calculatePlayersFromHistory(newHistory, state.currentSectionPlayers);
    _updatePlayersInState(replayedPlayers);
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      history: newHistory,
      currentRound: newHistory.length + 1,
      currentPairing: restoredPairing,
    );
    state = state.copyWith(sectionData: newSectionData);
    computeTieBreakers();
    saveCurrentTournament();
  }

  List<MacmahonPlayer> _calculatePlayersFromHistory(List<PairingResult> history, List<MacmahonPlayer> sectionPlayers) {
    final players = sectionPlayers.map((p) => p.copyWith(
      currentMms: p.initialMms, wins: 0, losses: 0, draws: 0, opponents: {}, defeatedOpponents: {}, floatHistory: [], cumulativeScore: 0.0,
    )).toList();

    for (final roundResult in history) {
      for (final pair in roundResult.pairs) {
        final b = players.firstWhere((p) => p.id == pair.black.id);
        final w = players.firstWhere((p) => p.id == pair.white.id);
        b.addOpponent(w.id); w.addOpponent(b.id);
        b.floatHistory.add(pair.blackFloatResult); w.floatHistory.add(pair.whiteFloatResult);
        if (pair.winnerId == b.id) { b.wins++; b.currentMms += 1.0; b.defeatedOpponents.add(w.id); w.losses++; }
        else if (pair.winnerId == w.id) { w.wins++; w.currentMms += 1.0; w.defeatedOpponents.add(b.id); b.losses++; }
        else if (pair.isResultEntered) { b.draws++; b.currentMms += 0.5; w.draws++; w.currentMms += 0.5; }
      }
      if (roundResult.byePlayer != null) {
        final bye = players.firstWhere((p) => p.id == roundResult.byePlayer!.id);
        bye.currentMms += 1.0; bye.wins++; bye.floatHistory.add(0);
      }
      for (final p in players) p.updateCumulativeScore();
    }
    return players;
  }

  void computeTieBreakers() {
    final players = state.players;
    final updatedPlayers = players.map((p) {
      if (p.section != state.selectedSection) return p;
      double sos = 0;
      for (final oId in p.opponents) {
        final o = players.firstWhere((other) => other.id == oId, orElse: () => p);
        if (o.id != p.id) sos += o.currentMms;
      }
      double sodos = 0;
      for (final dId in p.defeatedOpponents) {
        final o = players.firstWhere((other) => other.id == dId, orElse: () => p);
        if (o.id != p.id) sodos += o.currentMms;
      }
      return p.copyWith(sos: sos, sodos: sodos);
    }).toList();
    state = state.copyWith(players: updatedPlayers);
  }

  List<MacmahonPlayer> _getKnockoutSurvivors(List<MacmahonPlayer> players, List<PairingResult> history) {
    if (history.isEmpty) return players;
    final lastRound = history.last;
    final winners = <MacmahonPlayer>[];
    for (final pair in lastRound.pairs) {
      if (pair.winnerId != null) winners.add(players.firstWhere((p) => p.id == pair.winnerId));
    }
    if (lastRound.byePlayer != null) winners.add(players.firstWhere((p) => p.id == lastRound.byePlayer!.id));
    return winners;
  }

  List<MacmahonPlayer> _assignGroups(List<MacmahonPlayer> players, int groupCount) {
    if (groupCount <= 1) return players;
    final sorted = List<MacmahonPlayer>.from(players)..shuffle();
    final updated = <MacmahonPlayer>[];
    for (int i = 0; i < sorted.length; i++) {
      final label = String.fromCharCode(65 + (i % groupCount));
      updated.add(sorted[i].copyWith(groupId: label));
    }
    return updated;
  }

  void _updatePlayersInState(List<MacmahonPlayer> updatedSectionPlayers) {
    final all = List<MacmahonPlayer>.from(state.players);
    for (final u in updatedSectionPlayers) {
      final idx = all.indexWhere((p) => p.id == u.id);
      if (idx != -1) all[idx] = u;
    }
    state = state.copyWith(players: all);
  }

  void startKnockoutStage() {
    final currentData = state.currentSectionData;
    if (currentData.stage != 1) return;

    // 현재 순위 기준으로 상위 N명 선발
    final sectionPlayers = List<MacmahonPlayer>.from(state.currentSectionPlayers);
    sectionPlayers.sort((a, b) => _comparePlayers(b, a)); // 내림차순 정렬

    final qualifiers = sectionPlayers.take(currentData.qualifierCount).toList();

    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      stage: 2,
      currentRound: 1, // 토너먼트 1라운드부터 시작
      currentPairing: null,
    );

    state = state.copyWith(sectionData: newSectionData);
    saveCurrentTournament();
  }

  int _comparePlayers(MacmahonPlayer a, MacmahonPlayer b) {
    if (a.currentMms != b.currentMms) return a.currentMms.compareTo(b.currentMms);
    if (a.sos != b.sos) return a.sos.compareTo(b.sos);
    if (a.sodos != b.sodos) return a.sodos.compareTo(b.sodos);
    return a.cumulativeScore.compareTo(b.cumulativeScore);
  }

  Future<void> startNewTournament() async {
    if (state.players.isNotEmpty || state.tournamentName != '새 대회') await saveCurrentTournament();
    state = MacmahonState(id: 'tour_${DateTime.now().millisecondsSinceEpoch}');
  }

  Future<void> toggleTournamentStatus() async {
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = state.currentSectionData.copyWith(isFinished: !state.isFinished);
    state = state.copyWith(sectionData: newSectionData);
    await saveCurrentTournament();
  }
}

final macmahonProvider = StateNotifierProvider<MacmahonNotifier, MacmahonState>((ref) => MacmahonNotifier());
