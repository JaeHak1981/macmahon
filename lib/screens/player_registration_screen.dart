import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_player.dart';
import '../providers/macmahon_provider.dart';

class PlayerRegistrationScreen extends ConsumerStatefulWidget {
  const PlayerRegistrationScreen({super.key});

  @override
  ConsumerState<PlayerRegistrationScreen> createState() =>
      _PlayerRegistrationScreenState();
}

class _PlayerRegistrationScreenState
    extends ConsumerState<PlayerRegistrationScreen> {
  final _nameController = TextEditingController();
  final _mmsController = TextEditingController(text: '0');
  bool _isTopBar = false;

  @override
  void dispose() {
    _nameController.dispose();
    _mmsController.dispose();
    super.dispose();
  }

  void _addPlayer() {
    final name = _nameController.text.trim();
    final mms = double.tryParse(_mmsController.text) ?? 0.0;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('선수 이름을 입력하세요.')),
      );
      return;
    }
    final player = MacmahonPlayer(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      initialMms: mms,
      currentMms: mms,
      isTopBar: _isTopBar,
    );
    ref.read(macmahonProvider.notifier).addPlayer(player);
    _nameController.clear();
    _mmsController.text = '0';
    setState(() => _isTopBar = false);
  }

  @override
  Widget build(BuildContext context) {
    final players = ref.watch(macmahonProvider).players;

    return Scaffold(
      appBar: AppBar(
        title: Text('선수 등록 (${players.length}명)'),
      ),
      body: Column(
        children: [
          // ── 입력 폼 ───────────────────────────────────
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: '이름',
                          prefixIcon: Icon(Icons.person),
                        ),
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _mmsController,
                        decoration: const InputDecoration(
                          labelText: '초기 MMS',
                          prefixIcon: Icon(Icons.stairs),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Checkbox(
                      value: _isTopBar,
                      activeColor: AppTheme.primary,
                      onChanged: (v) => setState(() => _isTopBar = v ?? false),
                    ),
                    const Text('Top Bar 이상 (안티그래비티 제외)'),
                  ],
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _addPlayer,
                  icon: const Icon(Icons.add),
                  label: const Text('선수 추가'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (players.isNotEmpty) _RecommendationCard(playerCount: players.length),
          
          const Divider(height: 1),

          // ── 선수 목록 ─────────────────────────────────
          Expanded(
            child: players.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline,
                            size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('등록된 선수가 없습니다.',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: players.length,
                    onReorder: (_, __) {}, // 순서 변경은 MMS로 자동 정렬
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return _PlayerTile(
                        key: ValueKey(player.id),
                        player: player,
                        rank: index + 1,
                        onDelete: () => ref
                            .read(macmahonProvider.notifier)
                            .removePlayer(player.id),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final MacmahonPlayer player;
  final int rank;
  final VoidCallback onDelete;

  const _PlayerTile({
    super.key,
    required this.player,
    required this.rank,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary,
          child: Text(
            '$rank',
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Text(player.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            if (player.isTopBar) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('Top Bar',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ],
        ),
        subtitle: Text('MMS: ${player.currentMms}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // floatHistory 시각화
            if (player.floatHistory.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: (() {
                  final h = player.floatHistory;
                  final recent = h.length > 5 ? h.sublist(h.length - 5) : h;
                  return recent.map((f) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: f == 1
                          ? AppTheme.floatUp
                          : f == -1
                              ? AppTheme.floatDown
                              : Colors.grey,
                    ),
                  )).toList();
                })(),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
class _RecommendationCard extends StatelessWidget {
  final int playerCount;
  const _RecommendationCard({required this.playerCount});

  @override
  Widget build(BuildContext context) {
    // 권장 라운드 수 계산: ceil(log2(N))
    final recommendedRounds = playerCount < 2 ? 0 : (math.log(playerCount) / math.log(2)).ceil();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppTheme.primary.withValues(alpha: 0.05),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '선수 $playerCount명 기준 권장 라운드 수는 $recommendedRounds라운드입니다.',
              style: const TextStyle(
                color: AppTheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
