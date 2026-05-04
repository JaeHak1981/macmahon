import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/macmahon_pair.dart';
import '../models/macmahon_player.dart';
import '../services/pairing_service.dart';
import '../services/storage_service.dart';
import '../utils/macmahon_utils.dart';

// ─── 대회 방식 및 진행 단계 ────────────────────────────

enum TournamentFormat {
  undecided,         // 미정
  macmahon,          // 맥마흔 (스위스 리그 변형)
  league,            // 풀리그 (Round-robin)
  knockout,          // 토너먼트 (Single Elimination)
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
    this.format = TournamentFormat.undecided,
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
    this.tournamentName = '',
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
    if (playersForSection.isEmpty) return 0;

    // 리그전 또는 리그+토너먼트 예선일 경우
    if (format == TournamentFormat.league ||
        (format == TournamentFormat.leagueAndKnockout && stage == 1)) {
      if (currentSectionData.groupCount > 1) {
        // 조별 인원 기준 (평균)
        int avgPlayersPerGroup =
            (playersForSection.length / currentSectionData.groupCount).ceil();
        return avgPlayersPerGroup % 2 == 0
            ? avgPlayersPerGroup - 1
            : avgPlayersPerGroup;
      }
      return playersForSection.length % 2 == 0
          ? playersForSection.length - 1
          : playersForSection.length;
    }

