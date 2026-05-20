import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/macmahon_provider.dart';

class GroupAssignmentScreen extends ConsumerWidget {
  const GroupAssignmentScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);
    final players = state.currentSectionPlayers;
    final groupCount = state.currentSectionData.groupCount;
    final groups = List.generate(groupCount, (i) => String.fromCharCode(65 + i));

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('조 편성 관리'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            onPressed: () => _confirmAutoAssign(context, ref),
            icon: const Icon(Icons.auto_awesome, size: 18),
            label: const Text('자동 편성'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primary.withValues(alpha: 0.05),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppTheme.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '총 $groupCount개 조로 편성합니다. 각 선수의 조를 직접 선택하거나 자동 편성 기능을 사용하세요.',
                        style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  children: groups.map((g) {
                    final count = players.where((p) => p.groupId == g).length;
                    return Chip(
                      label: Text('$g조: $count명'),
                      backgroundColor: Colors.white,
                      labelStyle: const TextStyle(fontSize: 12),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: players.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final player = players[index];
                return ListTile(
                  title: Text(
                    player.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('MMS: ${player.currentMms}'),
                  trailing: DropdownButton<String>(
                    value: player.groupId,
                    hint: const Text('조 미지정'),
                    underline: const SizedBox(),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('미지정'),
                      ),
                      ...groups.map(
                        (g) => DropdownMenuItem(
                          value: g,
                          child: Text('$g조'),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      ref.read(macmahonProvider.notifier).updatePlayerGroup(player.id, val);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }

  void _confirmAutoAssign(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('자동 조 편성'),
        content: const Text('조가 미지정된 선수들을 현재 설정된 조에 균등하게 자동 배정하시겠습니까?\n이미 조가 배정된 선수는 변경되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              ref.read(macmahonProvider.notifier).autoAssignGroups();
              Navigator.pop(ctx);
            },
            child: const Text('자동 편성 실행'),
          ),
        ],
      ),
    );
  }
}
