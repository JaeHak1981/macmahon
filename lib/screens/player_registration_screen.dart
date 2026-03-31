import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_player.dart';
import '../providers/macmahon_provider.dart';
import '../services/export_service.dart';
import '../providers/history_provider.dart';

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
    final state = ref.read(macmahonProvider);
    final player = MacmahonPlayer(
      id: '${DateTime.now().millisecondsSinceEpoch}_${state.players.length}_$name',
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
        actions: [
          IconButton(
            tooltip: '엑셀에서 가져오기',
            icon: const Icon(Icons.file_upload),
            onPressed: () => _importFromExcel(context, ref),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
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
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _addPlayer,
                        icon: const Icon(Icons.add),
                        label: const Text('선수 추가'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                        ),
                        onPressed: () async {
                          await ref.read(macmahonProvider.notifier).saveCurrentTournament();
                          ref.read(tournamentHistoryProvider.notifier).loadHistory();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('선수 명단/대회 정보가 저장되었습니다.')),
                            );
                          }
                        },
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('명단 저장'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (players.isNotEmpty) const _RecommendationCard(),
          
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
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: players.length,
                    itemBuilder: (context, index) {
                      final player = players[index];
                      return _PlayerTile(
                        key: ValueKey(player.id),
                        player: player,
                        rank: index + 1,
                        onDelete: () => ref
                            .read(macmahonProvider.notifier)
                            .removePlayer(player.id),
                        onEdit: () => _editPlayerName(context, player, ref.read(macmahonProvider.notifier)),
                      );
                    },
                  ),
          ),
        ],
      ),
            ),
          ),
        ),
    );
  }

  void _editPlayerName(BuildContext context, MacmahonPlayer player, MacmahonNotifier notifier) {
    final controller = TextEditingController(text: player.name);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('선수 이름 수정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '이름',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
          onSubmitted: (val) {
            notifier.updatePlayerName(player.id, val);
            Navigator.pop(context);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              notifier.updatePlayerName(player.id, controller.text);
              Navigator.pop(context);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  Future<void> _importFromExcel(BuildContext context, WidgetRef ref) async {
    try {
      final importedPlayers = await ExportService.importPlayersFromExcel();
      if (importedPlayers.isNotEmpty) {
        ref.read(macmahonProvider.notifier).addPlayers(importedPlayers);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${importedPlayers.length}명의 선수를 가져왔습니다.')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('가져오기 실패: $e')),
        );
      }
    }
  }
}

class _PlayerTile extends StatelessWidget {
  final MacmahonPlayer player;
  final int rank;
  final VoidCallback onDelete;
  final VoidCallback onEdit;

  const _PlayerTile({
    super.key,
    required this.player,
    required this.rank,
    required this.onDelete,
    required this.onEdit,
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
              icon: const Icon(Icons.edit, color: AppTheme.textSecondary),
              onPressed: onEdit,
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
class _RecommendationCard extends ConsumerWidget {
  const _RecommendationCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);
    final playerCount = state.players.length;
    final recommendedRounds = state.recommendedRounds;

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
