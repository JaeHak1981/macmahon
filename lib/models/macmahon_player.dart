/// 맥마흔 시스템 — 선수 모델
///
/// floatHistory: 각 라운드의 플로팅 결과
///   +1 = Float Up (상향 매칭)
///    0 = 동점 매칭
///   -1 = Float Down (하향 매칭)
///
/// opponents: 이미 대결한 상대 선수 ID 집합 (리매치 방지)
class MacmahonPlayer {
  final String id;
  final String name;
  final double initialMms; // 초기 맥마흔 점수 (대회 시작 시 부여)
  double currentMms; // 현재 맥마흔 점수 (라운드마다 갱신)
  final bool isTopBar; // Top Bar 이상 여부 (안티그래비티 제외 대상)
  List<int> floatHistory; // 각 라운드별 플로팅 결과 리스트
  Set<String> opponents; // 이미 대결한 상대 ID 집합
  Set<String> defeatedOpponents; // 내가 이긴 상대 ID 집합 (SODOS용)
  int wins = 0;
  int losses = 0;
  int draws = 0;
  double sos = 0.0; // Sum of Opponents' Scores
  double sodos = 0.0; // Sum of Defeated Opponents' Scores
  double cumulativeScore = 0.0; // 점수 누계 (Progressive Score) - 타이 브레이크용

  MacmahonPlayer({
    required this.id,
    required this.name,
    required this.initialMms,
    required this.currentMms,
    this.isTopBar = false,
    List<int>? floatHistory,
    Set<String>? opponents,
    Set<String>? defeatedOpponents,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.sos = 0.0,
    this.sodos = 0.0,
    this.cumulativeScore = 0.0,
  })  : floatHistory = floatHistory ?? [],
        opponents = opponents ?? {},
        defeatedOpponents = defeatedOpponents ?? {};

  /// 직전 라운드 플로팅 결과 (-1, 0, +1)
  int? get lastFloat => floatHistory.isEmpty ? null : floatHistory.last;

  /// 직전 2라운드가 모두 Float Down인지 여부
  /// → 이 경우 이번 라운드 Float Down 절대 금지
  bool get isConsecutiveFloatDown {
    if (floatHistory.length < 2) return false;
    return floatHistory[floatHistory.length - 1] == -1 &&
        floatHistory[floatHistory.length - 2] == -1;
  }

  /// 직전 라운드 혹은 지정된 라운드 후에 점수 누계 업데이트
  void updateCumulativeScore() {
    cumulativeScore += currentMms;
  }

  /// 직전 라운드가 Float Down인지 여부 (강한 페널티 대상)
  bool get wasFloatDown => lastFloat == -1;

  /// 직전 라운드가 Float Up인지 여부 (강한 페널티 대상)
  bool get wasFloatUp => lastFloat == 1;

  /// 상대와 이미 대결했는지 여부
  bool hasPlayedAgainst(String opponentId) => opponents.contains(opponentId);

  /// 대결 기록 추가
  void addOpponent(String opponentId) => opponents.add(opponentId);

  /// 라운드 결과 적용 (플로팅 기록 추가 + 점수 갱신)
  void applyRoundResult({required int floatResult, required double mmsDelta}) {
    floatHistory.add(floatResult);
    currentMms += mmsDelta;
    updateCumulativeScore(); // 라운드 종료 시점의 MMS를 누적
  }

  @override
  String toString() =>
      'MacmahonPlayer($name, MMS: $currentMms, floatHistory: $floatHistory)';

  /// JSON 직렬화 (저장/복원용)
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'initialMms': initialMms,
        'currentMms': currentMms,
        'isTopBar': isTopBar,
        'floatHistory': floatHistory,
        'opponents': opponents.toList(),
        'defeatedOpponents': defeatedOpponents.toList(),
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'sos': sos,
        'sodos': sodos,
        'cumulativeScore': cumulativeScore,
      };

  factory MacmahonPlayer.fromJson(Map<String, dynamic> json) =>
      MacmahonPlayer(
        id: json['id'] as String,
        name: json['name'] as String,
        initialMms: (json['initialMms'] as num).toDouble(),
        currentMms: (json['currentMms'] as num).toDouble(),
        isTopBar: json['isTopBar'] as bool? ?? false,
        floatHistory: List<int>.from(json['floatHistory'] as List),
        opponents: Set<String>.from(json['opponents'] as List),
        defeatedOpponents: json['defeatedOpponents'] != null 
            ? Set<String>.from(json['defeatedOpponents'] as List)
            : {},
        wins: json['wins'] as int? ?? 0,
        losses: json['losses'] as int? ?? 0,
        draws: json['draws'] as int? ?? 0,
        sos: (json['sos'] as num? ?? 0.0).toDouble(),
        sodos: (json['sodos'] as num? ?? 0.0).toDouble(),
        cumulativeScore: (json['cumulativeScore'] as num? ?? 0.0).toDouble(),
      );
}
