import '../entities/macmahon_entities.dart';
import 'cost_matrix_builder.dart';

class PairingService {
  PairingResult generatePairing({
    required List<MacmahonPlayer> players,
    required int round,
  }) {
    if (players.isEmpty) {
      return PairingResult(pairs: [], round: round);
    }

    final List<MacmahonPlayer> workingList = List.from(players);
    workingList.sort((a, b) {
      int mmsComp = b.currentMms.compareTo(a.currentMms);
      if (mmsComp != 0) return mmsComp;
      int sosComp = b.sos.compareTo(a.sos);
      if (sosComp != 0) return sosComp;
      return a.id.compareTo(b.id);
    });

    // 1. 부전승(BYE) 사전 분리 로직
    MacmahonPlayer? byePlayer;
    if (workingList.length % 2 != 0) {
      byePlayer = _findByePlayer(workingList);
      workingList.removeWhere((p) => p.id == byePlayer!.id);
    }

    if (workingList.isEmpty) {
      return PairingResult(
        pairs: [],
        round: round,
        byePlayers: byePlayer != null ? [byePlayer] : [],
      );
    }

    // 2. 완벽 매칭 (DFS 백트래킹)
    List<MacmahonPair> bestMatches = _generatePerfectPairing(workingList);

    return PairingResult(
      pairs: bestMatches,
      round: round,
      byePlayers: byePlayer != null ? [byePlayer] : [],
    );
  }

  MacmahonPlayer _findByePlayer(List<MacmahonPlayer> players) {
    // 1. 부전승 후보: 이미 부전승 경험이 있는 선수 제외
    final candidates = players.where((p) => !p.opponents.contains('__dummy__')).toList();
    
    // 만약 전원이 부전승을 해봤다면 전체 선수를 후보로 둠 (방어 코드)
    final validCandidates = candidates.isNotEmpty ? candidates : List<MacmahonPlayer>.from(players);

    // 2. 점수(MMS) 오름차순(최하위 우선), 동점 시 SOS 오름차순 정렬
    validCandidates.sort((a, b) {
      int mmsComp = a.currentMms.compareTo(b.currentMms);
      if (mmsComp != 0) return mmsComp;
      return a.sos.compareTo(b.sos);
    });

    return validCandidates.first; // 가장 점수가 낮고 부전승을 안해본 선수
  }

  List<MacmahonPair>? _bestPairs;
  double _minCost = double.infinity;
  int _iterations = 0;
  static const int _maxIterations = 100000;

  List<MacmahonPair> _generatePerfectPairing(List<MacmahonPlayer> players) {
    _bestPairs = null;
    _minCost = double.infinity;
    _iterations = 0;
    
    _dfs(players, [], 0.0);
    
    // 타임아웃 등으로 전혀 매칭을 찾지 못한 극소수의 경우에 대비한 Fallback (단순 스위스 연결)
    if (_bestPairs == null) {
      return _fallbackGreedyPairing(players);
    }
    
    return _bestPairs!;
  }

  void _dfs(
    List<MacmahonPlayer> unmatched, 
    List<MacmahonPair> currentPairs, 
    double currentCost,
  ) {
    // 안전장치: 과도한 연산 루프(타임아웃) 방지
    if (_iterations > _maxIterations) return;
    
    // 가지치기(Pruning): 현재까지 누적된 비용이 이미 최고기록(최저비용)을 초과했다면 탐색 중단
    if (currentCost >= _minCost) return; 
    
    // 모두 짝이 지어진 경우: 새로운 최고기록 갱신
    if (unmatched.isEmpty) {
      _minCost = currentCost;
      _bestPairs = List.from(currentPairs);
      return;
    }
    
    _iterations++;
    
    // 항상 가장 먼저 남은 선수(점수가 가장 높은 선수)를 기준으로 탐색
    final p1 = unmatched.first;
    final candidates = unmatched.sublist(1);
    
    // 상대방 후보 정렬: Cost가 낮은 순서대로 먼저 탐색하여 최적해를 빠르게 도출 (Greedy 방식)
    candidates.sort((a, b) {
      double costA = CostMatrixBuilder.calculateCost(p1, a);
      double costB = CostMatrixBuilder.calculateCost(p1, b);
      if (costA != costB) return costA.compareTo(costB);
      
      // Cost가 동일하다면, 스위스 리그 Slide 방식처럼 중간 등수에 있는 사람을 우선 시도
      int idealIdx = candidates.length ~/ 2;
      int distA = (candidates.indexOf(a) - idealIdx).abs();
      int distB = (candidates.indexOf(b) - idealIdx).abs();
      return distA.compareTo(distB);
    });
    
    for (final p2 in candidates) {
      double cost = CostMatrixBuilder.calculateCost(p1, p2);
      
      // 후보들이 이미 Cost 오름차순 정렬되어 있으므로, 
      // 이 시점에서 한계치를 넘었다면 뒤의 후보들은 안 봐도 한계치를 넘음 (가지치기 극대화)
      if (currentCost + cost >= _minCost) break;
      
      final nextUnmatched = List<MacmahonPlayer>.from(unmatched)
        ..remove(p1)
        ..remove(p2);
        
      final black = p1.currentMms >= p2.currentMms ? p1 : p2;
      final white = p1.currentMms >= p2.currentMms ? p2 : p1;
      
      currentPairs.add(MacmahonPair(
        black: black,
        white: white,
        cost: cost,
      ));
      
      _dfs(nextUnmatched, currentPairs, currentCost + cost);
      
      currentPairs.removeLast(); // 백트래킹(되돌리기)
    }
  }

