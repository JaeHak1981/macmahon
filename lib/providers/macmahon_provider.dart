import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/macmahon_pair.dart';
import '../models/macmahon_player.dart';
import '../services/pairing_service.dart';
import '../services/storage_service.dart';
import '../utils/macmahon_utils.dart';

// ─── 상태 클래스 ────────────────────────────────────────────

/// 맥마흔 페어링 상태
class MacmahonState {
  final List<MacmahonPlayer> players; // 전체 선수 목록
  final List<PairingResult> history; // 라운드별 페어링 이력
  final PairingResult? currentPairing; // 이번 라운드 대진표
  final int currentRound; // 현재 라운드 번호
  final bool isLoading; // 계산 중 여부
  final String? errorMessage; // 에러 메시지
  final String tournamentName; // 대회 명칭
  final String tournamentDate; // 대회 날짜
  final String tournamentLocation; // 대회 장소

  const MacmahonState({
    this.players = const [],
    this.history = const [],
    this.currentPairing,
    this.currentRound = 1,
    this.isLoading = false,
    this.errorMessage,
    this.tournamentName = '새 대회',
    this.tournamentDate = '',
    this.tournamentLocation = '',
  });

  MacmahonState copyWith({
    List<MacmahonPlayer>? players,
    List<PairingResult>? history,
    dynamic currentPairing = _sentinel, // null을 명시적으로 허구하기 위한 센티넬
    int? currentRound,
    bool? isLoading,
    String? errorMessage,
    String? tournamentName,
    String? tournamentDate,
    String? tournamentLocation,
  }) {
    return MacmahonState(
      players: players ?? this.players,
      history: history ?? this.history,
      currentPairing: currentPairing == _sentinel ? this.currentPairing : currentPairing as PairingResult?,
      currentRound: currentRound ?? this.currentRound,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      tournamentName: tournamentName ?? this.tournamentName,
      tournamentDate: tournamentDate ?? this.tournamentDate,
      tournamentLocation: tournamentLocation ?? this.tournamentLocation,
    );
  }

  static const _sentinel = Object();

  Map<String, dynamic> toJson() => {
        'players': players.map((p) => p.toJson()).toList(),
        'history': history.map((h) => h.toJson()).toList(),
        'currentPairing': currentPairing?.toJson(),
        'currentRound': currentRound,
        'tournamentName': tournamentName,
        'tournamentDate': tournamentDate,
        'tournamentLocation': tournamentLocation,
      };

