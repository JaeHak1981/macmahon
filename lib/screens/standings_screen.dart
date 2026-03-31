import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_player.dart';
import '../models/macmahon_pair.dart';
import '../providers/macmahon_provider.dart';
import '../services/export_service.dart';
import 'package:flutter/services.dart';

class StandingsScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const StandingsScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<StandingsScreen> createState() => _StandingsScreenState();
}

class _StandingsScreenState extends ConsumerState<StandingsScreen> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);

    // MMS > SOS > SODOS > 승자승 > 초기 MMS > 승수 기준 내림차순 정렬
    final sorted = [...state.players]..sort(_comparePlayers);

    final playerNumbers = _getPlayerNumbers(state.players);
    final playerRanks = _calculateRanks(sorted);

    return DefaultTabController(
      initialIndex: widget.initialIndex,
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            state.tournamentName.isNotEmpty
                ? '${state.tournamentName} - 결과'
                : '대회 결과',
          ),
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
              tooltip: '점수 안내',
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showScoreHelpDialog(context),
            ),
            IconButton(
              tooltip: '엑셀로 내보내기',
              icon: const Icon(Icons.file_download),
              onPressed: () => _exportToExcel(
                context,
                sorted,
                state.tournamentName,
                state.history,
                playerNumbers,
              ),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: TabBarView(
                children: [
                  _RankingsTab(
                    state: state,
                    sorted: sorted,
                    playerNumbers: playerNumbers,
                    playerRanks: playerRanks,
                  ),
                  _ResultGridTab(
                    state: state,
                    sorted: sorted,
                    playerNumbers: playerNumbers,
                    playerRanks: playerRanks,
                    verticalController: _verticalController,
                    horizontalController: _horizontalController,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Map<String, int> _calculateRanks(List<MacmahonPlayer> sorted) {
    final playerRanks = <String, int>{};
    for (int i = 0; i < sorted.length; i++) {
      final p = sorted[i];
      if (i > 0) {
        final prev = sorted[i - 1];
        bool isSame =
            p.currentMms == prev.currentMms &&
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
    return playerRanks;
  }

  int _comparePlayers(MacmahonPlayer a, MacmahonPlayer b) {
    // 1. MMS (대국 점수)
    final mmsCmp = b.currentMms.compareTo(a.currentMms);
    if (mmsCmp != 0) return mmsCmp;

    // 2. 누진점수 (Progressive Score/Cumulative Score)
    // 초반에 강한 보드에서 버틴 선수에게 우선순위 부여 (스위스 리그 방식 선호)
    final cumCmp = b.cumulativeScore.compareTo(a.cumulativeScore);
    if (cumCmp != 0) return cumCmp;

    // 3. SOS (상대 MMS 합)
    final sosCmp = b.sos.compareTo(a.sos);
    if (sosCmp != 0) return sosCmp;

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

  void _showScoreHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          '점수 구조 안내',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'MMS (내 승점)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '선수가 이 대회에서 거둔 총 승점(승수)입니다. 똑같이 0점으로 시작한 대회라면, 3승을 했을 때 3점이 됩니다.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 16),
              Text(
                'SOS (대진 난이도)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '똑같이 3승으로 동점이더라도, 더 어려운 상대들과 싸운 선수를 우대합니다.\n이걸 증명하기 위해 \'내가 만났던 모든 상대들의 승점\'을 합친 타이브레이커 숫자입니다.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 16),
              Text(
                'SODOS (승리 순도)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '만약 SOS까지 똑같은 초유의 동점 사태가 났을 때, 내가 만난 모든 상대가 아니라 오직 \'내가 직접 이긴 상대\'들의 점수만 합쳐서 최종 우열을 가립니다.',
                style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              '이해했습니다',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToExcel(
    BuildContext context,
    List<MacmahonPlayer> sorted,
    String tournamentName,
    List<PairingResult> history,
    Map<String, int> playerNumbers,
  ) async {
    try {
      final path = await ExportService.exportToExcel(
        sorted,
        tournamentName.isEmpty ? 'macmahon_tournament' : tournamentName,
        history: history,
        playerNumbers: playerNumbers,
      );
      if (path != null && context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('엑셀 파일이 저장되었습니다: $path')));
      }
    } catch (e) {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('내보내기 실패'),
            content: SingleChildScrollView(child: Text(e.toString())),
            actions: [
              TextButton(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: e.toString()));
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('오류 내용이 복사되었습니다.')),
                    );
                  }
                },
                child: const Text('오류 복사'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          ),
        );
      }
    }
  }

  Map<String, int> _getPlayerNumbers(List<MacmahonPlayer> players) {
    final playerNumbers = <String, int>{};
    for (int i = 0; i < players.length; i++) {
      playerNumbers[players[i].id] = i + 1;
    }
    return playerNumbers;
  }
}

