import 'dart:math';
import '../entities/macmahon_entities.dart';
import '../entities/tournament_state.dart';

class AssignGroupsUseCase {
  /// 미지정 선수를 인원수가 균형 잡히도록 조에 자동 배정합니다.
  MacmahonState execute(MacmahonState state) {
    final currentData = state.currentSectionData;
    final groupCount = currentData.groupCount;
    if (groupCount <= 1) return state;

    final players = state.currentSectionPlayers;
    final updated = List<MacmahonPlayer>.from(state.players);

    // 현재 섹션의 미지정 선수들
    final unassigned =
        players.where((p) => p.groupId == null || p.groupId!.isEmpty).toList()
          ..shuffle();

    // 현재 조별 인원수 계산
    final groupCounts = <String, int>{};
    for (int i = 0; i < groupCount; i++) {
      groupCounts[String.fromCharCode(65 + i)] = 0;
    }

    for (final p in players) {
      if (p.groupId != null &&
          p.groupId!.isNotEmpty &&
          groupCounts.containsKey(p.groupId)) {
        groupCounts[p.groupId!] = groupCounts[p.groupId!]! + 1;
      }
    }

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

    return state.copyWith(players: updated);
  }
}
