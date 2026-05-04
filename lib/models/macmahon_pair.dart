import 'macmahon_player.dart';

/// 매칭된 대진 한 쌍을 나타내는 모델
class MacmahonPair {
  final MacmahonPlayer black; // 흑번 선수
  final MacmahonPlayer white; // 백번 선수
  final double mmsDiff; // MMS 점수 차이 (절댓값)
  final double cost; // 이 페어링의 총 비용 (낮을수록 이상적)

  /// floatResult: 이 페어링이 각 선수에게 미치는 플로팅 결과
  ///   black 기준: black.currentMms > white.currentMms → black은 Float Down(-1)
  ///   동점일 경우 모두 0
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

  /// 두 선수 간의 플로팅 방향 계산
  /// self가 opponent보다 점수가 높으면 → Float Down(-1)
  /// self가 opponent보다 점수가 낮으면 → Float Up(+1)
  /// 동점이면 → 0
  static int _calcFloat(MacmahonPlayer self, MacmahonPlayer opponent) {
    if (self.currentMms > opponent.currentMms) return -1; // Float Down
    if (self.currentMms < opponent.currentMms) return 1; // Float Up
    return 0; // 동점
  }

  Map<String, dynamic> toJson() => {
        'blackId': black.id,
        'whiteId': white.id,
        'cost': cost,
        'winnerId': winnerId,
        'isResultEntered': isResultEntered,
      };

  static MacmahonPair fromJson(
      Map<String, dynamic> json, List<MacmahonPlayer> players) {
    return MacmahonPair(
      black: players.firstWhere((p) => p.id == json['blackId']),
      white: players.firstWhere((p) => p.id == json['whiteId']),
      cost: (json['cost'] as num).toDouble(),
      winnerId: json['winnerId'] as String?,
      isResultEntered: json['isResultEntered'] as bool? ?? false,
    );
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

  /// 전체 비용 합계 (낮을수록 페어링 품질이 높음)
  double get totalCost => pairs.fold(0.0, (sum, p) => sum + p.cost);

  Map<String, dynamic> toJson() => {
        'round': round,
        'byePlayerId': byePlayer?.id,
        'byePlayerIds': byePlayers.map((p) => p.id).toList(),
        'pairs': pairs.map((p) => p.toJson()).toList(),
      };

  static PairingResult fromJson(
      Map<String, dynamic> json, List<MacmahonPlayer> players) {
    final byePlayerId = json['byePlayerId'];
    final byePlayerIds = json['byePlayerIds'] as List?;
    
    List<MacmahonPlayer> byes = [];
    if (byePlayerIds != null) {
      byes = byePlayerIds.map((id) => players.firstWhere((p) => p.id == id)).toList();
    } else if (byePlayerId != null) {
      byes = [players.firstWhere((p) => p.id == byePlayerId)];
    }

    return PairingResult(
      round: (json['round'] as num?)?.toInt() ?? 1,
      byePlayers: byes,
      pairs: (json['pairs'] as List)
          .map((p) => MacmahonPair.fromJson(p, players))
          .toList(),
    );
  }

  @override
  String toString() =>
      'PairingResult(round: $round, pairs: ${pairs.length}, totalCost: $totalCost)';
}
