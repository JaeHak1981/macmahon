import '../entities/macmahon_entities.dart';
import 'cost_matrix_builder.dart';

class PairingService {
  int _bestCost = 999999;
  List<MacmahonPair>? _bestPairs;

  PairingResult generatePairing({
    required List<MacmahonPlayer> players,
    required int round,
  }) {
    _bestCost = 999999;
    _bestPairs = null;

    if (players.isEmpty) {
      return PairingResult(pairs: [], round: round);
    }

    // 1. 순위표 정렬: 점수(MMS) ➔ 기세(historyString) ➔ 가산점(SOS) 순
    final List<MacmahonPlayer> workingList = List.from(players);
    workingList.sort((a, b) {
      int mmsComp = b.currentMms.compareTo(a.currentMms);
      if (mmsComp != 0) return mmsComp;
      int cumComp = b.cumulativeScore.compareTo(a.cumulativeScore);
      if (cumComp != 0) return cumComp;
      int sodosComp = b.sodos.compareTo(a.sodos);
      if (sodosComp != 0) return sodosComp;
      return b.sos.compareTo(a.sos);
    });

    final List<MacmahonPair> pairs = [];
    MacmahonPlayer? byePlayer;
    List<MacmahonPlayer> unmatched = List.from(workingList);

    // 2. 부전승(BYE) 처리 (홀수라서 1명이 남은 경우)
    if (unmatched.length % 2 != 0) {
      // 한 사람이 부전승을 1번 이상 할 수 없도록 필터링
      // 부전승을 한 번도 안 해본 선수 중 가장 후순위 선수를 찾음
      int byeCandidateIndex = -1;
      for (int i = unmatched.length - 1; i >= 0; i--) {
        if (!unmatched[i].hasPlayedAgainst(_kDummyId)) {
          byeCandidateIndex = i;
          break;
        }
      }
      
      // 만약 전원이 부전승을 한 번씩 해본 극단적인 경우라면 그냥 꼴찌를 지정
      if (byeCandidateIndex == -1) {
        byeCandidateIndex = unmatched.length - 1;
      }
      
      byePlayer = unmatched.removeAt(byeCandidateIndex);
    }

    // 3. 스마트 백트래킹(DFS)으로 최적의 직관적 매칭 찾기
    bool success = _findBestPairingDFS(unmatched, pairs, 0, workingList);

    if (success && _bestPairs != null) {
      pairs.clear();
      pairs.addAll(_bestPairs!);
    } else {
      pairs.clear();
      unmatched = List.from(workingList);
      if (unmatched.length % 2 != 0) {
        byePlayer = unmatched.removeLast(); // 단순 꼴찌 배정
      }
      _fallbackGreedyPairing(unmatched, pairs);
    }

    return PairingResult(
      pairs: pairs,
      round: round,
      byePlayers: byePlayer != null ? [byePlayer] : [],
    );
  }

  bool _findBestPairingDFS(
      List<MacmahonPlayer> unmatched,
      List<MacmahonPair> currentPairs,
      int currentCost,
      List<MacmahonPlayer> originalList) {
    
    // Pruning: 이미 찾은 최고 기록보다 벌점이 높으면 즉시 포기
    if (currentCost >= _bestCost) return false;

    // 모든 선수의 짝을 다 찾은 경우
    if (unmatched.isEmpty) {
      _bestCost = currentCost;
      _bestPairs = List.from(currentPairs);
      return true; // 일단 하나 찾았음
    }

    MacmahonPlayer p1 = unmatched[0];
    bool foundAny = false;

    for (int i = 1; i < unmatched.length; i++) {
      MacmahonPlayer p2 = unmatched[i];

      // 두 사람이 둔 적이 없다면 짝을 지어봄
      if (!p1.hasPlayedAgainst(p2.id)) {
        int pairCost = _calculateCost(p1, p2, originalList);
        
        final black = p1.currentMms >= p2.currentMms ? p1 : p2;
        final white = p1.currentMms >= p2.currentMms ? p2 : p1;
        
        currentPairs.add(MacmahonPair(black: black, white: white, cost: pairCost.toDouble()));
        
        List<MacmahonPlayer> remaining = List.from(unmatched)
          ..remove(p1)
          ..remove(p2);

        if (_findBestPairingDFS(remaining, currentPairs, currentCost + pairCost, originalList)) {
          foundAny = true;
        }

        currentPairs.removeLast();
      }
    }

    return foundAny;
  }

  int _calculateCost(MacmahonPlayer p1, MacmahonPlayer p2, List<MacmahonPlayer> originalList) {
    int cost = 0;
    
    // 1. MMS 차이 벌점 (1점 차이당 1000점)
    int mmsDiff = (p1.currentMms - p2.currentMms).abs().toInt();
    cost += mmsDiff * 1000;
    
    // 2. 거리 벌점 (원래 정렬된 리스트에서의 인덱스 차이)
    // 순위표 상에서 인접한 사람을 가장 강력하게 우선시 (가중치 100)
    int idx1 = originalList.indexOf(p1);
    int idx2 = originalList.indexOf(p2);
    cost += (idx1 - idx2).abs() * 100;

    // 3. 기세(History) 미세 벌점
    // 거리가 같을 경우, 부전승('B')과 자력승('W')을 구분하여 완벽히 똑같은 기세인 사람끼리 묶어줌 (가중치 10)
    if (p1.historyString != p2.historyString) {
      cost += 10;
    }
    
    return cost;
  }

  void _fallbackGreedyPairing(List<MacmahonPlayer> unmatched, List<MacmahonPair> pairs) {
    while (unmatched.length >= 2) {
      final p1 = unmatched.removeAt(0);
      int partnerIndex = 0;

      while (partnerIndex < unmatched.length && p1.hasPlayedAgainst(unmatched[partnerIndex].id)) {
        partnerIndex++;
      }

      if (partnerIndex == unmatched.length) {
        partnerIndex = 0; // 에러 방지용 강제 매칭
      }

      final p2 = unmatched.removeAt(partnerIndex);
      final black = p1.currentMms >= p2.currentMms ? p1 : p2;
      final white = p1.currentMms >= p2.currentMms ? p2 : p1;

      pairs.add(MacmahonPair(black: black, white: white, cost: 0.0));
    }
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
