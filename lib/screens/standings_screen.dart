import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_player.dart';
import '../models/macmahon_pair.dart';
import '../providers/macmahon_provider.dart';
import '../services/export_service.dart';

class StandingsScreen extends ConsumerWidget {
  final int initialIndex;
  const StandingsScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);

    // MMS > SOS > SODOS > 승자승 > 초기 MMS > 승수 기준 내림차순 정렬
    final sorted = [...state.players]..sort(_comparePlayers);

    return DefaultTabController(
      initialIndex: initialIndex,
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
            _RankingsTab(state: state, sorted: sorted),
            _ResultGridTab(state: state, sorted: sorted),
          ],
        ),
      ),
    );
  }

  int _comparePlayers(MacmahonPlayer a, MacmahonPlayer b) {
    // 1. MMS (대국 점수)
    final mmsCmp = b.currentMms.compareTo(a.currentMms);
    if (mmsCmp != 0) return mmsCmp;

    // 2. SOS (상대 MMS 합)
    final sosCmp = b.sos.compareTo(a.sos);
    if (sosCmp != 0) return sosCmp;

    // 3. 누진점수 (Progressive Score/Cumulative Score)
    // 초반에 강한 보드에서 버틴 선수에게 우선순위 부여
    final cumCmp = b.cumulativeScore.compareTo(a.cumulativeScore);
    if (cumCmp != 0) return cumCmp;

    // 4. SODOS (이긴 상대의 MMS 합)
    final sodosCmp = b.sodos.compareTo(a.sodos);
    if (sodosCmp != 0) return sodosCmp;

    // 5. 승자승 (Direct Encounter)
    if (a.defeatedOpponents.contains(b.id)) return -1;
    if (b.defeatedOpponents.contains(a.id)) return 1;

    // 6. 초기 MMS (가산점)
    final initCmp = b.initialMms.compareTo(a.initialMms);
    if (initCmp != 0) return initCmp;

    // 7. 총 승수
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
  final MacmahonState state;
  final List<MacmahonPlayer> sorted;
  const _RankingsTab({required this.state, required this.sorted});

  @override
  Widget build(BuildContext context) {
    if (sorted.isEmpty) {
      return const Center(child: Text('선수가 없습니다.', style: TextStyle(color: Colors.grey)));
    }

    final playerNumbers = <String, int>{};
    for (int i = 0; i < state.players.length; i++) {
      playerNumbers[state.players[i].id] = i + 1;
    }

    return Column(
      children: [
        Container(
          color: AppTheme.surface,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: const Row(
            children: [
              SizedBox(width: 40),
              SizedBox(
                  width: 90,
                  child: Text('선수명',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textSecondary,
                          fontSize: 12))),
              Expanded(
                child: Text('라운드 결과',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        fontSize: 12)),
              ),
              _HeaderCell('MMS'),
              _HeaderCell('SOS'),
              _HeaderCell('승'),
              _HeaderCell('패'),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: sorted.length,
            itemBuilder: (context, index) {
              final player = sorted[index];

              int displayRank = 1;
              if (index > 0) {
                for (int i = index; i > 0; i--) {
                  final p1 = sorted[index];
                  final p2 = sorted[i - 1];

                  bool isSame = p1.currentMms == p2.currentMms &&
                      p1.sos == p2.sos &&
                      p1.cumulativeScore == p2.cumulativeScore && // 누진점수 추가
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
                history: state.history,
                playerNumbers: playerNumbers,
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

    final playerNumbers = <String, int>{};
    for (int i = 0; i < state.players.length; i++) {
      playerNumbers[state.players[i].id] = i + 1;
    }

    // 선수별 순위 미리 계산 (동순위 처리 포함)
    final playerRanks = <String, int>{};
    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      if (i > 0) {
        final prev = sorted[i - 1];
        bool isSame = p.currentMms == prev.currentMms &&
            p.sos == prev.sos &&
            p.cumulativeScore == prev.cumulativeScore &&
            p.sodos == prev.sodos &&
            !p.defeatedOpponents.contains(prev.id) &&
            !prev.defeatedOpponents.contains(p.id) &&
            p.initialMms == prev.initialMms &&
            p.wins == prev.wins;
        
        if (isSame) {
          playerRanks[p.id] = playerRanks[prev.id]!;
        } else {
          playerRanks[p.id] = i + 1;
        }
      } else {
        playerRanks[p.id] = 1;
      }
    }

    final rounds = state.history.length;
    const headerGreen = Color(0xFFDCEDC8); // 연한 연두색

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: MediaQuery.of(context).size.width,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Table(
                    defaultColumnWidth: const IntrinsicColumnWidth(),
                    border: TableBorder.all(color: Colors.black, width: 1.0),
                    children: [
                      // ── 헤더 1행: 연한 연두색 배경 ──────────────────────────
                      TableRow(
                        decoration: const BoxDecoration(color: headerGreen),
                        children: [
                          _GridMainHeaderCell('번호', textColor: Colors.black),
                          _GridMainHeaderCell('이름', textColor: Colors.black, minWidth: 100),
                          for (int r = 1; r <= rounds; r++) ...[
                            _GridMainHeaderCell('${r}R', textColor: Colors.black),
                            const SizedBox.shrink(),
                          ],
                          _GridMainHeaderCell('초기\nMMS', textColor: Colors.black),
                          _GridMainHeaderCell('승수', textColor: Colors.black),
                          _GridMainHeaderCell('순위', textColor: Colors.black),
                        ],
                      ),
                      // ── 헤더 2행: 세부 항목 (상대, 승패) ────────────────
                      TableRow(
                        decoration: const BoxDecoration(color: headerGreen),
                        children: [
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          for (int r = 0; r < rounds; r++) ...[
                            _GridSubHeaderCell('상대', textColor: Colors.black87),
                            _GridSubHeaderCell('결과', textColor: Colors.black87),
                          ],
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                          const SizedBox.shrink(),
                        ],
                      ),
                      // ── 데이터 행 (등록 번호 순으로 출력) ─────────────────────
                      for (int i = 0; i < state.players.length; i++)
                        _buildDataRow(state.players[i], i + 1, playerNumbers, rounds, playerRanks[state.players[i].id] ?? 0),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _buildDataRow(MacmahonPlayer player, int playerNum, Map<String, int> playerNumbers, int rounds, int rank) {
    return TableRow(
      children: [
        _GridDataCell('$playerNum', textAlign: TextAlign.center),
        _GridDataCell(player.name, bold: true, minWidth: 100, textAlign: TextAlign.center),
        for (int r = 0; r < rounds; r++) ..._buildRoundCells(player, state.history[r], playerNumbers),
        _GridDataCell(player.initialMms.toStringAsFixed(1), textAlign: TextAlign.center),
        _GridDataCell('${player.wins}', textAlign: TextAlign.center, bold: true),
        _GridDataCell('$rank', textAlign: TextAlign.center, bold: true),
      ],
    );
  }

  List<Widget> _buildRoundCells(MacmahonPlayer player, PairingResult roundHistory, Map<String, int> playerNumbers) {
    MacmahonPair? pair;
    try {
      pair = roundHistory.pairs.firstWhere((p) => p.black.id == player.id || p.white.id == player.id);
    } catch (_) {
      pair = null;
    }

    if (pair == null) {
      if (roundHistory.byePlayer?.id == player.id) {
        return [
          _GridDataCell('-', textAlign: TextAlign.center),
          _GridDataCell('● (부전)', color: const Color(0xFFD32F2F), textAlign: TextAlign.center, fontSize: 11, bold: true),
        ];
      }
      return [
        _GridDataCell('-', textAlign: TextAlign.center),
        _GridDataCell('-', textAlign: TextAlign.center),
      ];
    }

    final isBlack = pair.black.id == player.id;
    final opponentId = isBlack ? pair.white.id : pair.black.id;
    final opponentNum = playerNumbers[opponentId] ?? 0;

    String marker = '';
    Color color = Colors.black;
    double? markerSize;

    if (pair.isResultEntered) {
      if (pair.winnerId == null) {
        marker = '무';
        color = Colors.orange.shade700;
      } else if (pair.winnerId == player.id) {
        marker = '●'; // 빨간 원 (승리)
        color = const Color(0xFFD32F2F);
        markerSize = 18;
      } else {
        marker = '·'; // 파란 점 (패배)
        color = const Color(0xFF1976D2);
        markerSize = 28;
      }
    } else {
      marker = '?';
      color = Colors.grey;
    }

    return [
      _GridDataCell('$opponentNum', textAlign: TextAlign.center, color: color, bold: pair.isResultEntered),
      Container(
        height: 40,
        alignment: Alignment.center,
        child: Text(
          marker,
          style: TextStyle(
            color: color,
            fontSize: markerSize ?? 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];
  }
}

class _GridMainHeaderCell extends StatelessWidget {
  final String text;
  final Color textColor;
  final double? minWidth;
  const _GridMainHeaderCell(this.text, {this.textColor = Colors.black, this.minWidth});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 40),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      alignment: Alignment.center,
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }
}

class _GridSubHeaderCell extends StatelessWidget {
  final String text;
  final Color textColor;
  const _GridSubHeaderCell(this.text, {this.textColor = Colors.black87});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      child: Text(text,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class _GridDataCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  final TextAlign textAlign;
  final double? minWidth;
  final double? fontSize;

  const _GridDataCell(this.text, {
    this.bold = false, 
    this.color, 
    this.textAlign = TextAlign.center, 
    this.minWidth,
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 35),
      height: 40,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppTheme.textPrimary,
          fontSize: fontSize ?? 13,
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
  final List<PairingResult> history;
  final Map<String, int> playerNumbers;

  const _StandingsTile({
    required this.rank,
    required this.player,
    required this.isTopThree,
    required this.history,
    required this.playerNumbers,
  });

  Color get _rankColor {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
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
            SizedBox(
              width: 90,
              child: Row(
                children: [
                   Flexible(
                    child: Text(player.name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        )),
                  ),
                  if (player.isTopBar) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('T', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: history.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(left: 8.0),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        alignment: WrapAlignment.start,
                        children: [
                          for (int r = 0; r < history.length; r++)
                            _buildRoundMiniBadge(history[r], r + 1),
                        ],
                      ),
                    ),
            ),
            const SizedBox(width: 8),
            _ScoreCell(value: player.currentMms.toStringAsFixed(1), bold: true, color: AppTheme.primary),
            _ScoreCell(value: player.sos.toStringAsFixed(1), color: AppTheme.textSecondary),
            _ScoreCell(value: '${player.wins}', color: Colors.green),
            _ScoreCell(value: '${player.losses}', color: Colors.red),
          ],
        ),
      ),
    );
  }

  Widget _buildRoundMiniBadge(PairingResult roundHistory, int roundNum) {
    MacmahonPair? pair;
    try {
      pair = roundHistory.pairs.firstWhere((p) => p.black.id == player.id || p.white.id == player.id);
    } catch (_) {
      pair = null;
    }

    String text = '';
    Color color = Colors.grey;

    if (pair == null) {
      if (roundHistory.byePlayer?.id == player.id) {
        text = '${roundNum}R : 부전승';
        color = Colors.green;
      } else {
        text = '${roundNum}R : -';
      }
    } else {
      final isBlack = pair.black.id == player.id;
      final opponentId = isBlack ? pair.white.id : pair.black.id;
      final opponentNum = playerNumbers[opponentId] ?? 0;

      if (!pair.isResultEntered) {
        text = '${roundNum}R : ? 상대 : $opponentNum';
      } else if (pair.winnerId == null) {
        text = '${roundNum}R : 무 상대 : $opponentNum';
        color = Colors.orange;
      } else if (pair.winnerId == player.id) {
        text = '${roundNum}R : 승 상대 : $opponentNum';
        color = Colors.green;
      } else {
        text = '${roundNum}R : 패 상대 : $opponentNum';
        color = Colors.red;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: color,
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
