import '../../domain/entities/tournament_state.dart';
import '../../../../core/constants/tournament_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/macmahon_provider.dart';
import 'tournament_dashboard_screen.dart';
import '../providers/history_provider.dart';

class SectionManagementScreen extends ConsumerWidget {
  const SectionManagementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          state.tournamentName,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined, color: AppTheme.primary),
            onPressed: () => _confirmExit(context, ref),
            tooltip: '메인 화면으로 나가기',
          ),
          IconButton(
            icon: const Icon(Icons.edit_note, color: AppTheme.textSecondary),
            onPressed: () => _showTournamentInfoDialog(context, ref, state),
            tooltip: '대회 정보 수정',
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.redAccent),
            onPressed: () => _confirmReset(context, ref),
            tooltip: '대회 초기화',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on_outlined, size: 16, color: AppTheme.textSecondary),
                const SizedBox(width: 4),
                Text(
                  '${state.tournamentDate} | ${state.tournamentLocation}',
                  style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              '참가 부 관리',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              '관리할 부를 선택하거나 새로운 부를 추가하세요.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 250,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1,
                ),
                itemCount: state.sections.length + 1,
                itemBuilder: (context, index) {
                  if (index == state.sections.length) {
                    return _AddSectionCard(onTap: () => _showAddSectionDialog(context, ref));
                  }
                  final sectionName = state.sections[index];
                  final sectionData = state.sectionData[sectionName]!;
                  final players = state.players.where((p) => p.section == sectionName).toList();

                  return _SectionCard(
                    name: sectionName,
                    playerCount: players.length,
                    round: sectionData.currentRound,
                    format: sectionData.format,
                    isFinished: sectionData.isFinished,
                    onTap: () {
                      ref.read(macmahonProvider.notifier).selectSection(sectionName);
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const TournamentDashboardScreen()),
                      );
                    },
                    onDelete: () => _confirmDeleteSection(context, ref, sectionName),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddSectionDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 참가 부 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '부 이름 (예: 꿈나무부)',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(macmahonProvider.notifier).addSection(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteSection(BuildContext context, WidgetRef ref, String sectionName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('부 삭제'),
        content: Text('[$sectionName] 부와 해당 부의 모든 선수 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(macmahonProvider.notifier).removeSection(sectionName);
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }

  void _confirmExit(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('홈 화면으로 이동'),
        content: const Text('현재 대회를 저장하고 메인 화면으로 나가시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final notifier = ref.read(macmahonProvider.notifier);
              await notifier.startNewTournament();
              ref.read(tournamentHistoryProvider.notifier).loadHistory();
              if (context.mounted) Navigator.pop(ctx);
            },
            child: const Text('나가기'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 초기화'),
        content: const Text('현재 대회의 모든 부와 선수 기록이 삭제됩니다. 정말 초기화하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(macmahonProvider.notifier).startNewTournament();
              Navigator.pop(ctx);
            },
            child: const Text('전체 초기화'),
          ),
        ],
      ),
    );
  }

  void _showTournamentInfoDialog(BuildContext context, WidgetRef ref, MacmahonState state) {
    final nameController = TextEditingController(text: state.tournamentName);
    final dateController = TextEditingController(text: state.tournamentDate);
    final locationController = TextEditingController(text: state.tournamentLocation);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 정보 설정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: '대회명')),
            TextField(controller: dateController, decoration: const InputDecoration(labelText: '날짜')),
            TextField(controller: locationController, decoration: const InputDecoration(labelText: '장소')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              ref.read(macmahonProvider.notifier).updateTournamentInfo(
                name: nameController.text.trim(),
                date: dateController.text.trim(),
                location: locationController.text.trim(),
              );
              ref.read(macmahonProvider.notifier).saveCurrentTournament();
              ref.read(tournamentHistoryProvider.notifier).loadHistory();
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String name;
  final int playerCount;
  final int round;
  final TournamentFormat format;
  final bool isFinished;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SectionCard({
    required this.name,
    required this.playerCount,
    required this.round,
    required this.format,
    required this.isFinished,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formatName(format),
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SmallStat(
                        icon: Icons.people,
                        label: playerCount > 0 ? '$playerCount명' : '0명',
                      ),
                      const SizedBox(width: 12),
                      _SmallStat(
                        icon: Icons.play_circle_outline,
                        label: round > 0 ? '${round}R 진행' : '준비 중',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                onPressed: onDelete,
              ),
            ),
            if (isFinished)
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '종료',
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatName(TournamentFormat format) {
    switch (format) {
      case TournamentFormat.undecided: return '방식 미정';
      case TournamentFormat.macmahon: return '맥마흔 (스위스)';
      case TournamentFormat.league: return '풀리그';
      case TournamentFormat.knockout: return '토너먼트';
      case TournamentFormat.doubleElimination: return '더블 일리미네이션';
      case TournamentFormat.leagueAndKnockout: return '혼합 (리그+토너)';
    }
  }
}

class _SmallStat extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SmallStat({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _AddSectionCard extends StatelessWidget {
  final VoidCallback onTap;
  const _AddSectionCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.shade200, style: BorderStyle.none),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline, size: 40, color: Colors.grey.shade400),
            const SizedBox(height: 8),
            Text(
              '부 추가',
              style: TextStyle(color: Colors.grey.shade500, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
