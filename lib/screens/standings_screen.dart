import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
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
  final ScreenshotController _screenshotController = ScreenshotController();
  TabController? _tabController;

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);
    final players = state.currentSectionPlayers;

    final sorted = <MacmahonPlayer>[];
    final playerRanks = <String, int>{};
    _computeStandings(players, state.format, sorted, playerRanks);

    final playerNumbers = _getPlayerNumbers(players);

    // 현재 단계가 리그전인지 판별 (일반 리그 또는 리그+토너먼트의 예선 단계)
    final isLeagueStage = state.format == TournamentFormat.league ||
        (state.format == TournamentFormat.leagueAndKnockout &&
            state.stage == 1);

    final appBar = AppBar(
      title: Text(
        state.tournamentName.isNotEmpty
            ? '${state.tournamentName} - ${state.selectedSection} 결과'
            : '${state.selectedSection} 대회 결과',
      ),
      bottom: isLeagueStage
          ? null
          : TabBar(
              tabs: [
                const Tab(text: '순위표', icon: Icon(Icons.format_list_numbered)),
                const Tab(text: '결과표 (Grid)', icon: Icon(Icons.grid_on)),
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
        IconButton(
          tooltip: '이미지로 저장 (PNG)',
          icon: const Icon(Icons.image_outlined),
          onPressed: () async {
            int currentIndex = _tabController?.index ?? 0;

            // 현재 스크린의 상태(탭 등)에 맞는 위젯을 생성하여 전체 캡처
            final exportWidget = Material(
              color: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      state.tournamentName.isNotEmpty ? state.tournamentName : '대회 결과',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Text('${state.selectedSection} - ${isLeagueStage ? "리그표" : (currentIndex == 0 ? "순위표" : "대국결과표")}', 
                        style: const TextStyle(fontSize: 18)),
                    const SizedBox(height: 20),
                    isLeagueStage
                        ? _LeagueMatrixTab(
                            state: state,
                            sorted: sorted,
                            playerNumbers: playerNumbers,
                            playerRanks: playerRanks,
                            onResultTap: (_, __, ___) {},
                            isExport: true,
                          )
                        : (currentIndex == 0 
                            ? _RankingsTab(
                                state: state,
                                sorted: sorted,
                                playerNumbers: playerNumbers,
                                playerRanks: playerRanks,
                                onResultTap: (_, __, ___) {},
                                isExport: true,
                              )
                            : _ResultGridTab(
                                state: state,
                                sorted: sorted,
                                playerNumbers: playerNumbers,
                                playerRanks: playerRanks,
                                verticalController: ScrollController(),
                                horizontalController: ScrollController(),
                                onResultTap: (_, __, ___) {},
                                isExport: true,
                              )),
                  ],
                ),
              ),
            );

            // 전체 길이를 위해 예상 높이 계산 (여백과 행 높이를 대폭 상향하여 절대 잘리지 않도록 강제)
            double estimatedHeight = 300; // 상단 헤더 및 여백
            if (isLeagueStage) {
              final Map<String, int> groupCounts = {};
              for (var p in sorted) {
                final gid = p.groupId ?? "A";
                groupCounts[gid] = (groupCounts[gid] ?? 0) + 1;
              }
              for (var count in groupCounts.values) {
                // 조별 헤더 및 간격(150) + (인원수 * 행높이(80))
                estimatedHeight += 150 + (count * 80);
              }
            } else {
              estimatedHeight += 200 + (sorted.length * 80);
            }
            estimatedHeight += 300; // 하단 절대 안전 여백

            // 명시적인 크기를 가진 컨테이너로 감싸서 캡처 라이브러리의 오동작 방지
            final wrapperWidget = Container(
              width: 1200,
              height: estimatedHeight,
              color: AppTheme.surface,
              alignment: Alignment.topCenter,
              child: exportWidget,
            );

            final imageBytes = await _screenshotController.captureFromWidget(
              wrapperWidget,
              context: context,
              targetSize: Size(1200, estimatedHeight),
              delay: const Duration(milliseconds: 200),
            );

            final path = await ExportService.saveImageBytes(
              imageBytes,
              state.tournamentName.isNotEmpty ? state.tournamentName : 'tournament',
            );
            
            if (path != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('이미지가 저장되었습니다: $path')),
              );
            }
          },
        ),
      ],
    );

    final content = Screenshot(
      controller: _screenshotController,
      child: Container(
        color: AppTheme.surface, // 배경색 지정 (캡처 시 필요)
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: isLeagueStage
                  ? _LeagueMatrixTab(
                      state: state,
                      sorted: sorted,
                      playerNumbers: playerNumbers,
                      playerRanks: playerRanks,
                      onResultTap: (p1, p2, pair) =>
                          _showResultInput(context, ref, p1, p2, pair),
                    )
              : TabBarView(
                  children: [
                    _RankingsTab(
                      state: state,
                      sorted: sorted,
                      playerNumbers: playerNumbers,
                      playerRanks: playerRanks,
                      onResultTap: (p1, p2, pair) =>
                          _showResultInput(context, ref, p1, p2, pair),
                    ),
                    _ResultGridTab(
                      state: state,
                      sorted: sorted,
                      playerNumbers: playerNumbers,
                      playerRanks: playerRanks,
                      verticalController: _verticalController,
                      horizontalController: _horizontalController,
                      onResultTap: (p1, p2, pair) =>
                          _showResultInput(context, ref, p1, p2, pair),
                    ),
                  ],
                ),
            ),
          ),
        ),
      ),
    );

    if (!isLeagueStage && _tabController == null) {
      return DefaultTabController(
        initialIndex: widget.initialIndex.clamp(0, 1),
        length: 2,
        child: Builder(builder: (context) {
          _tabController = DefaultTabController.of(context);
          return Scaffold(
            appBar: appBar,
            body: content,
          );
        }),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: content,
    );
  }

  void _showResultInput(BuildContext context, WidgetRef ref, MacmahonPlayer p1,
      MacmahonPlayer p2, MacmahonPair pair) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title:
            const Text('결과 입력', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('${p1.name} vs ${p2.name}\n결과를 선택해 주세요.'),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          _ResultButton(
            label: 'O (승)',
            color: Colors.blue,
            onPressed: () {
              ref
                  .read(macmahonProvider.notifier)
                  .recordResultByPlayers(p1.id, p2.id, p1.id);
              Navigator.pop(ctx);
            },
          ),
          _ResultButton(
            label: 'X (패)',
            color: Colors.red,
            onPressed: () {
              ref
                  .read(macmahonProvider.notifier)
                  .recordResultByPlayers(p1.id, p2.id, p2.id);
              Navigator.pop(ctx);
            },
          ),
          _ResultButton(
            label: '△ (무)',
            color: Colors.orange,
            onPressed: () {
              ref
                  .read(macmahonProvider.notifier)
                  .recordResultByPlayers(p1.id, p2.id, null);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _computeStandings(
    List<MacmahonPlayer> players,
    TournamentFormat format,
    List<MacmahonPlayer> outSorted,
    Map<String, int> outRanks,
  ) {
    // 1. 그룹별 분리
    final groups = <String, List<MacmahonPlayer>>{};
    for (var p in players) {
      final gId = p.groupId ?? "";
      groups.putIfAbsent(gId, () => []).add(p);
    }

    final isLeague = format == TournamentFormat.league || format == TournamentFormat.leagueAndKnockout;
    final sortedGroupIds = groups.keys.toList()..sort();

    for (var gId in sortedGroupIds) {
      final groupPlayers = groups[gId]!;

      // 1차: MMS 기준으로 그룹핑 (동률 판별의 기준점)
      final mmsGroups = <double, List<MacmahonPlayer>>{};
      for (var p in groupPlayers) {
        mmsGroups.putIfAbsent(p.currentMms, () => []).add(p);
      }

      final sortedMms = mmsGroups.keys.toList()..sort((a, b) => b.compareTo(a));
      int currentRank = 1;

      for (var mms in sortedMms) {
        final tiedPlayers = mmsGroups[mms]!;

        // 2차: 동률 그룹 내 승자승(Internal Wins) 계산
        final internalWins = <String, int>{};
        for (var p in tiedPlayers) {
          int wins = 0;
          for (var opp in tiedPlayers) {
            if (p.id != opp.id && p.defeatedOpponents.contains(opp.id)) {
              wins++;
            }
          }
          internalWins[p.id] = wins;
        }

        // 3차: 다중 조건 정렬 (내부 승수 -> SODOS -> SOS -> 누진점수 -> 초기 서열 -> 총 승수)
        tiedPlayers.sort((a, b) {
          final wA = internalWins[a.id]!;
          final wB = internalWins[b.id]!;
          if (wA != wB) return wB.compareTo(wA);

          final sodosCmp = b.sodos.compareTo(a.sodos);
          if (sodosCmp != 0) return sodosCmp;

          if (!isLeague) {
            final sosCmp = b.sos.compareTo(a.sos);
            if (sosCmp != 0) return sosCmp;

            final cumCmp = b.cumulativeScore.compareTo(a.cumulativeScore);
            if (cumCmp != 0) return cumCmp;
          }

          final initCmp = b.initialMms.compareTo(a.initialMms);
          if (initCmp != 0) return initCmp;

          return b.wins.compareTo(a.wins);
        });

        // 4차: 최종 순위 부여 (모든 조건이 동일하면 공동 순위 부여)
        if (tiedPlayers.isNotEmpty) {
          int subRank = currentRank;
          outRanks[tiedPlayers[0].id] = subRank;
          outSorted.add(tiedPlayers[0]);

          for (int i = 1; i < tiedPlayers.length; i++) {
            final prev = tiedPlayers[i - 1];
            final curr = tiedPlayers[i];

            bool isSame = internalWins[curr.id] == internalWins[prev.id] &&
                curr.sodos == prev.sodos &&
                curr.initialMms == prev.initialMms &&
                curr.wins == prev.wins;

            if (!isLeague) {
              isSame = isSame && curr.sos == prev.sos && curr.cumulativeScore == prev.cumulativeScore;
            }

            if (!isSame) {
              subRank = currentRank + i; // 공동 순위일 경우 건너뛰고, 다르면 순위 하락
            }
            outRanks[curr.id] = subRank;
            outSorted.add(curr);
          }
        }
        currentRank += tiedPlayers.length;
      }
    }
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
  final void Function(MacmahonPlayer, MacmahonPlayer, MacmahonPair) onResultTap;
  final bool isExport;

  const _RankingsTab({
    required this.state,
    required this.sorted,
    required this.playerNumbers,
    required this.playerRanks,
    required this.onResultTap,
    this.isExport = false,
  });

  @override
  Widget build(BuildContext context) {
    if (sorted.isEmpty) {
      return const Center(
        child: Text('선수가 없습니다.', style: TextStyle(color: Colors.grey)),
      );
    }

    final listWidget = ListView(
      shrinkWrap: isExport,
      physics: isExport ? const NeverScrollableScrollPhysics() : null,
      children: _buildRankListWithHeaders(),
    );

    return Column(
      children: [
        if (!isExport)
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
                SizedBox(width: 210, child: Center(child: Text('집계', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary, fontSize: 12)))),
              ],
            ),
          ),
        if (!isExport) const Divider(height: 1),
        isExport ? listWidget : Expanded(child: listWidget),
      ],
    );
  }

  List<Widget> _buildRankListWithHeaders() {
    final List<Widget> items = [];
    String? currentGroup;

    for (int i = 0; i < sorted.length; i++) {
      final player = sorted[i];

      // 그룹 헤더 추가 (그룹이 여러 개일 때만)
      if (player.groupId != currentGroup) {
        currentGroup = player.groupId;
        if (state.currentSectionData.groupCount > 1) {
          items.add(
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: AppTheme.primary.withValues(alpha: 0.05),
              child: Text(
                '${currentGroup ?? "A"}조 순위',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  fontSize: 14,
                ),
              ),
            ),
          );
          items.add(const Divider(height: 1));
        }
      }

      final displayRank = playerRanks[player.id] ?? (i + 1);
      final isTopThree = displayRank <= 3;
      final currentPair = state.currentPairing?.pairs.firstWhere(
        (p) => p.black.id == player.id || p.white.id == player.id,
        orElse: () => MacmahonPair(
            black: player, white: player, cost: 0), // Dummy
      );
      final hasCurrentMatch = currentPair != null &&
          currentPair.black.id != currentPair.white.id;

      items.add(_StandingsTile(
        rank: displayRank,
        player: player,
        isTopThree: isTopThree,
        history: state.history,
        playerNumbers: playerNumbers,
        onTapResult: hasCurrentMatch
            ? () {
                final opponent = currentPair.black.id == player.id
                    ? currentPair.white
                    : currentPair.black;
                onResultTap(player, opponent, currentPair);
              }
            : null,
      ));
    }
    return items;
  }
}

