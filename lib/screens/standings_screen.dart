import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_player.dart';
import '../providers/macmahon_provider.dart';

class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);

    // MMS > SOS > SODOS > 승수 기준 내림차순 정렬
    final sorted = [...state.players]
      ..sort((a, b) {
        // 1. MMS
        final mmsCmp = b.currentMms.compareTo(a.currentMms);
        if (mmsCmp != 0) return mmsCmp;
        // 2. SOS
        final sosCmp = b.sos.compareTo(a.sos);
        if (sosCmp != 0) return sosCmp;
        // 3. SODOS
        final sodosCmp = b.sodos.compareTo(a.sodos);
        if (sodosCmp != 0) return sodosCmp;
        // 4. 승수
        return b.wins.compareTo(a.wins);
      });

    return Scaffold(
      appBar: AppBar(
        title: Text(state.tournamentName.isNotEmpty 
            ? '${state.tournamentName} - 순위표' 
            : '순위표 (${state.currentRound - 1}라운드 완료)'),
      ),
      body: sorted.isEmpty
          ? const Center(
              child: Text('선수가 없습니다.',
                  style: TextStyle(color: Colors.grey)),
            )
          : Column(
              children: [
                // ── 범례 ────────────────────────────────
                Container(
                  color: AppTheme.surface,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: const [
                      SizedBox(width: 40),
                      SizedBox(
                          width: 120,
                          child: Text('이름',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary,
                                  fontSize: 12))),
                      Spacer(),
                      _HeaderCell('MMS'),
                      _HeaderCell('SOS'),
                      _HeaderCell('승'),
                      _HeaderCell('패'),
                    ],
                  ),
                ),
                const Divider(height: 1),

                // ── 순위 목록 ──────────────────────────
                Expanded(
                  child: ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, index) {
                      final player = sorted[index];
                      final isTopThree = index < 3;
                      return _StandingsTile(
                        rank: index + 1,
                        player: player,
                        isTopThree: isTopThree,
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Text(text,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              fontSize: 12)),
    );
  }
}

class _StandingsTile extends StatelessWidget {
  final int rank;
  final MacmahonPlayer player;
  final bool isTopThree;

  const _StandingsTile({
    required this.rank,
    required this.player,
    required this.isTopThree,
  });

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // 금
      case 2:
        return const Color(0xFFC0C0C0); // 은
      case 3:
        return const Color(0xFFCD7F32); // 동
      default:
        return AppTheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isTopThree
            ? _rankColor.withValues(alpha: 0.07)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTopThree ? _rankColor.withValues(alpha: 0.4) : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 순위 배지
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _rankColor,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '$rank',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // 이름 + 배지들
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(player.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isTopThree
                                ? AppTheme.textPrimary
                                : AppTheme.textPrimary,
                          )),
                      if (player.isTopBar) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Top',
                              style: TextStyle(fontSize: 9)),
                        ),
                      ],
                    ],
                  ),
                  // floatHistory 점 시각화
                  if (player.floatHistory.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: player.floatHistory
                            .map((f) => Container(
                                  margin:
                                      const EdgeInsets.only(right: 3),
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
                                ))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),

            // 성적
            _ScoreCell(
                value: player.currentMms.toStringAsFixed(1),
                bold: true,
                color: AppTheme.primary),
            _ScoreCell(
                value: player.sos.toStringAsFixed(1),
                color: AppTheme.textSecondary),
            _ScoreCell(value: '${player.wins}', color: Colors.green),
            _ScoreCell(value: '${player.losses}', color: Colors.red),
          ],
        ),
      ),
    );
  }
}

class _ScoreCell extends StatelessWidget {
  final String value;
  final bool bold;
  final Color color;
  const _ScoreCell(
      {required this.value, this.bold = false, required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color,
          fontSize: bold ? 15 : 14,
        ),
      ),
    );
  }
}
