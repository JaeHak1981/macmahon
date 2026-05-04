import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/macmahon_player.dart';
import '../providers/macmahon_provider.dart';
import '../utils/macmahon_utils.dart';

class KnockoutSelectionScreen extends ConsumerStatefulWidget {
  const KnockoutSelectionScreen({super.key});

  @override
  ConsumerState<KnockoutSelectionScreen> createState() => _KnockoutSelectionScreenState();
}

class _KnockoutSelectionScreenState extends ConsumerState<KnockoutSelectionScreen> {
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
    
    _rankedPlayers = [];
    _playerRanks = {};
    MacmahonUtils.computeStandings(players, state.format, _rankedPlayers, _playerRanks);

    // Initial selection: top N players based on qualifierCount
    final qualifierCount = state.currentSectionData.qualifierCount;
    for (int i = 0; i < _rankedPlayers.length && i < qualifierCount; i++) {
      _selectedPlayerIds.add(_rankedPlayers[i].id);
    }
    setState(() {});
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

  void _confirmSelection() {
    final state = ref.read(macmahonProvider);
    final qualifierCount = state.currentSectionData.qualifierCount;
    
    if (_selectedPlayerIds.length != qualifierCount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('본선 진출자는 정확히 $qualifierCount명 선택해야 합니다. (현재 ${_selectedPlayerIds.length}명 선택됨)')),
      );
      return;
    }

    ref.read(macmahonProvider.notifier).startKnockoutStage(_selectedPlayerIds.toList());
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('선택된 선수들로 본선 토너먼트가 시작되었습니다.')),
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
            onPressed: _selectedPlayerIds.length == qualifierCount ? _confirmSelection : null,
            icon: Icon(Icons.check, color: _selectedPlayerIds.length == qualifierCount ? Colors.white : Colors.white54),
            label: Text('본선 시작', style: TextStyle(color: _selectedPlayerIds.length == qualifierCount ? Colors.white : Colors.white54)),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? Colors.blue : Colors.grey.shade300,
                    foregroundColor: isSelected ? Colors.white : Colors.black54,
                    child: Text('$rank'),
                  ),
                  title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('조: ${p.groupId ?? "전체"} | MMS: ${p.currentMms} | 승: ${p.wins} | SODOS: ${p.sodos}'),
                  trailing: Checkbox(
                    value: isSelected,
                    onChanged: (_) => _toggleSelection(p.id),
                  ),
                  onTap: () => _toggleSelection(p.id),
                  tileColor: isSelected ? Colors.blue.withValues(alpha: 0.05) : null,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