class _ResultGridTab extends StatelessWidget {
  final MacmahonState state;
  final List<MacmahonPlayer> sorted;
  final Map<String, int> playerNumbers;
  final Map<String, int> playerRanks;
  final ScrollController verticalController;
  final ScrollController horizontalController;
  final void Function(MacmahonPlayer, MacmahonPlayer, MacmahonPair) onResultTap;
  final bool isExport;

  const _ResultGridTab({
    required this.state,
    required this.sorted,
    required this.playerNumbers,
    required this.playerRanks,
    required this.verticalController,
    required this.horizontalController,
    required this.onResultTap,
    this.isExport = false,
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
    for (final p in sorted) {
      playerMmsByRound[p.id] = [p.initialMms];
    }

    for (int r = 0; r < state.history.length; r++) {
      final roundResult = state.history[r];
      for (final p in sorted) {
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
        } else if (roundResult.byePlayers.any((bp) => bp.id == p.id)) {
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

    final content = SingleChildScrollView(
      controller: horizontalController,
      scrollDirection: Axis.horizontal,
      physics: isExport ? const NeverScrollableScrollPhysics() : null,
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
                _GridMainHeaderCell('No.'),
                _GridMainHeaderCell('선수명'),
                for (int r = 0; r < roundsCount; r++)
                  _GridMainHeaderCell('${r + 1}R'),
                _GridMainHeaderCell('초기'),
                _GridMainHeaderCell('승수'),
                _GridMainHeaderCell('MMS'),
                _GridMainHeaderCell('SOS'),
                _GridMainHeaderCell('순위'),
              ],
            ),
            for (final player in sorted)
              _buildDataRow(
                context,
                player,
                playerNumbers[player.id]!,
                playerNumbers,
                allRounds,
                playerRanks[player.id] ?? 0,
                playerMmsByRound[player.id]!,
              ),
          ],
        ),
      ),
    );

    if (isExport) return content;

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
          child: content,
        ),
      ),
    );
  }

  TableRow _buildDataRow(
    BuildContext context,
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
            context,
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
    BuildContext context,
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

    final isCurrentRound = roundHistory.round == state.currentRound;

    return GestureDetector(
      onTap: (pair != null && isCurrentRound)
          ? () {
              final opponent =
                  pair!.black.id == player.id ? pair!.white : pair!.black;
              onResultTap(player, opponent, pair!);
            }
          : null,
      child: Container(
        color: (pair != null && isCurrentRound && !pair.isResultEntered)
            ? AppTheme.primary.withValues(alpha: 0.05)
            : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _GridDataCell(
              opponentNumStr,
              minWidth: 60,
              color:
                  pair != null && !pair.isResultEntered ? Colors.black : color,
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
        ),
      ),
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
  final VoidCallback? onTapResult;

  const _StandingsTile({
    required this.rank,
    required this.player,
    required this.isTopThree,
    required this.history,
    required this.playerNumbers,
    this.onTapResult,
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
              width: 110,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
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
                      if (onTapResult != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: InkWell(
                            onTap: onTapResult,
                            child: const Icon(
                              Icons.edit_note,
                              size: 18,
                              color: AppTheme.primary,
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
                  if (player.groupId != null)
                    Text(
                      '${player.groupId}조',
                      style: const TextStyle(
                        color: AppTheme.primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _LeagueMatrixTab extends ConsumerWidget {
  final MacmahonState state;
  final List<MacmahonPlayer> sorted;
  final Map<String, int> playerNumbers;
  final Map<String, int> playerRanks;
  final void Function(MacmahonPlayer, MacmahonPlayer, MacmahonPair) onResultTap;
  final bool isExport;

  const _LeagueMatrixTab({
    required this.state,
    required this.sorted,
    required this.playerNumbers,
    required this.playerRanks,
    required this.onResultTap,
    this.isExport = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (sorted.isEmpty) {
      return const Center(child: Text('선수가 없습니다.'));
    }

    final Map<String, List<MacmahonPlayer>> groups = {};
    for (final p in sorted) {
      final gId = p.groupId ?? "전체";
      groups.putIfAbsent(gId, () => []).add(p);
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...groups.entries.map((entry) {
          final groupName = entry.key;
          final groupPlayers = entry.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (groups.length > 1)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    '$groupName조 리그표',
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary),
                  ),
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: isExport ? const NeverScrollableScrollPhysics() : null,
                child: _buildGroupTable(context, ref, groupPlayers),
              ),
              const SizedBox(height: 32),
            ],
          );
        }),
        if (!isExport && state.currentPairing != null && state.currentPairs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: state.currentPairs.every((p) => p.isResultEntered)
                    ? () {
                        ref.read(macmahonProvider.notifier).advanceRound();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('라운드가 종료되었습니다.')),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  state.currentPairs.every((p) => p.isResultEntered)
                      ? '${state.currentRound}라운드 종료 및 다음 대진 생성'
                      : '결과 입력 대기 중 (${state.currentPairs.where((p) => p.isResultEntered).length}/${state.currentPairs.length})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );

    if (isExport) return content;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      padding: const EdgeInsets.all(16),
      child: content,
    );
  }

  Widget _buildGroupTable(BuildContext context, WidgetRef ref, List<MacmahonPlayer> groupPlayers) {
    final n = groupPlayers.length;
    final headerColor = Colors.grey.shade100;

    return Table(
      border: TableBorder.all(color: Colors.grey.shade400, width: 1.5),
      columnWidths: {
        0: const FixedColumnWidth(160),
        for (int i = 1; i <= n; i++) i: const FixedColumnWidth(70),
        n + 1: const FixedColumnWidth(80),
        n + 2: const FixedColumnWidth(80),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          decoration: BoxDecoration(color: headerColor),
          children: [
            const _MatrixCell('선수명', bold: true, fontSize: 14),
            for (int i = 1; i <= n; i++)
              _MatrixCell('$i', bold: true, fontSize: 14),
            const _MatrixCell('승점', bold: true, fontSize: 14),
            const _MatrixCell('순위', bold: true, fontSize: 14),
          ],
        ),
        for (int i = 0; i < n; i++)
          TableRow(
            children: [
              _MatrixCell('${i + 1}. ${groupPlayers[i].name}',
                  bold: true, textAlign: TextAlign.left, fontSize: 14),
              for (int j = 0; j < n; j++)
                _buildResultCell(context, ref, groupPlayers[i], groupPlayers[j], i == j),
              _MatrixCell(groupPlayers[i].wins.toString(),
                  bold: true, fontSize: 16),
              _MatrixCell('${playerRanks[groupPlayers[i].id] ?? "-"}위',
                  bold: true, fontSize: 16, color: AppTheme.primary),
            ],
          ),
      ],
    );
  }

  Widget _buildResultCell(BuildContext context, WidgetRef ref, MacmahonPlayer p1, MacmahonPlayer p2, bool isSelf) {
    if (isSelf) {
      return Container(
        height: 70,
        color: Colors.grey.shade200,
        child: const Center(child: Text('\\', style: TextStyle(color: Colors.grey))),
      );
    }

    String resultText = '';
    Color? textColor;
    bool alreadyPlayed = false;

    for (final round in state.history) {
      for (final pair in round.pairs) {
        if ((pair.black.id == p1.id && pair.white.id == p2.id) ||
            (pair.black.id == p2.id && pair.white.id == p1.id)) {
          alreadyPlayed = true;
          if (pair.winnerId == p1.id) {
            resultText = 'O';
            textColor = Colors.blue;
          } else if (pair.winnerId == p2.id) {
            resultText = 'X';
            textColor = Colors.red;
          } else if (pair.isResultEntered) {
            resultText = '△';
            textColor = Colors.orange;
          }
          break;
        }
      }
    }

    MacmahonPair? currentPair;
    if (!alreadyPlayed && state.currentPairing != null) {
      for (final pair in state.currentPairing!.pairs) {
        if ((pair.black.id == p1.id && pair.white.id == p2.id) ||
            (pair.black.id == p2.id && pair.white.id == p1.id)) {
          currentPair = pair;
          if (pair.isResultEntered) {
            if (pair.winnerId == p1.id) {
              resultText = 'O';
              textColor = Colors.blue;
            } else if (pair.winnerId == p2.id) {
              resultText = 'X';
              textColor = Colors.red;
            } else {
              resultText = '△';
              textColor = Colors.orange;
            }
          }
          break;
        }
      }
    }

    return GestureDetector(
      onTap: currentPair == null
          ? null
          : () => onResultTap(p1, p2, currentPair!),
      child: Container(
        height: 70,
        color: currentPair != null && !currentPair.isResultEntered ? AppTheme.primary.withOpacity(0.05) : null,
        alignment: Alignment.center,
        child: Text(
          resultText.isEmpty ? '-' : resultText,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: textColor ?? Colors.grey,
          ),
        ),
      ),
    );
  }

}

class _ResultButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ResultButton({required this.label, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _MatrixCell extends StatelessWidget {
  final String text;
  final bool bold;
  final TextAlign textAlign;
  final Color? color;
  final double fontSize;

  const _MatrixCell(
    this.text, {
    this.bold = false,
    this.textAlign = TextAlign.center,
    this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.center,
      child: Text(
        text,
        textAlign: textAlign,
        style: TextStyle(
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          fontSize: fontSize,
          color: color,
        ),
      ),
    );
  }
}