    // 맥마흔 또는 토너먼트일 경우
    final topBarCount = playersForSection.where((p) => p.isTopBar).length;
    return MacmahonUtils.calculateRecommendedRounds(
      playersForSection.length,
      topBarCount: topBarCount > 0 ? topBarCount : null,
    );
  }
  List<String> get availableGroups {
    final count = currentSectionData.groupCount;
    if (count <= 1) return [];
    return List.generate(count, (i) => String.fromCharCode(65 + i));
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
      tournamentName: json['tournamentName'] as String? ?? '',
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


  void updateTournamentInfo({
    String? name,
    String? date,
    String? location,
    List<String>? sections,
  }) {
    Map<String, SectionData>? newSectionData;
    String? firstSection;
    
    if (sections != null) {
      newSectionData = {
        for (var s in sections) s: const SectionData(),
      };
      firstSection = sections.isNotEmpty ? sections.first : '';
    }

    // 부 이름이 변경되었을 경우, 기존 선수들의 부 정보도 함께 업데이트하거나 
    // 유효하지 않은 부에 속한 선수들을 첫 번째 부로 이동시킴
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

  void removeSection(String sectionName) {
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData.remove(sectionName);

    // 삭제되는 부의 선수들 제거
    final updatedPlayers = state.players.where((p) => p.section != sectionName).toList();

    String nextSelected = '';
    if (newSectionData.isNotEmpty) {
      if (state.selectedSection == sectionName) {
        nextSelected = newSectionData.keys.first;
      } else {
        nextSelected = state.selectedSection;
      }
    }

    state = state.copyWith(
      sectionData: newSectionData,
      selectedSection: nextSelected,
      players: updatedPlayers,
    );
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

  void autoAssignGroups() {
    final currentData = state.currentSectionData;
    if (currentData.groupCount <= 1) return;
    
    final players = state.currentSectionPlayers;
    final assigned = _assignGroups(players, currentData.groupCount);
    _updatePlayersInState(assigned);
    saveCurrentTournament();
  }

  void updatePlayerGroup(String playerId, String? groupId) {
    state = state.copyWith(
      players: state.players.map((p) => p.id == playerId ? p.copyWith(groupId: groupId) : p).toList(),
    );
    saveCurrentTournament();
  }

  void clearGroups() {
    final currentSection = state.selectedSection;
    state = state.copyWith(
      players: state.players.map((p) => p.section == currentSection ? p.copyWith(groupId: null) : p).toList(),
    );
    saveCurrentTournament();
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
        id: 'sample_${i}_${now}_$currentSection',
        name: name,
        section: currentSection,
        initialMms: 0,
        currentMms: 0,
        isTopBar: i < (count ~/ 4).clamp(1, 8),
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

      if (format == TournamentFormat.undecided) {
        state = state.copyWith(isLoading: false, errorMessage: '대회 방식을 먼저 설정해 주세요 (도구 메뉴의 대회 방식 설정).');
        return;
      }

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
          result = _pairingService.generateGroupLeaguePairing(
              players: players, round: currentRound);
        } else {
          result = _pairingService.generateAllLeagueMatches(players: players);
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
          result = PairingResult(pairs: pairs, round: 1, byePlayers: bye != null ? [bye] : []);
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
      if ((p.black.id == blackId && p.white.id == whiteId) || (p.black.id == whiteId && p.white.id == blackId)) {
        return p.copyWith(winnerId: winnerId, isResultEntered: true);
      }
      return p;
    }).toList();
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = state.currentSectionData.copyWith(
      currentPairing: state.currentPairing!.copyWith(pairs: updatedPairs),
    );
    state = state.copyWith(sectionData: newSectionData);
    _recomputeStandings();
  }

  void _recomputeStandings() {
    final currentData = state.currentSectionData;
    // 히스토리와 현재 진행 중인 페어링을 모두 합쳐서 계산
    final List<PairingResult> allResults = [...currentData.history];
    if (currentData.currentPairing != null) {
      allResults.add(currentData.currentPairing!);
    }

    final replayedPlayers = _calculatePlayersFromHistory(allResults, state.currentSectionPlayers);
    _updatePlayersInState(replayedPlayers);
    computeTieBreakers();
    saveCurrentTournament();
  }

  void recordResultByPlayers(String playerAId, String playerBId, String? winnerId) {
    if (state.currentPairing == null) return;
    recordResult(blackId: playerAId, whiteId: playerBId, winnerId: winnerId);
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
    final newHistory =
        currentData.history.sublist(0, currentData.history.length - 1);
    final replayedPlayers =
        _calculatePlayersFromHistory(newHistory, state.currentSectionPlayers);
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

  void cancelCurrentPairing() {
    final currentSection = state.selectedSection;
    final currentData = state.currentSectionData;
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[currentSection] = currentData.copyWith(currentPairing: null);
    state = state.copyWith(sectionData: newSectionData);
    saveCurrentTournament();
  }

  void resetCurrentSection() {
    final currentSection = state.selectedSection;
    final currentData = state.currentSectionData;

    // 선수들의 경기 기록 초기화 (MMS는 유지)
    final resetPlayers = state.currentSectionPlayers
        .map((p) => p.copyWith(
              currentMms: p.initialMms,
              wins: 0,
              losses: 0,
              draws: 0,
              opponents: {},
              defeatedOpponents: {},
              floatHistory: [],
              cumulativeScore: 0.0,
              sos: 0.0,
              sodos: 0.0,
            ))
        .toList();

    _updatePlayersInState(resetPlayers);

    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[currentSection] = currentData.copyWith(
      history: [],
      currentRound: 1,
      currentPairing: null,
      isFinished: false,
    );

    state = state.copyWith(sectionData: newSectionData);
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
      for (final byePlayer in roundResult.byePlayers) {
        final bye = players.firstWhere((p) => p.id == byePlayer.id);
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

  List<MacmahonPlayer> _getKnockoutSurvivors(
      List<MacmahonPlayer> players, List<PairingResult> history) {
    final currentData = state.currentSectionData;

    // 리그+토너먼트에서 토너먼트 스테이지의 첫 라운드인 경우
    // 히스토리(예선 기록)에 상관없이 현재 순위 상위 N명을 본선 진출자로 선발
    if (currentData.format == TournamentFormat.leagueAndKnockout &&
        currentData.stage == 2 &&
        currentData.currentRound == 1) {
      final sorted = List<MacmahonPlayer>.from(players)
        ..sort((a, b) => comparePlayers(b, a, currentData.format));
      return sorted.take(currentData.qualifierCount).toList();
    }

    // 일반적인 토너먼트 진행: 이전 라운드 승자만 추출
    // (예선-본선 전환이 아닌 토너먼트 내의 라운드 진행 시)
    if (history.isEmpty) return players;

    // 현재 스테이지 내에서의 이전 라운드 결과만 확인해야 함
    // 하지만 현재 history는 모든 스테이지가 합쳐져 있으므로, 
    // 토너먼트 시작 이후의 기록만 필터링하거나 마지막 기록을 신중히 사용해야 함.
    final lastRound = history.last;
    final winners = <MacmahonPlayer>[];
    for (final pair in lastRound.pairs) {
      if (pair.winnerId != null) {
        winners.add(players.firstWhere((p) => p.id == pair.winnerId));
      }
    }
    for (final bye in lastRound.byePlayers) {
      winners.add(players.firstWhere((p) => p.id == bye.id));
    }
    return winners;
  }

  List<MacmahonPlayer> _assignGroups(List<MacmahonPlayer> players, int groupCount) {
    if (groupCount <= 1) return players;
    
    final updated = List<MacmahonPlayer>.from(players);
    final unassigned = updated.where((p) => p.groupId == null || p.groupId!.isEmpty).toList()..shuffle();
    
    // 현재 조별 인원수 계산
    final groupCounts = <String, int>{};
    for (int i = 0; i < groupCount; i++) {
      groupCounts[String.fromCharCode(65 + i)] = 0;
    }
    
    for (final p in players) {
      if (p.groupId != null && p.groupId!.isNotEmpty && groupCounts.containsKey(p.groupId)) {
        groupCounts[p.groupId!] = groupCounts[p.groupId!]! + 1;
      }
    }
    
    // 미지정 선수를 인원수가 가장 적은 조에 순차적으로 배정
    for (final p in unassigned) {
      String minGroup = groupCounts.keys.first;
      int minCount = groupCounts[minGroup]!;
      for (final g in groupCounts.keys) {
        if (groupCounts[g]! < minCount) {
          minGroup = g;
          minCount = groupCounts[g]!;
        }
      }
      
      final idx = updated.indexWhere((up) => up.id == p.id);
      if (idx != -1) {
        updated[idx] = updated[idx].copyWith(groupId: minGroup);
      }
      
      groupCounts[minGroup] = groupCounts[minGroup]! + 1;
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
    sectionPlayers.sort((a, b) => comparePlayers(b, a, currentData.format)); // 내림차순 정렬

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

  int comparePlayers(MacmahonPlayer a, MacmahonPlayer b, TournamentFormat format) {
    // 1. MMS (대국 점수 / 승수)
    final mmsCmp = a.currentMms.compareTo(b.currentMms);
    if (mmsCmp != 0) return mmsCmp;

    // 2. 승자승 (Direct Encounter)
    if (a.defeatedOpponents.contains(b.id)) return 1;
    if (b.defeatedOpponents.contains(a.id)) return -1;

    // 3. SODOS (이긴 상대의 MMS 합 / Sonnenborn-Berger)
    final sodosCmp = a.sodos.compareTo(b.sodos);
    if (sodosCmp != 0) return sodosCmp;

    final isLeague = format == TournamentFormat.league || format == TournamentFormat.leagueAndKnockout;

    // 스위스 리그(맥마흔) 방식일 때만 SOS 및 누진점수 적용
    if (!isLeague) {
      // 4. SOS (상대 MMS 합)
      final sosCmp = a.sos.compareTo(b.sos);
      if (sosCmp != 0) return sosCmp;

      // 5. 누진점수 (Cumulative Score)
      final cumCmp = a.cumulativeScore.compareTo(b.cumulativeScore);
      if (cumCmp != 0) return cumCmp;
    }

    // 6. 초기 MMS (등급 순)
    final initCmp = a.initialMms.compareTo(b.initialMms);
    if (initCmp != 0) return initCmp;

    // 7. 총 승수
    return a.wins.compareTo(b.wins);
  }

  Future<void> saveCurrentTournament() async {
    if (state.tournamentName.isEmpty) return;
    await _storageService.saveTournament(state);
  }

  Future<void> startNewTournament() async {
    // 대회명이 있을 때만 기존 대회 저장 (선수 유무와 관계없이)
    if (state.tournamentName.isNotEmpty) {
      await saveCurrentTournament();
    }
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