  List<MacmahonPair> _fallbackGreedyPairing(List<MacmahonPlayer> players) {
    final pairs = <MacmahonPair>[];
    for (int i = 0; i < players.length; i += 2) {
      if (i + 1 < players.length) {
        final p1 = players[i];
        final p2 = players[i + 1];
        pairs.add(MacmahonPair(
          black: p1.currentMms >= p2.currentMms ? p1 : p2,
          white: p1.currentMms >= p2.currentMms ? p2 : p1,
          cost: CostMatrixBuilder.calculateCost(p1, p2),
        ));
      }
    }
    return pairs;
  }

  PairingResult generateLeaguePairing({
    required List<MacmahonPlayer> players,
    required int round,
  }) {
    if (players.isEmpty) return PairingResult(pairs: [], round: round);

    final List<MacmahonPlayer> workingList = List.from(players);
    if (workingList.length % 2 != 0) {
      workingList.add(MacmahonPlayer(id: _kDummyId, name: 'BYE', initialMms: 0, currentMms: 0));
    }

    final int n = workingList.length;
    final int roundsCount = n - 1;
    
    if (round > roundsCount) {
      return PairingResult(pairs: [], round: round);
    }

    final List<MacmahonPlayer> rotated = List.from(workingList);
    
    for (int r = 1; r < round; r++) {
      final MacmahonPlayer last = rotated.removeLast();
      rotated.insert(1, last);
    }

    final List<MacmahonPair> pairs = [];
    MacmahonPlayer? byePlayer;

    for (int i = 0; i < n / 2; i++) {
      final p1 = rotated[i];
      final p2 = rotated[n - 1 - i];

      if (p1.id == _kDummyId) {
        byePlayer = p2;
      } else if (p2.id == _kDummyId) {
        byePlayer = p1;
      } else {
        pairs.add(MacmahonPair(black: p1, white: p2, cost: 0));
      }
    }

    return PairingResult(
      pairs: pairs,
      round: round,
      byePlayers: byePlayer != null ? [byePlayer] : [],
    );
  }

  PairingResult generateKnockoutPairing({
    required List<MacmahonPlayer> players,
    required int round,
  }) {
    if (players.isEmpty) return PairingResult(pairs: [], round: round);

    final List<MacmahonPlayer> sorted = List.from(players);
    // 1라운드일 때만 실력순(MMS)으로 정렬하여 시드 배정
    // 2라운드부터는 이전 라운드 승자 순서를 유지해야 대진표가 꼬이지 않음
    if (round == 1) {
      sorted.sort((a, b) => b.currentMms.compareTo(a.currentMms));
      
      // 시드 배정 (1위 vs 8위 식의 배치를 원한다면 여기서 순서를 섞어줘야 함)
      // 현재 브라켓 UI는 순차적 배치를 가정하므로, 일단 그대로 둡니다.
    }

    int n = sorted.length;
    MacmahonPlayer? byePlayer;

    if (n % 2 != 0) {
      // 인접 매칭을 위해 홀수인 경우 마지막 선수를 부전승 처리
      byePlayer = sorted.last;
    }

    final List<MacmahonPlayer> remaining =
        byePlayer != null ? sorted.sublist(0, n - 1) : sorted;

    final List<MacmahonPair> pairs = [];

    // 인접 매칭: 0-1, 2-3, 4-5... 순서로 대진 생성
    for (int i = 0; i < remaining.length; i += 2) {
      final p1 = remaining[i];
      final p2 = remaining[i + 1];

      // 부전승(Dummy) 체크 및 자동 결과 처리
      final bool isP1Dummy = p1.id == _kDummyId || p1.id.startsWith('bye_') || p1.name == '(부전)';
      final bool isP2Dummy = p2.id == _kDummyId || p2.id.startsWith('bye_') || p2.name == '(부전)';

      if (isP1Dummy || isP2Dummy) {
        pairs.add(MacmahonPair(
          black: p1,
          white: p2,
          cost: 0,
          winnerId: isP1Dummy ? p2.id : p1.id,
          isResultEntered: true,
        ));
      } else {
        pairs.add(MacmahonPair(black: p1, white: p2, cost: 0));
      }
    }

    return PairingResult(
      pairs: pairs,
      round: round,
      byePlayers: byePlayer != null ? [byePlayer] : [],
    );
  }

