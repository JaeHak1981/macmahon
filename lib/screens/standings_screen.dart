import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_player.dart';
import '../models/macmahon_pair.dart';
import '../providers/macmahon_provider.dart';
import '../services/export_service.dart';

class StandingsScreen extends ConsumerWidget {
  const StandingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);

    // MMS > SOS > SODOS > 승자승 > 초기 MMS > 승수 기준 내림차순 정렬
    final sorted = [...state.players]..sort(_comparePlayers);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(state.tournamentName.isNotEmpty
              ? '${state.tournamentName} - 결과'
              : '대회 결과'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '순위표', icon: Icon(Icons.format_list_numbered)),
              Tab(text: '결과표 (Grid)', icon: Icon(Icons.grid_on)),
            ],
            indicatorColor: AppTheme.primary,
            labelColor: AppTheme.primary,
            unselectedLabelColor: AppTheme.textSecondary,
          ),
          actions: [
            IconButton(
              tooltip: '엑셀로 내보내기',
              icon: const Icon(Icons.file_download),
              onPressed: () => _exportToExcel(context, sorted, state.tournamentName),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _RankingsTab(sorted: sorted),
            _ResultGridTab(state: state, sorted: sorted),
          ],
        ),
      ),
    );
  }

  int _comparePlayers(MacmahonPlayer a, MacmahonPlayer b) {
    // 1. MMS
    final mmsCmp = b.currentMms.compareTo(a.currentMms);
    if (mmsCmp != 0) return mmsCmp;
    // 2. SOS
    final sosCmp = b.sos.compareTo(a.sos);
    if (sosCmp != 0) return sosCmp;
    // 3. SODOS
    final sodosCmp = b.sodos.compareTo(a.sodos);
    if (sodosCmp != 0) return sodosCmp;

    // 4. 승자승 (Direct Encounter)
    if (a.defeatedOpponents.contains(b.id)) return -1; // a가 b를 이김 -> a가 상위
    if (b.defeatedOpponents.contains(a.id)) return 1; // b가 a를 이김 -> b가 상위

    // 5. 초기 MMS (Initial Rank)
    final initCmp = b.initialMms.compareTo(a.initialMms);
    if (initCmp != 0) return initCmp;

    // 6. 승수
    return b.wins.compareTo(a.wins);
  }

  Future<void> _exportToExcel(BuildContext context, List<MacmahonPlayer> sorted, String tournamentName) async {
    try {
      final path = await ExportService.exportToExcel(
          sorted, tournamentName.isEmpty ? 'macmahon_tournament' : tournamentName);
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('엑셀 파일이 저장되었습니다: $path')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('내보내기 실패: $e')),
        );
      }
    }
  }
}

class _RankingsTab extends StatelessWidget {
  final List<MacmahonPlayer> sorted;
  const _RankingsTab({required this.sorted});