  factory MacmahonState.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List)
        .map((p) => MacmahonPlayer.fromJson(p))
        .toList();
    return MacmahonState(
      players: players,
      history: (json['history'] as List)
          .map((h) => PairingResult.fromJson(h, players))
          .toList(),
      currentPairing: json['currentPairing'] == null
          ? null
          : PairingResult.fromJson(json['currentPairing'], players),
      currentRound: json['currentRound'] as int,
      tournamentName: json['tournamentName'] as String? ?? '새 대회',
      tournamentDate: json['tournamentDate'] as String? ?? '',
      tournamentLocation: json['tournamentLocation'] as String? ?? '',
    );
  }

  /// 현재 라운드 부전승 선수
  MacmahonPlayer? get byePlayer => currentPairing?.byePlayer;

  /// 전체 대진 목록 (현재 라운드)
  List<MacmahonPair> get currentPairs => currentPairing?.pairs ?? [];

  /// 추천 라운드 수
  int get recommendedRounds {
    final topBarCount = players.where((p) => p.isTopBar).length;
    return MacmahonUtils.calculateRecommendedRounds(
      players.length,
      topBarCount: topBarCount > 0 ? topBarCount : null,
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────

/// 맥마흔 페어링 Notifier (Riverpod StateNotifier)
class MacmahonNotifier extends StateNotifier<MacmahonState> {
  final PairingService _pairingService;
  final StorageService _storageService;

  MacmahonNotifier({PairingService? pairingService, StorageService? storageService})
      : _pairingService = pairingService ?? PairingService(),
        _storageService = storageService ?? StorageService(),
        super(const MacmahonState());

  /// 상태 로드 (기존 기록에서 불러오기)
  void loadState(MacmahonState loadedState) {
    state = loadedState;
  }

  /// 현재 상태 저장
  Future<void> saveCurrentTournament() async {
    await _storageService.saveTournament(state);
  }

  /// 대회 정보 업데이트
  void updateTournamentInfo({
    String? name,
    String? date,
    String? location,
  }) {
    state = state.copyWith(
      tournamentName: name,
      tournamentDate: date,
      tournamentLocation: location,
    );
  }

  /// 선수 목록 초기화 (대회 정보는 유지 가능하도록 처리)
  void initializePlayers(List<MacmahonPlayer> players) {
    state = state.copyWith(
      players: players,
      currentRound: 1,
      history: [],
      currentPairing: null,
    );
  }

  /// 선수 추가
  void addPlayer(MacmahonPlayer player) {
    state = state.copyWith(
      players: [...state.players, player],
    );
  }

  /// 선수 제거
  void removePlayer(String playerId) {
    state = state.copyWith(
      players: state.players.where((p) => p.id != playerId).toList(),
    );
  }

  /// 현재 라운드 페어링 실행
  ///
  /// 1. 비용 행렬 생성
  /// 2. 헝가리안 알고리즘으로 최적 매칭 계산
  /// 3. 상태 업데이트
  Future<void> generatePairing() async {
    if (state.players.isEmpty) {
      state = state.copyWith(errorMessage: '선수가 없습니다.');
      return;
    }

    state = state.copyWith(isLoading: true, errorMessage: null);

    try {
      // 페어링 계산 (무거운 연산이므로 Future로 처리)
      final result = await Future(() => _pairingService.generatePairing(
            players: state.players,
            round: state.currentRound,
          ));

      // floatHistory 및 opponents 반영
      _pairingService.applyPairingResult(result);

      state = state.copyWith(
        currentPairing: result,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: '페어링 오류: $e',
      );
    }
  }

  /// 라운드 결과 입력 (대진표에 승자 기록)
  void recordResult({
    required String blackId,
    required String whiteId,
    String? winnerId, // null = 무승부
  }) {
    if (state.currentPairing == null) return;

    final updatedPairs = state.currentPairing!.pairs.map((p) {
      if (p.black.id == blackId && p.white.id == whiteId) {
        return p.copyWith(winnerId: winnerId, isResultEntered: true);
      }
      return p;
    }).toList();

    state = state.copyWith(
      currentPairing: state.currentPairing!.copyWith(pairs: updatedPairs),
    );
  }

  /// 다음 라운드로 진행 (모든 결과 반영 및 히스토리 저장)
  void advanceRound() {
    if (state.currentPairing == null) return;

    // 히스토리에 현재 대진(결과 포함) 추가
    final updatedHistory = [...state.history, state.currentPairing!];
    
    // 전체 상태 재계산 (Functional Replay)
    _recalculateStateFromHistory(updatedHistory);
    
    // 자동 저장
    saveCurrentTournament();
  }

  /// 마지막 라운드 취소 (Undo)
  void undoLastRound() {
    if (state.history.isEmpty) return;

    // 마지막 히스토리 제거
    final newHistory = List<PairingResult>.from(state.history)..removeLast();
    
    // 전체 상태 재계산
    _recalculateStateFromHistory(newHistory);
  }

  /// 히스토리를 기반으로 모든 선수의 점수, 상대 기록, SOS를 처음부터 다시 계산합니다.
  void _recalculateStateFromHistory(List<PairingResult> history) {
    // 1. 모든 선수 초기화 (initialMms로 복구)
    var players = state.players.map((p) {
      return MacmahonPlayer(
        id: p.id,
        name: p.name,
        initialMms: p.initialMms,
        currentMms: p.initialMms,
        isTopBar: p.isTopBar,
        opponents: {}, // 명시적으로 비우기
        defeatedOpponents: {}, 
        floatHistory: [],
        cumulativeScore: 0.0, // 명시적 초기화
      );
    }).toList();

    // 2. 히스토리 순회하며 결과 적용
    for (final roundResult in history) {
      for (final pair in roundResult.pairs) {
        final black = players.firstWhere((p) => p.id == pair.black.id);
        final white = players.firstWhere((p) => p.id == pair.white.id);

        // 상대 기록 추가
        black.addOpponent(white.id);
        white.addOpponent(black.id);

        // 플로팅 기록 추가 (pair 생성 시점의 점수 기준)
        black.floatHistory.add(pair.blackFloatResult);
        white.floatHistory.add(pair.whiteFloatResult);

        // 승패 반영
        if (pair.winnerId == black.id) {
          black.wins++;
          black.currentMms += 1.0;
          black.defeatedOpponents.add(white.id);
          white.losses++;
        } else if (pair.winnerId == white.id) {
          white.wins++;
          white.currentMms += 1.0;
          white.defeatedOpponents.add(black.id);
          black.losses++;
        } else if (pair.isResultEntered) {
          // 무승부
          black.draws++;
          black.currentMms += 0.5;
          white.draws++;
          white.currentMms += 0.5;
        }
      }

      // 부전승 처리
      if (roundResult.byePlayer != null) {
        final bye = players.firstWhere((p) => p.id == roundResult.byePlayer!.id);
        bye.currentMms += 1.0;
        bye.wins++;
        bye.floatHistory.add(0);
      }

      // 라운드 종료 시점의 MMS를 누계 (Progressive Score)
      for (final p in players) {
        p.updateCumulativeScore();
      }
    }

    // 3. 상태 업데이트
    state = state.copyWith(
      players: players,
      history: history,
      currentRound: history.length + 1,
      currentPairing: null,
    );

    // 4. SOS 재계산
    computeTieBreakers();
  }

  /// 모든 선수의 SOS 및 SODOS를 다시 계산합니다.
  /// (상대의 MMS가 변경될 때마다 전체가 업데이트되어야 함)
  void computeTieBreakers() {
    final players = state.players;
    final updatedPlayers = players.map((p) {
      double newSos = 0.0;

      for (final opponentId in p.opponents) {
        // 상대 선수 찾기
        final opponent = players.firstWhere(
          (other) => other.id == opponentId,
          orElse: () => MacmahonPlayer(
              id: '', name: '', initialMms: 0.0, currentMms: 0.0), // fallback with doubles
        );

        if (opponent.id.isNotEmpty) {
          newSos += opponent.currentMms;
        }
      }

      // SODOS 재계산: 내가 이긴 상대의 현재 MMS 합계
      double newSodos = 0.0;
      for (final defeatedId in p.defeatedOpponents) {
        final opponent = players.firstWhere(
          (other) => other.id == defeatedId,
          orElse: () => MacmahonPlayer(id: '', name: '', initialMms: 0, currentMms: 0),
        );
        if (opponent.id.isNotEmpty) {
          newSodos += opponent.currentMms;
        }
      }

      return MacmahonPlayer(
        id: p.id,
        name: p.name,
        initialMms: p.initialMms,
        currentMms: p.currentMms,
        isTopBar: p.isTopBar,
        floatHistory: p.floatHistory,
        opponents: p.opponents,
        defeatedOpponents: p.defeatedOpponents,
        wins: p.wins,
        losses: p.losses,
        draws: p.draws,
        sos: newSos,
        sodos: newSodos,
        cumulativeScore: p.cumulativeScore, // 누계 점수 유지
      );
    }).toList();

    state = state.copyWith(players: updatedPlayers);
  }


  /// 대회 리셋
  void resetTournament() {
    state = const MacmahonState();
  }
}

// ─── Provider ─────────────────────────────────────────────

/// 맥마흔 페어링 Provider
final macmahonProvider =
    StateNotifierProvider<MacmahonNotifier, MacmahonState>(
  (ref) => MacmahonNotifier(),
);