  PairingResult generateKnockoutPairingManual({
    required List<MacmahonPlayer> orderedPlayers,
    required int round,
  }) {
    if (orderedPlayers.isEmpty) return PairingResult(pairs: [], round: round);

    int n = orderedPlayers.length;
    MacmahonPlayer? byePlayer;

    if (n % 2 != 0) {
      byePlayer = orderedPlayers.last;
    }

    final List<MacmahonPlayer> remaining =
        byePlayer != null ? orderedPlayers.sublist(0, n - 1) : orderedPlayers;

    final List<MacmahonPair> pairs = [];

    for (int i = 0; i < remaining.length; i += 2) {
      final p1 = remaining[i];
      final p2 = remaining[i + 1];

      // 부전승(Dummy) 체크 및 자동 결과 처리
      final bool isP1Dummy = p1.id == _kDummyId || p1.id.startsWith('bye_') || p1.name == '(부전)';
      final bool isP2Dummy = p2.id == _kDummyId || p2.id.startsWith('bye_') || p2.name == '(부전)';

      if (isP1Dummy || isP2Dummy) {
        pairs.add(MacmahonPair(
          black: p1,
          white: p2,
          cost: 0,
          winnerId: isP1Dummy ? p2.id : p1.id,
          isResultEntered: true,
        ));
      } else {
        pairs.add(MacmahonPair(
          black: p1,
          white: p2,
          cost: 0,
        ));
      }
    }

    return PairingResult(
      pairs: pairs,
      round: round,
      byePlayers: byePlayer != null ? [byePlayer] : [],
    );
  }

  PairingResult generateAllLeagueMatches({
    required List<MacmahonPlayer> players,
  }) {
    if (players.isEmpty) return PairingResult(pairs: [], round: 1);

    final List<MacmahonPlayer> workingList = List.from(players);
    if (workingList.length % 2 != 0) {
      workingList.add(MacmahonPlayer(
          id: _kDummyId, name: 'BYE', initialMms: 0, currentMms: 0));
    }

    final int n = workingList.length;
    final int roundsCount = n - 1;
    final List<MacmahonPair> allPairs = [];
    final Set<MacmahonPlayer> allByePlayers = {};

    for (int r = 1; r <= roundsCount; r++) {
      final res = generateLeaguePairing(players: workingList, round: r);
      allPairs.addAll(res.pairs);
      if (res.byePlayer != null) {
        allByePlayers.add(res.byePlayer!);
      }
    }

    return PairingResult(
      pairs: allPairs,
      round: 1,
      byePlayers: allByePlayers.toList(),
    );
  }

  PairingResult generateGroupLeaguePairing({
    required List<MacmahonPlayer> players,
    required int round,
  }) {
    final Map<String, List<MacmahonPlayer>> groups = {};
    for (final p in players) {
      final gId = p.groupId ?? "A";
      groups.putIfAbsent(gId, () => []).add(p);
    }

    final List<MacmahonPair> allPairs = [];
    final List<MacmahonPlayer> allByePlayers = [];

    groups.forEach((gId, groupPlayers) {
      final res = generateAllLeagueMatches(players: groupPlayers);
      allPairs.addAll(res.pairs);
      allByePlayers.addAll(res.byePlayers);
    });

    return PairingResult(
      pairs: allPairs,
      round: 1,
      byePlayers: allByePlayers,
    );
  }

  static const String _kDummyId = '__dummy__';

}
