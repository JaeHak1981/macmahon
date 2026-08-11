import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/macmahon_entities.dart';
import '../providers/macmahon_provider.dart';
import '../../../../core/utils/macmahon_utils.dart';
import 'bracket_screen.dart';

class KnockoutSelectionScreen extends ConsumerStatefulWidget {
  const KnockoutSelectionScreen({super.key});

  @override
  ConsumerState<KnockoutSelectionScreen> createState() =>
      _KnockoutSelectionScreenState();
}

class _KnockoutSelectionScreenState
    extends ConsumerState<KnockoutSelectionScreen> {
  final Set<String> _selectedPlayerIds = {};
  List<MacmahonPlayer> _rankedPlayers = [];
  Map<String, int> _playerRanks = {};

  @override
  void initState() {
    super.initState();
    // 렌더링 전 데이터 초기화
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeData();
    });
  }

  void _initializeData() {
    final state = ref.read(macmahonProvider);
    final players = state.currentSectionPlayers;
    final sd = state.currentSectionData;

    _rankedPlayers = [];
    _playerRanks = {};
    MacmahonUtils.computeStandings(
      players,
      state.format,
      _rankedPlayers,
      _playerRanks,
    );

    // Initial selection: 조별 진출 인원(qualifiersPerGroup) 기준 적용
    _selectedPlayerIds.clear();
    if (sd.groupCount > 1) {
      final perGroup = sd.qualifiersPerGroup;
      final Map<String, List<MacmahonPlayer>> groupMap = {};

      for (final p in _rankedPlayers) {
        final gid = p.groupId ?? 'default';
        groupMap.putIfAbsent(gid, () => []).add(p);
      }

      for (final gid in groupMap.keys) {
        final groupPlayers = groupMap[gid]!;
        for (int i = 0; i < groupPlayers.length && i < perGroup; i++) {
          _selectedPlayerIds.add(groupPlayers[i].id);
        }
      }
    } else {
      // 기존 전체 순위 기반 선발 (조가 1개인 경우)
      final qualifierCount = sd.qualifierCount;
      for (int i = 0; i < _rankedPlayers.length && i < qualifierCount; i++) {
        _selectedPlayerIds.add(_rankedPlayers[i].id);
      }
    }
    setState(() {});
  }

  // 동률 여부 확인 (순위가 같은 다른 선수가 있는지)
  bool _isTied(String playerId, int rank) {
    return _rankedPlayers
        .where((p) => p.id != playerId && _playerRanks[p.id] == rank)
        .isNotEmpty;
  }

  // 커트라인 동률 경고 여부 확인
  bool _hasCutoffTie(int qualifierCount) {
    if (_rankedPlayers.length <= qualifierCount) return false;
    final cutoffRank = _playerRanks[_rankedPlayers[qualifierCount - 1].id] ?? 0;
    final nextRank = _playerRanks[_rankedPlayers[qualifierCount].id] ?? 0;
    return cutoffRank == nextRank;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedPlayerIds.contains(id)) {
        _selectedPlayerIds.remove(id);
      } else {
        _selectedPlayerIds.add(id);
      }
    });
  }

  void _confirmSelection() async {
    final state = ref.read(macmahonProvider);
    final qualifierCount = state.currentSectionData.qualifierCount;

    if (_selectedPlayerIds.length != qualifierCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '본선 진출자는 정확히 $qualifierCount명 선택해야 합니다. (현재 ${_selectedPlayerIds.length}명 선택됨)',
          ),
        ),
      );
      return;
    }

    // 1. 본선 스테이지 전환 및 선발 명단 저장
    ref
        .read(macmahonProvider.notifier)
        .startKnockoutStage(_selectedPlayerIds.toList());

    if (!mounted) return;

    // 2. 본선 대진표 화면으로 이동 (현재 화면을 대체)
    // 여기서 바로 generatePairing을 하지 않고, BracketScreen에서 자동/수동을 선택하게 함
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const BracketScreen()),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('본선 진출자가 선발되었습니다. 대진 방식을 선택해 주세요.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);
    final qualifierCount = state.currentSectionData.qualifierCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('본선 진출자 선발'),
        actions: [
          TextButton.icon(
            onPressed: _selectedPlayerIds.length == qualifierCount
                ? _confirmSelection
                : null,
            icon: Icon(
              Icons.check,
              color: _selectedPlayerIds.length == qualifierCount
                  ? Colors.white
                  : Colors.white54,
            ),
            label: Text(
              '선발 완료',
              style: TextStyle(
                color: _selectedPlayerIds.length == qualifierCount
                    ? Colors.white
                    : Colors.white54,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            color: Colors.blue.withValues(alpha: 0.1),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    '동률 또는 특수한 상황인 경우, 시스템이 추천한 진출자를 해제하고 수동으로 다른 선수를 선택할 수 있습니다.',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        '진출 인원: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      DropdownButton<int>(
                        value: qualifierCount,
                        underline: const SizedBox(),
                        isDense: true,
                        items: [2, 4, 8, 16, 32]
                            .map(
                              (val) => DropdownMenuItem(
                                value: val,
                                child: Text('$val명'),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) {
                            ref
                                .read(macmahonProvider.notifier)
                                .updateSectionSettings(qualifierCount: val);
                            // 인원수 변경 시 선택 상태 초기화 및 재설정
                            setState(() {
                              _selectedPlayerIds.clear();
                              for (
                                int i = 0;
                                i < _rankedPlayers.length && i < val;
                                i++
                              ) {
                                _selectedPlayerIds.add(_rankedPlayers[i].id);
                              }
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedPlayerIds.length == qualifierCount
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '선택: ${_selectedPlayerIds.length} / $qualifierCount 명',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _selectedPlayerIds.length == qualifierCount
                          ? Colors.green.shade900
                          : Colors.red.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _rankedPlayers.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    itemCount: _rankedPlayers.length,
                    itemBuilder: (context, index) {
                      final p = _rankedPlayers[index];
                      final rank = _playerRanks[p.id] ?? 0;
                      final isSelected = _selectedPlayerIds.contains(p.id);
                      final tied = _isTied(p.id, rank);

                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: isSelected
                              ? Colors.blue
                              : Colors.grey.shade300,
                          foregroundColor: isSelected
                              ? Colors.white
                              : Colors.black54,
                          child: Text('$rank'),
                        ),
                        title: Row(
                          children: [
                            Text(
                              p.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (tied)
                              Container(
                                margin: const EdgeInsets.only(left: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '동률',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        subtitle: Text(
                          '조: ${p.groupId ?? "전체"} | 승점: ${p.currentMms} | 승: ${p.wins} | SODOS: ${p.sodos}',
                        ),
                        trailing: Checkbox(
                          value: isSelected,
                          onChanged: (_) => _toggleSelection(p.id),
                        ),
                        onTap: () => _toggleSelection(p.id),
                        tileColor: isSelected
                            ? Colors.blue.withValues(alpha: 0.05)
                            : null,
                      );
                    },
                  ),
          ),
          if (_hasCutoffTie(qualifierCount))
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.orange.shade600,
              child: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '커트라인에 순위가 같은 선수가 있습니다. 추첨 결과를 반영하여 선수를 정확히 선택해 주세요.',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 하단 확정 버튼 추가
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _selectedPlayerIds.length == qualifierCount
                      ? _confirmSelection
                      : null,
                  icon: const Icon(Icons.check_circle),
                  label: const Text(
                    '선발 완료 및 본선 대진 생성',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
