import '../../../../core/constants/tournament_enums.dart';

/// 매칭된 대진 한 쌍을 나타내는 엔티티
class MacmahonPair {
  final MacmahonPlayer black; // 흑번 선수
  final MacmahonPlayer white; // 백번 선수
  final double mmsDiff; // MMS 점수 차이 (절댓값)
  final double cost; // 이 페어링의 총 비용 (낮을수록 이상적)

  /// floatResult: 이 페어링이 각 선수에게 미치는 플로팅 결과
  final int blackFloatResult; // black 선수의 float 결과
  final int whiteFloatResult; // white 선수의 float 결과
  final String? winnerId; // 승리한 선수 ID (null = 무승부 또는 미결정)
  final bool isResultEntered; // 결과 입력 여부

  MacmahonPair({
    required this.black,
    required this.white,
    required this.cost,
    this.winnerId,
    this.isResultEntered = false,
  })  : mmsDiff = (black.currentMms - white.currentMms).abs(),
        blackFloatResult = _calcFloat(black, white),
        whiteFloatResult = _calcFloat(white, black);

  MacmahonPair copyWith({
    String? winnerId,
    bool? isResultEntered,
  }) {
    return MacmahonPair(
      black: black,
      white: white,
      cost: cost,
      winnerId: winnerId ?? this.winnerId,
      isResultEntered: isResultEntered ?? this.isResultEntered,
    );
  }

  MacmahonPair setResult(String? winnerId) {
    return MacmahonPair(
      black: black,
      white: white,
      cost: cost,
      winnerId: winnerId,
      isResultEntered: true,
    );
  }

  static int _calcFloat(MacmahonPlayer self, MacmahonPlayer opponent) {
    if (self.currentMms > opponent.currentMms) return -1; // Float Down
    if (self.currentMms < opponent.currentMms) return 1; // Float Up
    return 0; // 동점
  }

  @override
  String toString() =>
      'Pair(${black.name} vs ${white.name}, winner: $winnerId, enters: $isResultEntered)';
}

class PairingResult {
  final List<MacmahonPair> pairs; // 확정된 대진 목록
  final List<MacmahonPlayer> byePlayers; // 부전승 선수 목록
  final int round; // 라운드 번호

  const PairingResult({
    required this.pairs,
    required this.round,
    this.byePlayers = const [],
  });

  MacmahonPlayer? get byePlayer => byePlayers.isNotEmpty ? byePlayers.first : null;

  PairingResult copyWith({
    List<MacmahonPair>? pairs,
    List<MacmahonPlayer>? byePlayers,
    int? round,
  }) {
    return PairingResult(
      pairs: pairs ?? this.pairs,
      round: round ?? this.round,
      byePlayers: byePlayers ?? this.byePlayers,
    );
  }

  double get totalCost => pairs.fold(0.0, (sum, p) => sum + p.cost);

  @override
  String toString() =>
      'PairingResult(round: $round, pairs: ${pairs.length}, totalCost: $totalCost)';
}

/// 선수 엔티티
class MacmahonPlayer {
  final String id;
  final String name;
  final String section;
  final double initialMms;
  final double currentMms;
  final bool isTopBar;
  final List<int> floatHistory;
  final Set<String> opponents;
  final Set<String> defeatedOpponents;
  final int wins;
  final int losses;
  final int draws;
  final double sos;
  final double sodos;
  final double sosos;
  final double cumulativeScore;
  final String? groupId;

  MacmahonPlayer({
    required this.id,
    required this.name,
    this.section = '일반부',
    required this.initialMms,
    required this.currentMms,
    this.isTopBar = false,
    this.floatHistory = const [],
    this.opponents = const {},
    this.defeatedOpponents = const {},
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.sos = 0.0,
    this.sodos = 0.0,
    this.sosos = 0.0,
    this.cumulativeScore = 0.0,
    this.groupId,
  });

  MacmahonPlayer copyWith({
    String? id,
    String? name,
    String? section,
    double? initialMms,
    double? currentMms,
    bool? isTopBar,
    List<int>? floatHistory,
    Set<String>? opponents,
    Set<String>? defeatedOpponents,
    int? wins,
    int? losses,
    int? draws,
    double? sos,
    double? sodos,
    double? sosos,
    double? cumulativeScore,
    String? groupId,
  }) {
    return MacmahonPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      section: section ?? this.section,
      initialMms: initialMms ?? this.initialMms,
      currentMms: currentMms ?? this.currentMms,
      isTopBar: isTopBar ?? this.isTopBar,
      floatHistory: floatHistory ?? this.floatHistory,
      opponents: opponents ?? this.opponents,
      defeatedOpponents: defeatedOpponents ?? this.defeatedOpponents,
      wins: wins ?? this.wins,
      losses: losses ?? this.losses,
      draws: draws ?? this.draws,
      sos: sos ?? this.sos,
      sodos: sodos ?? this.sodos,
      sosos: sosos ?? this.sosos,
      cumulativeScore: cumulativeScore ?? this.cumulativeScore,
      groupId: groupId ?? this.groupId,
    );
  }

  int? get lastFloat => floatHistory.isEmpty ? null : floatHistory.last;

  bool get isConsecutiveFloatDown {
    if (floatHistory.length < 2) return false;
    return floatHistory[floatHistory.length - 1] == -1 &&
        floatHistory[floatHistory.length - 2] == -1;
  }

  bool get wasFloatDown => lastFloat == -1;
  bool get wasFloatUp => lastFloat == 1;

  bool hasPlayedAgainst(String opponentId) => opponents.contains(opponentId);

  @override
  String toString() =>
      'MacmahonPlayer($name, Section: $section, MMS: $currentMms, Group: $groupId)';
}