  @override
  Widget build(BuildContext context) {
    if (sorted.isEmpty) {
      return const Center(child: Text('선수가 없습니다.', style: TextStyle(color: Colors.grey)));
    }

    return Column(
      children: [
        // ── 범례 ────────────────────────────────
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
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

              // 공동 순위 계산 (1, 1, 3...)
              int displayRank = 1;
              if (index > 0) {
                for (int i = index; i > 0; i--) {
                  final p1 = sorted[i];
                  final p2 = sorted[i - 1];

                  bool isSame = p1.currentMms == p2.currentMms &&
                      p1.sos == p2.sos &&
                      p1.sodos == p2.sodos &&
                      !p1.defeatedOpponents.contains(p2.id) &&
                      !p2.defeatedOpponents.contains(p1.id) &&
                      p1.initialMms == p2.initialMms &&
                      p1.wins == p2.wins;

                  if (!isSame) {
                    displayRank = i + 1;
                    break;
                  }
                }
              }

              final isTopThree = displayRank <= 3;
              return _StandingsTile(
                rank: displayRank,
                player: player,
                isTopThree: isTopThree,
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ResultGridTab extends StatelessWidget {
  final MacmahonState state;
  final List<MacmahonPlayer> sorted;

  const _ResultGridTab({required this.state, required this.sorted});

  @override
  Widget build(BuildContext context) {
    if (sorted.isEmpty) {
      return const Center(child: Text('선수가 없습니다.', style: TextStyle(color: Colors.grey)));
    }

    // 1. 선수별 고유 번호 부여 (등록 순서 기준)
    final playerNumbers = <String, int>{};
    for (int i = 0; i < state.players.length; i++) {
      playerNumbers[state.players[i].id] = i + 1;
    }

    final rounds = state.history.length;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Table(
            defaultColumnWidth: const IntrinsicColumnWidth(),
            border: TableBorder.all(color: Colors.grey.withValues(alpha: 0.3), width: 1),
            children: [
              // Header Row
              TableRow(
                decoration: const BoxDecoration(color: AppTheme.surface),
                children: [
                  _GridHeaderCell('#'),
                  _GridHeaderCell('이름'),
                  for (int r = 1; r <= rounds; r++) _GridHeaderCell('R$r'),
                  _GridHeaderCell('MMS'),
                  _GridHeaderCell('SOS'),
                ],
              ),
              // Data Rows
              for (final player in sorted)
                TableRow(
                  children: [
                    _GridDataCell('${playerNumbers[player.id]}', textAlign: TextAlign.center),
                    _GridDataCell(player.name, bold: true),
                    for (int r = 0; r < rounds; r++)
                      _buildRoundResultCell(player, state.history[r], playerNumbers),
                    _GridDataCell(player.currentMms.toStringAsFixed(1), textAlign: TextAlign.center, color: AppTheme.primary, bold: true),
                    _GridDataCell(player.sos.toStringAsFixed(1), textAlign: TextAlign.center, color: AppTheme.textSecondary),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoundResultCell(
      MacmahonPlayer player, PairingResult roundHistory, Map<String, int> playerNumbers) {
    // 1. 해당 라운드 대진 찾기
    MacmahonPair? pair;
    try {
      pair = roundHistory.pairs.firstWhere((p) => p.black.id == player.id || p.white.id == player.id);
    } catch (_) {
      pair = null;
    }

    // 2. 부전승 확인
    if (pair == null) {
      if (roundHistory.byePlayer?.id == player.id) {
        return _GridDataCell('Bye', color: Colors.blue, textAlign: TextAlign.center);
      }
      return _GridDataCell('-', textAlign: TextAlign.center);
    }

    // 3. 결과 및 상대 번호 추출
    final isBlack = pair.black.id == player.id;
    final opponentId = isBlack ? pair.white.id : pair.black.id;
    final opponentNum = playerNumbers[opponentId] ?? 0;
    
    String resultChar = '';
    Color resultColor = AppTheme.textSecondary;

    if (!pair.isResultEntered) {
      resultChar = '?';
    } else if (pair.winnerId == null) {
      resultChar = '△'; // Draw
      resultColor = Colors.orange;
    } else if (pair.winnerId == player.id) {
      resultChar = 'o'; // Win
      resultColor = Colors.green;
    } else {
      resultChar = 'x'; // Loss
      resultColor = Colors.red;
    }

    return _GridDataCell('$resultChar $opponentNum', color: resultColor, textAlign: TextAlign.center);
  }
}

class _GridHeaderCell extends StatelessWidget {
  final String text;
  const _GridHeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
      ),
    );
  }
}

class _GridDataCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  final TextAlign textAlign;

  const _GridDataCell(this.text, {this.bold = false, this.color, this.textAlign = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppTheme.textPrimary,
          fontSize: 14,
        ),
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
        color: isTopThree ? _rankColor.withValues(alpha: 0.07) : AppTheme.cardBg,
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
                      color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
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
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          )),
                      if (player.isTopBar) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.accent.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Top', style: TextStyle(fontSize: 9)),
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
                                  margin: const EdgeInsets.only(right: 3),
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
            _ScoreCell(value: player.currentMms.toStringAsFixed(1), bold: true, color: AppTheme.primary),
            _ScoreCell(value: player.sos.toStringAsFixed(1), color: AppTheme.textSecondary),
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
  const _ScoreCell({required this.value, this.bold = false, required this.color});

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
