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
    workingList.sort((a, b) => b.currentMms.compareTo(a.currentMms));

    if (workingList.length % 2 != 0) {
      final dummy = _createDummyPlayer(workingList);
      workingList.add(dummy);
      workingList.sort((a, b) => b.currentMms.compareTo(a.currentMms));
    }

    final int n = workingList.length;
    final int m = n ~/ 2;

    final List<MacmahonPlayer> leftSide = [];
    final List<MacmahonPlayer> rightSide = [];
    for (int i = 0; i < n; i++) {
      if (i % 2 == 0) {
        leftSide.add(workingList[i]);
      } else {
        rightSide.add(workingList[i]);
      }
    }

    final costMatrix = List.generate(
      m,
      (i) => List.generate(m, (j) => CostMatrixBuilder.calculateCost(leftSide[i], rightSide[j])),
    );

    final matchedIndices = HungarianSolver.solve(costMatrix);

    final List<MacmahonPair> pairs = [];
    MacmahonPlayer? byePlayer;

    for (final pairIdx in matchedIndices) {
      final i = pairIdx.$1;
      final j = pairIdx.$2;
      final playerA = leftSide[i];
      final playerB = rightSide[j];

      if (playerA.id == _kDummyId) {
        byePlayer = playerB;
        continue;
      }
      if (playerB.id == _kDummyId) {
        byePlayer = playerA;
        continue;
      }

      final MacmahonPlayer black;
      final MacmahonPlayer white;
      if (playerA.currentMms >= playerB.currentMms) {
        black = playerA;
        white = playerB;
      } else {
        black = playerB;
        white = playerA;
      }

      pairs.add(MacmahonPair(
        black: black,
        white: white,
        cost: costMatrix[i][j],
      ));
    }

    return PairingResult(
      pairs: pairs,
      round: round,
      byePlayers: byePlayer != null ? [byePlayer] : [],
    );
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
    sorted.sort((a, b) => b.currentMms.compareTo(a.currentMms));

    int n = sorted.length;
    MacmahonPlayer? byePlayer;

    if (n % 2 != 0) {
      byePlayer = sorted.last;
    }

    final List<MacmahonPlayer> remaining = byePlayer != null 
        ? sorted.sublist(0, n - 1) 
        : sorted;

    final List<MacmahonPair> pairs = [];
    final int matchesCount = remaining.length ~/ 2;
    for (int i = 0; i < matchesCount; i++) {
      final p1 = remaining[i];
      final p2 = remaining[remaining.length - 1 - i];
      
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
