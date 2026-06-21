import '../entities/macmahon_entities.dart';
import 'cost_matrix_builder.dart';
import 'hungarian_solver.dart';

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

    // 2. 다중 이분 분할 (Fallback Splits) 매칭
    // 1차 시도 (Slide 분할 - 스위스 리그 기본 방식)
    List<MacmahonPair> bestMatches = _attemptMatching(workingList, 'slide');
    double bestCost = bestMatches.fold(0.0, (sum, p) => sum + p.cost);

    // 10000점(재대결 패널티) 이상일 경우 2차 시도
    if (bestCost >= 10000) {
      // 2차 시도 (Fold 분할)
      List<MacmahonPair> foldMatches = _attemptMatching(workingList, 'fold');
      double foldCost = foldMatches.fold(0.0, (sum, p) => sum + p.cost);

      if (foldCost < bestCost) {
        bestMatches = foldMatches;
      }
    }

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

  List<MacmahonPair> _attemptMatching(List<MacmahonPlayer> players, String splitType) {
    final int m = players.length ~/ 2;
    final List<MacmahonPlayer> leftSide = [];
    final List<MacmahonPlayer> rightSide = [];

    // 1. 점수(MMS)별로 그룹화
    final Map<double, List<MacmahonPlayer>> mmsGroups = {};
    for (var p in players) {
      mmsGroups.putIfAbsent(p.currentMms, () => []).add(p);
    }
    
    // 점수 내림차순 정렬
    final sortedMms = mmsGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    
    List<MacmahonPlayer> currentGroup = [];
    for (int i = 0; i < sortedMms.length; i++) {
      currentGroup.addAll(mmsGroups[sortedMms[i]]!);
      
      // 그룹 인원수가 홀수면 마지막 1명을 다음 점수 그룹으로 이월 (Float Down)
      if (currentGroup.length % 2 != 0 && i < sortedMms.length - 1) {
        final floater = currentGroup.removeLast();
        mmsGroups[sortedMms[i+1]]!.insert(0, floater);
      }
      
      // 이제 currentGroup은 짝수 명
      if (currentGroup.length % 2 == 0 && currentGroup.isNotEmpty) {
        int groupM = currentGroup.length ~/ 2;
        if (splitType == 'slide') {
          // Slide: 1등-중간1등, 2등-중간2등 (상/하위 밀기) - 스위스 기본
          for (int j = 0; j < groupM; j++) {
            leftSide.add(currentGroup[j]);
            rightSide.add(currentGroup[groupM + j]);
          }
        } else if (splitType == 'fold') {
          // Fold: 1등-꼴등, 2등-뒤에서2등 (상/하위 접기)
          for (int j = 0; j < groupM; j++) {
            leftSide.add(currentGroup[j]);
            rightSide.add(currentGroup[currentGroup.length - 1 - j]);
          }
        } else {
          // Adjacent: 1등-2등, 3등-4등
          for (int j = 0; j < currentGroup.length; j++) {
            if (j % 2 == 0) leftSide.add(currentGroup[j]);
            else rightSide.add(currentGroup[j]);
          }
        }
        currentGroup.clear();
      }
    }
    
    // 마지막 그룹에서 남은 인원 처리 방어코드
    if (currentGroup.isNotEmpty) {
      int groupM = currentGroup.length ~/ 2;
      for (int j = 0; j < groupM; j++) {
        leftSide.add(currentGroup[j]);
        rightSide.add(currentGroup[groupM + j]);
      }
    }

    final costMatrix = List.generate(
      m, (i) => List.generate(m, (j) => CostMatrixBuilder.calculateCost(leftSide[i], rightSide[j]))
    );
    final matchedIndices = HungarianSolver.solve(costMatrix);
    
    final List<MacmahonPair> pairs = [];
    for (final pairIdx in matchedIndices) {
      final pA = leftSide[pairIdx.$1];
      final pB = rightSide[pairIdx.$2];
      
      final black = pA.currentMms >= pB.currentMms ? pA : pB;
      final white = pA.currentMms >= pB.currentMms ? pB : pA;
      
      pairs.add(MacmahonPair(
        black: black,
        white: white,
        cost: costMatrix[pairIdx.$1][pairIdx.$2],
      ));
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

  MacmahonPlayer _createDummyPlayer(List<MacmahonPlayer> players) {
    final lowestMms =
        players.map((p) => p.currentMms).reduce((a, b) => a < b ? a : b);
    return MacmahonPlayer(
      id: _kDummyId,
      name: 'BYE',
      initialMms: lowestMms - 1,
      currentMms: lowestMms - 1,
    );
  }
}
