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
  final int qualifiersPerGroup; // 각 조별 본선 진출 인원 (새로 추가)
  final List<String> knockoutQualifiers; // 수동으로 선택된 본선 진출자 ID 목록
  final bool useHeadToHead; // 동률 시 승자승 적용 여부

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
    this.qualifiersPerGroup = 1, // 기본값: 조 1위만 진출
    this.knockoutQualifiers = const [],
    this.useHeadToHead = true,
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
    int? qualifiersPerGroup,
    List<String>? knockoutQualifiers,
    bool? useHeadToHead,
  }) {
    return SectionData(
      history: history ?? this.history,
      currentPairing: currentPairing == _sentinel
          ? this.currentPairing
          : currentPairing as PairingResult?,
      currentRound: currentRound ?? this.currentRound,
      isFinished: isFinished ?? this.isFinished,
      format: format ?? this.format,
      leagueType: leagueType ?? this.leagueType,
      stage: stage ?? this.stage,
      qualifierCount: qualifierCount ?? this.qualifierCount,
      groupCount: groupCount ?? this.groupCount,
      qualifiersPerGroup: qualifiersPerGroup ?? this.qualifiersPerGroup,
      knockoutQualifiers: knockoutQualifiers ?? this.knockoutQualifiers,
      useHeadToHead: useHeadToHead ?? this.useHeadToHead,
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
        'qualifiersPerGroup': qualifiersPerGroup,
        'knockoutQualifiers': knockoutQualifiers,
        'useHeadToHead': useHeadToHead,
      };

  factory SectionData.fromJson(
      Map<String, dynamic> json, List<MacmahonPlayer> allPlayers) {
    return SectionData(
      history: (json['history'] as List? ?? [])
          .map((h) => PairingResult.fromJson(h, allPlayers))
          .toList(),
      currentPairing: json['currentPairing'] != null
          ? PairingResult.fromJson(json['currentPairing'], allPlayers)
          : null,
      currentRound: (json['currentRound'] as num?)?.toInt() ?? 1,
      isFinished: json['isFinished'] as bool? ?? false,
      format: TournamentFormat.values[(json['format'] as num?)?.toInt() ?? 0],
      leagueType: LeagueType.values[(json['leagueType'] as num?)?.toInt() ?? 0],
      stage: (json['stage'] as num?)?.toInt() ?? 1,
      qualifierCount: (json['qualifierCount'] as num?)?.toInt() ?? 4,
      groupCount: (json['groupCount'] as num?)?.toInt() ?? 1,
      qualifiersPerGroup: (json['qualifiersPerGroup'] as num?)?.toInt() ?? 1,
      knockoutQualifiers: (json['knockoutQualifiers'] is List)
          ? List<String>.from(json['knockoutQualifiers'])
          : const [],
      useHeadToHead:
          (json['useHeadToHead'] is bool) ? json['useHeadToHead'] as bool : true,
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
    this.sectionData = const {'일반부': const SectionData()},
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

  void loadState(MacmahonState loadedState) {
    state = loadedState;
    // 로드 직후, 리그전 부(部)가 있으면 저장된 오염된 승점을 즉시 재계산하여 정확한 값으로 교정
    for (final section in loadedState.sectionData.keys) {
      final sd = loadedState.sectionData[section]!;
      final isLeague = sd.format == TournamentFormat.league ||
          (sd.format == TournamentFormat.leagueAndKnockout && sd.stage == 1);
      if (!isLeague) continue;
      // 부(部)를 현재 선택으로 전환 후 재계산, 그 후 원래 선택으로 복귀
      final original = state.selectedSection;
      state = state.copyWith(selectedSection: section);
      _recomputeStandings();
      state = state.copyWith(selectedSection: original);
    }
  }


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

  void updateSectionSettings({
    TournamentFormat? format,
    LeagueType? leagueType,
    int? qualifierCount,
    int? groupCount,
    int? qualifiersPerGroup,
    bool? useHeadToHead,
  }) {
    final currentSection = state.selectedSection;
    final currentData = state.currentSectionData;
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[currentSection] = currentData.copyWith(
      format: format,
      leagueType: leagueType,
      qualifierCount: qualifierCount,
      groupCount: groupCount,
      qualifiersPerGroup: qualifiersPerGroup,
      useHeadToHead: useHeadToHead,
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

  /// 수동으로 정렬된 리스트를 바탕으로 대진을 확정합니다.
  Future<void> generateManualPairing(List<MacmahonPlayer> orderedPlayers) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final currentRound = state.currentRound;
      final currentData = state.currentSectionData;

      final result = _pairingService.generateKnockoutPairingManual(
        orderedPlayers: orderedPlayers,
        round: currentRound,
      );

      _pairingService.applyPairingResult(result);
      final newSectionData = Map<String, SectionData>.from(state.sectionData);
      newSectionData[state.selectedSection] =
          currentData.copyWith(currentPairing: result);
      state = state.copyWith(sectionData: newSectionData, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, errorMessage: '수동 페어링 오류: $e');
    }
  }

  void recordResult(
      {required String blackId, required String whiteId, String? winnerId}) {
    if (state.currentPairing == null) return;

    final updatedPairs = state.currentPairing!.pairs.map((p) {
      if ((p.black.id == blackId && p.white.id == whiteId) ||
          (p.black.id == whiteId && p.white.id == blackId)) {
        return p.setResult(winnerId);
      }
      return p;
    }).toList();

    final newCurrentPairing =
        state.currentPairing!.copyWith(pairs: updatedPairs);
    final currentData = state.currentSectionData;

    // 일괄 계산 준비
    final isLeague = state.format == TournamentFormat.league ||
        (state.format == TournamentFormat.leagueAndKnockout &&
            state.stage == 1);

    List<MacmahonPlayer> updatedSectionPlayers;
    if (isLeague) {
      final allPairs = [...currentData.history.expand((h) => h.pairs)];
      allPairs.addAll(newCurrentPairing.pairs);
      updatedSectionPlayers = _calculateLeagueStandings(allPairs);
    } else {
      final allResults = [...currentData.history, newCurrentPairing];
      final replayed =
          _calculatePlayersFromHistory(allResults, state.currentSectionPlayers);
      updatedSectionPlayers = _calculateTieBreakers(replayed, state.players);
    }

    // 상태 일괄 업데이트 (Map 사용하여 O(N) 처리)
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      currentPairing: newCurrentPairing,
    );

    final playerMap = {for (final p in updatedSectionPlayers) p.id: p};
    final allPlayers =
        state.players.map((p) => playerMap[p.id] ?? p).toList();

    state = state.copyWith(
      sectionData: newSectionData,
      players: allPlayers,
    );

    saveCurrentTournament();
  }

  void recordResultByPlayers(String playerAId, String playerBId, String? winnerId) {
    final currentData = state.currentSectionData;
    bool anyUpdated = false;

    // 1. 현재 대진 및 히스토리 업데이트 (로컬 변수로 관리)
    PairingResult? newCurrentPairing = currentData.currentPairing;
    if (currentData.currentPairing != null) {
      final newPairs = <MacmahonPair>[];
      bool found = false;
      for (final p in currentData.currentPairing!.pairs) {
        if (!found &&
            ((p.black.id == playerAId && p.white.id == playerBId) ||
                (p.black.id == playerBId && p.white.id == playerAId))) {
          newPairs.add(p.setResult(winnerId));
          found = true;
          anyUpdated = true;
        } else {
          newPairs.add(p);
        }
      }
      if (found) {
        newCurrentPairing =
            currentData.currentPairing!.copyWith(pairs: newPairs);
      }
    }

    final newHistory = <PairingResult>[];
    for (final round in currentData.history) {
      bool foundInRound = false;
      final newPairs = <MacmahonPair>[];
      for (final p in round.pairs) {
        if (!foundInRound &&
            ((p.black.id == playerAId && p.white.id == playerBId) ||
                (p.black.id == playerBId && p.white.id == playerAId))) {
          newPairs.add(p.setResult(winnerId));
          foundInRound = true;
          anyUpdated = true;
        } else {
          newPairs.add(p);
        }
      }
      newHistory.add(foundInRound ? round.copyWith(pairs: newPairs) : round);
    }

    if (!anyUpdated) return;

    // 2. 일괄 계산 준비
    final isLeague = state.format == TournamentFormat.league ||
        (state.format == TournamentFormat.leagueAndKnockout &&
            state.stage == 1);

    List<MacmahonPlayer> updatedSectionPlayers;
    if (isLeague) {
      final allPairs = [...newHistory.expand((h) => h.pairs)];
      if (newCurrentPairing != null) allPairs.addAll(newCurrentPairing.pairs);
      updatedSectionPlayers = _calculateLeagueStandings(allPairs);
    } else {
      final allResults = [...newHistory];
      if (newCurrentPairing != null) allResults.add(newCurrentPairing);
      final replayed =
          _calculatePlayersFromHistory(allResults, state.currentSectionPlayers);
      updatedSectionPlayers = _calculateTieBreakers(replayed, state.players);
    }

    // 3. 단 한 번의 상태 업데이트로 모든 변경사항 반영 (리빌드 최소화)
    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      currentPairing: newCurrentPairing,
      history: newHistory,
    );

    // 선수 명단 일괄 업데이트 (Map 사용하여 O(N)으로 처리)
    final playerMap = {for (final p in updatedSectionPlayers) p.id: p};
    final allPlayers =
        state.players.map((p) => playerMap[p.id] ?? p).toList();

    state = state.copyWith(
      sectionData: newSectionData,
      players: allPlayers,
    );

    saveCurrentTournament();
  }

  // 리그전 계산 로직 분리 (반환형으로 변경)
  List<MacmahonPlayer> _calculateLeagueStandings(List<MacmahonPair> allPairs) {
    final sectionPlayers = state.currentSectionPlayers;
    final Map<String, _LeagueStat> stats = {
      for (final p in sectionPlayers) p.id: _LeagueStat(),
    };

    // 결과가 입력된 경기만 처리
    for (final pair in allPairs) {
      if (!pair.isResultEntered) continue;
      final bId = pair.black.id;
      final wId = pair.white.id;
      if (!stats.containsKey(bId) || !stats.containsKey(wId)) continue;

      if (pair.winnerId == bId) {
        stats[bId]!.wins++;
        stats[bId]!.defeated.add(wId);
        stats[wId]!.losses++;
      } else if (pair.winnerId == wId) {
        stats[wId]!.wins++;
        stats[wId]!.defeated.add(bId);
        stats[bId]!.losses++;
      } else {
        // 무승부
        stats[bId]!.draws++;
        stats[wId]!.draws++;
      }
    }

    // 선수 목록에 반영 (currentMms = 순수 승점: 승×1 + 무×0.5)
    final updated = sectionPlayers.map((p) {
      final s = stats[p.id] ?? _LeagueStat();
      final score = s.wins * 1.0 + s.draws * 0.5;
      return p.copyWith(
        currentMms: score,
        wins: s.wins,
        losses: s.losses,
        draws: s.draws,
        defeatedOpponents: s.defeated,
        // 아래는 리그전에서 사용하지 않으므로 0으로 초기화
        sos: 0.0,
        sodos: 0.0,
        cumulativeScore: 0.0,
        floatHistory: [],
        opponents: s.defeated.union({}), // 최소한 이긴 상대는 기록
      );
    }).toList();

    return updated;
  }

  void _recomputeStandings() {
    final currentData = state.currentSectionData;
    final isLeague = state.format == TournamentFormat.league ||
        (state.format == TournamentFormat.leagueAndKnockout &&
            state.stage == 1);

    List<MacmahonPlayer> updatedSectionPlayers;
    if (isLeague) {
      final allPairs = [...currentData.history.expand((h) => h.pairs)];
      if (currentData.currentPairing != null) {
        allPairs.addAll(currentData.currentPairing!.pairs);
      }
      updatedSectionPlayers = _calculateLeagueStandings(allPairs);
    } else {
      final List<PairingResult> allResults = [...currentData.history];
      if (currentData.currentPairing != null) {
        allResults.add(currentData.currentPairing!);
      }
      final replayed =
          _calculatePlayersFromHistory(allResults, state.currentSectionPlayers);
      updatedSectionPlayers = _calculateTieBreakers(replayed, state.players);
    }

    _updatePlayersInState(updatedSectionPlayers);
    saveCurrentTournament();
  }

  List<MacmahonPlayer> _calculateTieBreakers(
      List<MacmahonPlayer> sectionPlayers, List<MacmahonPlayer> allPlayers) {
    final Map<String, MacmahonPlayer> idMap = {
      for (final p in allPlayers) p.id: p
    };
    for (final p in sectionPlayers) {
      idMap[p.id] = p;
    }

    return sectionPlayers.map((p) {
      double sos = 0;
      for (final oId in p.opponents) {
        final o = idMap[oId];
        if (o != null && o.id != p.id) sos += o.currentMms;
      }
      double sodos = 0;
      for (final dId in p.defeatedOpponents) {
        final o = idMap[dId];
        if (o != null && o.id != p.id) sodos += o.currentMms;
      }
      return p.copyWith(sos: sos, sodos: sodos);
    }).toList();
  }

  void advanceRound() {
    if (state.currentPairing == null) return;
    final currentData = state.currentSectionData;
    final updatedHistory = [...currentData.history, currentData.currentPairing!];
    
    // 리그전인 경우 라운드 진행 시 완료 상태로 처리 (리그는 1라운드에 모든 대진이 생성되므로)
    final isFinished = state.format == TournamentFormat.league || 
                      (state.format == TournamentFormat.leagueAndKnockout && currentData.stage == 1);

    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      history: updatedHistory,
      currentRound: updatedHistory.length + 1,
      currentPairing: null,
      isFinished: isFinished,
    );
    state = state.copyWith(sectionData: newSectionData);
    _recomputeStandings();
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

  List<MacmahonPlayer> _calculatePlayersFromHistory(
      List<PairingResult> history, List<MacmahonPlayer> sectionPlayers) {
    // 맵을 사용하여 선수 조회를 O(1)로 최적화
    final Map<String, MacmahonPlayer> playerMap = {
      for (final p in sectionPlayers)
        p.id: p.copyWith(
          currentMms: (state.format == TournamentFormat.league || 
                      (state.format == TournamentFormat.leagueAndKnockout && state.stage == 1)) ? 0.0 : p.initialMms,
          wins: 0,
          losses: 0,
          draws: 0,
          opponents: {},
          defeatedOpponents: {},
          floatHistory: [],
          cumulativeScore: 0.0,
        )
    };

    for (final roundResult in history) {
      for (final pair in roundResult.pairs) {
        final b = playerMap[pair.black.id];
        final w = playerMap[pair.white.id];
        if (b == null || w == null) continue;

        b.addOpponent(w.id);
        w.addOpponent(b.id);
        b.floatHistory.add(pair.blackFloatResult);
        w.floatHistory.add(pair.whiteFloatResult);

        if (pair.winnerId == b.id) {
          b.wins++;
          b.currentMms += 1.0;
          b.defeatedOpponents.add(w.id);
          w.losses++;
        } else if (pair.winnerId == w.id) {
          w.wins++;
          w.currentMms += 1.0;
          w.defeatedOpponents.add(b.id);
          b.losses++;
        } else if (pair.isResultEntered) {
          b.draws++;
          b.currentMms += 0.5;
          w.draws++;
          w.currentMms += 0.5;
        }
      }
      for (final byePlayer in roundResult.byePlayers) {
        final bye = playerMap[byePlayer.id];
        if (bye != null) {
          bye.currentMms += 1.0;
          bye.wins++;
          bye.floatHistory.add(0);
        }
      }
      for (final p in playerMap.values) p.updateCumulativeScore();
    }
    return playerMap.values.toList();
  }

  void computeTieBreakers() {
    final players = state.players;
    // 고속 조회를 위한 ID 맵 생성
    final Map<String, MacmahonPlayer> idMap = {for (final p in players) p.id: p};

    final updatedPlayers = players.map((p) {
      if (p.section != state.selectedSection) return p;
      double sos = 0;
      for (final oId in p.opponents) {
        final o = idMap[oId];
        if (o != null && o.id != p.id) sos += o.currentMms;
      }
      double sodos = 0;
      for (final dId in p.defeatedOpponents) {
        final o = idMap[dId];
        if (o != null && o.id != p.id) sodos += o.currentMms;
      }
      return p.copyWith(sos: sos, sodos: sodos);
    }).toList();

    state = state.copyWith(players: updatedPlayers);
  }

  List<MacmahonPlayer> _getKnockoutSurvivors(
      List<MacmahonPlayer> players, List<PairingResult> history) {
    final currentData = state.currentSectionData;

    // 1. 본선 진출자 명단이 없으면 전체 선수를 대상으로 함 (일반 토너먼트)
    final List<String> qualifiers = currentData.knockoutQualifiers;

    // 2. 현재 단계가 본선 1라운드인 경우 -> 선발된 진출자 전원 반환
    if (currentData.currentRound == 1) {
      if (qualifiers.isNotEmpty) {
        return players.where((p) => qualifiers.contains(p.id)).toList();
      }
      // 리그 없이 바로 토너먼트인 경우 전체 선수 중 상위 N명
      return List<MacmahonPlayer>.from(players)
        ..sort((a, b) => comparePlayers(b, a, currentData.format))
        ..take(currentData.qualifierCount).toList();
    }

    // 3. 본선 진행 중인 경우 (2라운드 이상)
    // 히스토리 중 본선 진출자들이 포함된 대국(토너먼트 대국)만 추출
    // 보통 본선 시작 후 쌓인 히스토리가 본선 대국임
    if (history.isEmpty) return players;

    // 본선 시작 이후의 기록만 찾기 위해 뒤에서부터 탐색
    // (예선 기록은 조별 매칭이지만 본선은 전체 매칭이므로 구분 가능)
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
    final Map<String, MacmahonPlayer> updateMap = {
      for (final p in updatedSectionPlayers) p.id: p
    };
    state = state.copyWith(
      players: state.players.map((p) => updateMap[p.id] ?? p).toList(),
    );
  }

  Future<void> startKnockoutStage(List<String> selectedIds) async {
    final currentData = state.currentSectionData;
    if (currentData.stage != 1) return;

    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      stage: 2,
      currentRound: 1, // 토너먼트 1라운드부터 시작
      currentPairing: null,
      knockoutQualifiers: selectedIds, // 수동 선택된 본선 진출자 저장
    );

    state = state.copyWith(sectionData: newSectionData);
    await saveCurrentTournament();
  }

  /// 본선 단계를 초기화하고 예선 단계로 돌아갑니다.
  Future<void> resetKnockoutStage() async {
    final currentData = state.currentSectionData;
    if (currentData.stage != 2) return;

    final newSectionData = Map<String, SectionData>.from(state.sectionData);
    newSectionData[state.selectedSection] = currentData.copyWith(
      stage: 1,
      currentPairing: null,
      knockoutQualifiers: [],
    );

    state = state.copyWith(sectionData: newSectionData);
    await saveCurrentTournament();
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

/// 리그전 순위 계산용 임시 통계 저장 클래스
class _LeagueStat {
  int wins = 0;
  int losses = 0;
  int draws = 0;
  Set<String> defeated = {}; // 내가 이긴 상대 ID (승자승 타이브레이크용)
}

