import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../providers/macmahon_provider.dart';
import 'player_registration_screen.dart';
import 'pairing_screen.dart';
import 'standings_screen.dart';
import 'round_history_screen.dart';
import '../providers/history_provider.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(state.tournamentName.isEmpty ? '맥마흔 시스템' : state.tournamentName),
        actions: [
          IconButton(
            tooltip: '대회 정보 수정',
            icon: const Icon(Icons.edit_note),
            onPressed: () => _showTournamentInfoDialog(context, ref, state),
          ),
          if (state.history.isNotEmpty)
            IconButton(
              tooltip: '라운드 취소 (Undo)',
              icon: const Icon(Icons.undo),
              onPressed: () => _confirmUndo(context, ref),
            ),
          if (state.players.isNotEmpty)
            IconButton(
              tooltip: '대회 초기화',
              icon: const Icon(Icons.refresh),
              onPressed: () => _confirmReset(context, ref),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 대회 상태 카드 ────────────────────────────
            _TournamentStatusCard(state: state),
            const SizedBox(height: 16),

            // ── 메뉴 버튼들 ───────────────────────────────
            _MenuButton(
              icon: Icons.people,
              label: '선수 등록 / 관리',
              subtitle: '${state.players.length}명 등록됨',
              color: AppTheme.primary,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const PlayerRegistrationScreen()),
              ),
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.swap_horiz,
              label: '라운드 ${state.currentRound} 페어링',
              subtitle: state.currentPairing == null
                  ? '페어링 생성 전'
                  : '${state.currentPairs.length}경기 확정',
              color: AppTheme.primaryLight,
              onTap: state.players.length >= 2
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const PairingScreen()),
                      )
                  : null,
            ),
            const SizedBox(height: 12),
            _MenuButton(
              icon: Icons.leaderboard,
              label: '순위표',
              subtitle: 'MMS 기준 현재 순위',
              color: const Color(0xFF5D4037),
              onTap: state.players.isNotEmpty
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const StandingsScreen()),
                      )
                  : null,
            ),
            _MenuButton(
              icon: Icons.history_edu,
              label: '라운드 기록',
              subtitle: '지난 라운드 대진 및 결과',
              color: const Color(0xFF607D8B),
              onTap: state.history.isNotEmpty
                  ? () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const RoundHistoryScreen()),
                      )
                  : null,
            ),
            const SizedBox(height: 24),

            // ── 이번 라운드 대진 미리보기 ─────────────────
            if (state.currentPairing != null) ...[
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  '이번 라운드 대진',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ...state.currentPairs.map((pair) => _PairPreviewTile(
                    black: pair.black.name,
                    white: pair.white.name,
                    mmsDiff: pair.mmsDiff,
                  )),
              if (state.byePlayer != null)
                _ByeTile(playerName: state.byePlayer!.name),
            ],

            const SizedBox(height: 32),
            const _HistorySection(),
          ],
        ),
      ),
    );
  }

  void _showTournamentInfoDialog(
      BuildContext context, WidgetRef ref, MacmahonState state) {
    final nameController = TextEditingController(text: state.tournamentName);
    final dateController = TextEditingController(text: state.tournamentDate);
    final locationController =
        TextEditingController(text: state.tournamentLocation);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 정보 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                    labelText: '대회명', hintText: '예: 제1회 맥마흔 바둑대회'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                    labelText: '날짜', hintText: '예: 2024-03-20'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                    labelText: '장소', hintText: '예: 한국기원'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              ref.read(macmahonProvider.notifier).updateTournamentInfo(
                    name: nameController.text.trim(),
                    date: dateController.text.trim(),
                    location: locationController.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _confirmUndo(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('라운드 취소'),
        content: const Text('마지막 라운드 결과를 취소하고 이전 상태로 되돌리겠습니까?\n이 작업은 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              ref.read(macmahonProvider.notifier).undoLastRound();
              Navigator.pop(ctx);
            },
            child: const Text('라운드 취소 실행'),
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
        content: const Text('모든 데이터가 삭제됩니다. 초기화하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(macmahonProvider.notifier).resetTournament();
              Navigator.pop(ctx);
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

// ── 위젯: 대회 상태 카드 ────────────────────────────────────
class _TournamentStatusCard extends StatelessWidget {
  final MacmahonState state;
  const _TournamentStatusCard({required this.state});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.primary,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (state.tournamentDate.isNotEmpty ||
                state.tournamentLocation.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (state.tournamentDate.isNotEmpty) ...[
                      const Icon(Icons.calendar_today,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(state.tournamentDate,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                    if (state.tournamentDate.isNotEmpty &&
                        state.tournamentLocation.isNotEmpty)
                      const Text(' | ',
                          style: TextStyle(color: Colors.white38)),
                    if (state.tournamentLocation.isNotEmpty) ...[
                      const Icon(Icons.location_on,
                          color: Colors.white70, size: 14),
                      const SizedBox(width: 4),
                      Text(state.tournamentLocation,
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13)),
                    ],
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _StatItem(
                  label: '선수',
                  value: '${state.players.length}명',
                  icon: Icons.people,
                ),
                _StatItem(
                  label: '라운드',
                  value: '${state.currentRound}R',
                  subtitle: '(권장: ${state.recommendedRounds}R)',
                  icon: Icons.flag,
                ),
                _StatItem(
                  label: '완료 라운드',
                  value: '${state.history.length}R',
                  icon: Icons.check_circle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final IconData icon;
  const _StatItem(
      {required this.label, required this.value, this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 6),
        Text(value,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold)),
        if (subtitle != null)
          Text(subtitle!,
              style: const TextStyle(color: Colors.white, fontSize: 10)),
        Text(label,
            style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }
}

// ── 위젯: 메뉴 버튼 ─────────────────────────────────────────
class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 13)),
                  ],
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Colors.white70),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 위젯: 대진 미리보기 ──────────────────────────────────────
class _PairPreviewTile extends StatelessWidget {
  final String black;
  final String white;
  final double mmsDiff;
  const _PairPreviewTile(
      {required this.black, required this.white, required this.mmsDiff});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _StoneChip(label: '흑', isBlack: true),
            const SizedBox(width: 8),
            Text(black,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            const Text('vs',
                style: TextStyle(color: AppTheme.textSecondary)),
            const Spacer(),
            Text(white,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            _StoneChip(label: '백', isBlack: false),
            if (mmsDiff > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.floatDown.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '±${mmsDiff.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: AppTheme.floatDown,
                      fontSize: 11,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoneChip extends StatelessWidget {
  final String label;
  final bool isBlack;
  const _StoneChip({required this.label, required this.isBlack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isBlack ? AppTheme.black : AppTheme.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: [
          BoxShadow(
              color: Colors.black26,
              blurRadius: 2,
              offset: const Offset(1, 1))
        ],
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isBlack ? Colors.white : Colors.black54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

// ── 위젯: 부전승 타일 ────────────────────────────────────────
class _ByeTile extends StatelessWidget {
  final String playerName;
  const _ByeTile({required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      color: AppTheme.byeColor.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            const Icon(Icons.airline_seat_flat,
                color: AppTheme.byeColor, size: 20),
            const SizedBox(width: 8),
            Text(playerName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            const Text('부전승',
                style: TextStyle(
                    color: AppTheme.byeColor, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
// ── 위젯: 기존 기록 섹션 ──────────────────────────────────
class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(tournamentHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '최근 대회 기록',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary,
            ),
          ),
        ),
        historyAsync.when(
          data: (tournaments) {
            if (tournaments.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text('저장된 기록이 없습니다.',
                      style: TextStyle(color: AppTheme.textSecondary)),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final t = tournaments[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade200)),
                  leading: const Icon(Icons.history, color: AppTheme.primary),
                  title: Text(t.tournamentName,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${t.tournamentDate} | ${t.players.length}명 참여'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                        onPressed: () => _confirmDelete(context, ref, t),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => _loadTournament(context, ref, t),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Text('로딩 오류: $e'),
        ),
      ],
    );
  }

  void _loadTournament(BuildContext context, WidgetRef ref, MacmahonState state) {
    ref.read(macmahonProvider.notifier).loadState(state);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${state.tournamentName} 기록을 불러왔습니다.')),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, MacmahonState state) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('[${state.tournamentName}] 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(tournamentHistoryProvider.notifier).deleteTournament(
                    state.tournamentName,
                    state.tournamentDate,
                  );
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}