class _RankingsTab extends StatelessWidget {
  final MacmahonState state;
  final List<MacmahonPlayer> sorted;
  final Map<String, int> playerNumbers;
  final Map<String, int> playerRanks;

  const _RankingsTab({
    required this.state,
    required this.sorted,
    required this.playerNumbers,
    required this.playerRanks,
  });

  @override
  Widget build(BuildContext context) {
    if (sorted.isEmpty) {
      return const Center(
        child: Text('선수가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
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
                child: Text(
                  '선수명',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '라운드 결과',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
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
              final displayRank = playerRanks[player.id] ?? (index + 1);

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
  final Map<String, int> playerNumbers;
  final Map<String, int> playerRanks;
  final ScrollController verticalController;
  final ScrollController horizontalController;

  const _ResultGridTab({
    required this.state,
    required this.sorted,
    required this.playerNumbers,
    required this.playerRanks,
    required this.verticalController,
    required this.horizontalController,
  });

  @override
  Widget build(BuildContext context) {
    if (sorted.isEmpty) {
      return const Center(
        child: Text('선수가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    // 선수별 라운드 종료 후 MMS 히스토리 계산
    final playerMmsByRound = <String, List<double>>{};
    for (final p in state.players) {
      playerMmsByRound[p.id] = [p.initialMms];
    }

    for (int r = 0; r < state.history.length; r++) {
      final roundResult = state.history[r];
      for (final p in state.players) {
        double current = playerMmsByRound[p.id]!.last;

        MacmahonPair? pair;
        try {
          pair = roundResult.pairs.firstWhere(
            (pair) => pair.black.id == p.id || pair.white.id == p.id,
          );
        } catch (_) {
          pair = null;
        }

        if (pair != null) {
          if (pair.winnerId == p.id) {
            current += 1.0;
          } else if (pair.winnerId == null && pair.isResultEntered) {
            current += 0.5;
          }
        } else if (roundResult.byePlayer?.id == p.id) {
          current += 1.0;
        }
        playerMmsByRound[p.id]!.add(current);
      }
    }

    final allRounds = [...state.history];
    if (state.currentPairing != null) {
      allRounds.add(state.currentPairing!);
    }
    final roundsCount = allRounds.length;
    const headerGreen = Color(0xFFDCEDC8);

    return Scrollbar(
      controller: verticalController,
      thumbVisibility: true,
      child: Scrollbar(
        controller: horizontalController,
        thumbVisibility: true,
        notificationPredicate: (notif) => notif.depth == 1,
        child: SingleChildScrollView(
          controller: verticalController,
          scrollDirection: Axis.vertical,
          child: SingleChildScrollView(
            controller: horizontalController,
            scrollDirection: Axis.horizontal,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Table(
                columnWidths: {
                  0: const FixedColumnWidth(40), // 번호
                  1: const FixedColumnWidth(100), // 이름
                  for (int r = 0; r < roundsCount; r++)
                    r + 2: const FixedColumnWidth(121), // 라운드별 (60+1+60)
                  roundsCount + 2: const FixedColumnWidth(60), // 초기 MMS
                  roundsCount + 3: const FixedColumnWidth(60), // 승수
                  roundsCount + 4: const FixedColumnWidth(60), // MMS
                  roundsCount + 5: const FixedColumnWidth(60), // SOS
                  roundsCount + 6: const FixedColumnWidth(60), // 순위
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: TableBorder.all(color: Colors.black, width: 1.0),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: headerGreen),
                    children: [
                      _GridMainHeaderCell(
                        '번호',
                        textColor: Colors.black,
                        minWidth: 40,
                      ),
                      _GridMainHeaderCell(
                        '이름',
                        textColor: Colors.black,
                        minWidth: 100,
                      ),
                      for (int r = 1; r <= roundsCount; r++)
                        _GridRoundHeader('${r}R'),
                      _GridMainHeaderCell(
                        '초기\nMMS',
                        textColor: Colors.black,
                        minWidth: 60,
                      ),
                      _GridMainHeaderCell(
                        '승수',
                        textColor: Colors.black,
                        minWidth: 60,
                      ),
                      _GridMainHeaderCell(
                        'MMS',
                        textColor: AppTheme.primary,
                        minWidth: 60,
                      ),
                      _GridMainHeaderCell(
                        'SOS',
                        textColor: AppTheme.textSecondary,
                        minWidth: 60,
                      ),
                      _GridMainHeaderCell(
                        '순위',
                        textColor: Colors.black,
                        minWidth: 60,
                      ),
                    ],
                  ),
                  for (final player in state.players)
                    _buildDataRow(
                      player,
                      playerNumbers[player.id]!,
                      playerNumbers,
                      allRounds,
                      playerRanks[player.id] ?? 0,
                      playerMmsByRound[player.id] ?? [],
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  TableRow _buildDataRow(
    MacmahonPlayer player,
    int playerNum,
    Map<String, int> playerNumbers,
    List<PairingResult> allRounds,
    int rank,
    List<double> mmsHistory,
  ) {
    return TableRow(
      children: [
        _GridDataCell('$playerNum', textAlign: TextAlign.center),
        _GridDataCell(
          player.name,
          bold: true,
          minWidth: 100,
          textAlign: TextAlign.center,
        ),
        for (int r = 0; r < allRounds.length; r++)
          _buildRoundCell(
            player,
            allRounds[r],
            playerNumbers,
            mmsHistory.length > r + 1 ? mmsHistory[r + 1] : null,
          ),
        _GridDataCell(
          player.initialMms.toStringAsFixed(1),
          textAlign: TextAlign.center,
        ),
        _GridDataCell(
          '${player.wins}',
          textAlign: TextAlign.center,
          bold: true,
        ),
        _GridDataCell(
          player.currentMms.toStringAsFixed(1),
          textAlign: TextAlign.center,
          bold: true,
          color: AppTheme.primary,
        ),
        _GridDataCell(
          player.sos.toStringAsFixed(1),
          textAlign: TextAlign.center,
          color: AppTheme.textSecondary,
        ),
        _GridDataCell('$rank', textAlign: TextAlign.center, bold: true),
      ],
    );
  }

  Widget _buildRoundCell(
    MacmahonPlayer player,
    PairingResult roundHistory,
    Map<String, int> playerNumbers,
    double? mmsAfterRound,
  ) {
    MacmahonPair? pair;
    try {
      pair = roundHistory.pairs.firstWhere(
        (p) => p.black.id == player.id || p.white.id == player.id,
      );
    } catch (_) {
      pair = null;
    }

    String marker = '';
    Color color = Colors.black;
    double? markerSize;
    String opponentNumStr = '-';

    if (pair != null) {
      final isBlack = pair.black.id == player.id;
      final opponentId = isBlack ? pair.white.id : pair.black.id;
      final opponentNum = playerNumbers[opponentId] ?? 0;
      opponentNumStr = '$opponentNum';

      if (pair.isResultEntered) {
        if (pair.winnerId == null) {
          marker = '무';
          color = Colors.orange.shade700;
        } else if (pair.winnerId == player.id) {
          marker = '●';
          color = const Color(0xFFD32F2F);
          markerSize = 18;
        } else {
          marker = '·';
          color = const Color(0xFF1976D2);
          markerSize = 28;
        }
      } else {
        marker = '';
        color = Colors.black; // 진행 중인 라운드의 기본 색상은 검은색
      }
    } else if (roundHistory.byePlayer?.id == player.id) {
      marker = '● (부전)';
      color = const Color(0xFFD32F2F);
      markerSize = 11;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GridDataCell(
          opponentNumStr,
          minWidth: 60,
          color: pair != null && !pair.isResultEntered ? Colors.black : color,
          bold: pair != null, // 대진이 있으면 무조건 굵게 표시
        ),
        Container(width: 1, height: 72, color: Colors.black),
        _GridDataCellWithScore(
          marker,
          mmsAfterRound,
          color: color,
          fontSize: markerSize ?? 13,
          bold: true,
        ),
      ],
    );
  }
}

class _GridRoundHeader extends StatelessWidget {
  final String title;
  const _GridRoundHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 121, // 60 + 1 + 60
      height: 72,
      child: Column(
        children: [
          Expanded(
            child: Container(
              alignment: Alignment.center,
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          Container(height: 1, color: Colors.black),
          Row(
            children: [
              Expanded(
                child: _GridSubHeaderCell('상대', textColor: Colors.black87),
              ),
              Container(width: 1, height: 36, color: Colors.black),
              Expanded(
                child: _GridSubHeaderCell('결과', textColor: Colors.black87),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _GridDataCellWithScore extends StatelessWidget {
  final String marker;
  final double? score;
  final Color color;
  final double fontSize;
  final bool bold;

  const _GridDataCellWithScore(
    this.marker,
    this.score, {
    required this.color,
    required this.fontSize,
    this.bold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 60),
      height: 72, // 높이 증가 (72로 상향 조정)
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            marker,
            style: TextStyle(
              color: color,
              fontSize: fontSize,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          if (score != null)
            Text(
              '(${score!.toStringAsFixed(1)})',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 9,
                fontWeight: FontWeight.normal,
              ),
            ),
        ],
      ),
    );
  }
}

class _GridMainHeaderCell extends StatelessWidget {
  final String text;
  final Color textColor;
  final double? minWidth;
  const _GridMainHeaderCell(
    this.text, {
    this.textColor = Colors.black,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 60),
      height: 72,
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ),
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
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _GridDataCell extends StatelessWidget {
  final String text;
  final bool bold;
  final Color? color;
  final TextAlign textAlign;
  final double? minWidth;

  const _GridDataCell(
    this.text, {
    this.bold = false,
    this.color,
    this.textAlign = TextAlign.center,
    this.minWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minWidth: minWidth ?? 60),
      height: 72, 
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          color: color ?? AppTheme.textPrimary,
          fontSize: 13,
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
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          fontSize: 12,
        ),
      ),
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
        color: isTopThree
            ? _rankColor.withValues(alpha: 0.07)
            : AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isTopThree
              ? _rankColor.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
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
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 90,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      player.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  if (player.isTopBar) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'T',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
            _ScoreCell(
              value: player.currentMms.toStringAsFixed(1),
              bold: true,
              color: AppTheme.primary,
            ),
            _ScoreCell(
              value: player.sos.toStringAsFixed(1),
              color: AppTheme.textSecondary,
            ),
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
      pair = roundHistory.pairs.firstWhere(
        (p) => p.black.id == player.id || p.white.id == player.id,
      );
    } catch (_) {
      pair = null;
    }

    String text = '';
    Color color = Colors.grey;

    if (pair == null) {
      if (roundHistory.byePlayer?.id == player.id) {
        text = '${roundNum}R: 부전승';
        color = Colors.green;
      } else {
        text = '${roundNum}R: -';
      }
    } else {
      final isBlack = pair.black.id == player.id;
      final opponentId = isBlack ? pair.white.id : pair.black.id;
      final opponentNum = playerNumbers[opponentId] ?? 0;
      final opponentStr = opponentNum.toString().padLeft(2, '0');

      if (!pair.isResultEntered) {
        text = '${roundNum}R: $opponentStr번 ?';
      } else if (pair.winnerId == null) {
        text = '${roundNum}R: $opponentStr번 무';
        color = Colors.orange;
      } else if (pair.winnerId == player.id) {
        text = '${roundNum}R: $opponentStr번 승';
        color = Colors.green;
      } else {
        text = '${roundNum}R: $opponentStr번 패';
        color = Colors.red;
      }
    }

    return Container(
      width: 78, // 너비 고정
      padding: const EdgeInsets.symmetric(vertical: 4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.0),
      ),
      child: Text(
        text,
        maxLines: 1,
        style: TextStyle(
          fontSize: 11, // 줄바꿈 나지 않게 크기 약간 축소
          letterSpacing: -0.3,
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
  const _ScoreCell({
    required this.value,
    this.bold = false,
    required this.color,
  });

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
