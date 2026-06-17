import '../../domain/entities/tournament_state.dart';
import '../../../../core/constants/tournament_enums.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:math' as math;
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/macmahon_entities.dart';
import '../providers/macmahon_provider.dart';
import '../../../../core/services/export_service.dart';
import '../../../../core/utils/macmahon_utils.dart';
import 'package:flutter/services.dart';
import '../providers/history_provider.dart';
import 'knockout_selection_screen.dart';
import 'bracket_screen.dart';

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

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);
    final players = state.currentSectionPlayers;

    final sorted = <MacmahonPlayer>[];
    final playerRanks = <String, int>{};
    MacmahonUtils.computeStandings(
      players, state.format, sorted, playerRanks,
      useHeadToHead: state.currentSectionData.useHeadToHead,
    );

    final playerNumbers = _getPlayerNumbers(players);

    // 현재 단계가 리그전인지 판별 (일반 리그 또는 리그+토너먼트의 예선 단계)
    final isLeagueStage = state.format == TournamentFormat.league ||
        (state.format == TournamentFormat.leagueAndKnockout &&
            state.stage == 1);

    final isMixedFormat = state.format == TournamentFormat.leagueAndKnockout;
    final showBracketTab = state.format == TournamentFormat.knockout ||
        (isMixedFormat && state.stage == 2);
    
    // 혼합 방식 본선일 때는 3개 탭 (순위표, 리그표, 대진표)
    final bool showLeagueGridWithBracket = isMixedFormat && state.stage == 2;
    final tabsCount = showLeagueGridWithBracket ? 3 : 2;

    final currentData = state.currentSectionData;
    final currentPairing = currentData.currentPairing;
    final isFinished = currentData.isFinished;
    final allResultsEntered = currentPairing != null &&
        currentPairing.pairs.every((p) => p.isResultEntered);

    final qCount = currentData.knockoutQualifiers.isNotEmpty
        ? currentData.knockoutQualifiers.length
        : state.currentSectionPlayers.length;

    final currentRound = state.currentSectionData.currentRound;
    // 리그전이면 고정된 추천 라운드, 토너먼트면 진출 인원 기준 log2(N)
    final totalRounds = isLeagueStage
        ? MacmahonUtils.calculateRecommendedRounds(state.currentSectionPlayers.length)
        : (qCount > 1 ? (math.log(qCount) / math.log(2)).ceil() : 1);
        
    final isLastRound = currentRound >= totalRounds;

    final roundName = MacmahonUtils.getRoundName(
      currentRound: currentRound,
      totalRounds: totalRounds,
      format: state.format,
      playerCount: qCount,
      stage: state.stage,
    );

    final appBar = AppBar(
      title: Text(
        state.tournamentName.isNotEmpty
            ? '${state.tournamentName} - ${state.selectedSection} ($roundName)'
            : '${state.selectedSection} ($roundName)',
      ),
      bottom: isLeagueStage
          ? null
          : TabBar(
              isScrollable: true,
              tabs: [
                const Tab(text: '순위표', icon: Icon(Icons.format_list_numbered)),
                if (showLeagueGridWithBracket || !showBracketTab)
                  const Tab(text: '리그표 (Grid)', icon: Icon(Icons.grid_on)),
                if (showBracketTab)
                  const Tab(
                      text: '대진표 (Bracket)',
                      icon: Icon(Icons.account_tree_outlined)),
              ],
              indicatorColor: AppTheme.primary,
              labelColor: AppTheme.primary,
              unselectedLabelColor: AppTheme.textSecondary,
            ),
      actions: [
        if (!isFinished && !isLeagueStage) ...[
          if (allResultsEntered)
            TextButton.icon(
              onPressed: () => _handleAdvanceAndPairing(context, ref, isLastRound),
              icon: Icon(isLastRound ? Icons.emoji_events : Icons.bolt,
                  color: Colors.blue),
              label: Text(
                isLastRound ? '대회 종료 및 확정' : '라운드 종료 및 다음 대진 생성',
                style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
              ),
            )
          else if (currentPairing == null)
            TextButton.icon(
              onPressed: () => _handleGeneratePairing(context, ref),
              icon: const Icon(Icons.bolt, color: Colors.orange),
              label: const Text('대진 생성', style: TextStyle(color: Colors.orange)),
            ),
        ],
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
            playerRanks,
            isLeagueStage,
          ),
        ),
        Builder(
          builder: (innerContext) => IconButton(
            tooltip: '이미지로 저장 (PNG)',
            icon: const Icon(Icons.image_outlined),
            onPressed: () async {
              // 리그전이 아닐 때만 탭 인덱스 조회 (리그전은 탭이 없음)
              int currentIndex = 0;
              if (!isLeagueStage) {
                currentIndex = DefaultTabController.of(innerContext).index;
              }

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
                    Text('${state.selectedSection} - ${isLeagueStage ? "리그표" : (currentIndex == 0 ? "순위표" : (currentIndex == 1 && showLeagueGridWithBracket ? "리그표" : (showBracketTab && (currentIndex == tabsCount - 1) ? "대진표" : "대국결과표")))}', 
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
                            : (currentIndex == 1 && showLeagueGridWithBracket
                                ? _LeagueMatrixTab(
                                    state: state,
                                    sorted: sorted,
                                    playerNumbers: playerNumbers,
                                    playerRanks: playerRanks,
                                    onResultTap: (_, __, ___) {},
                                    isExport: true,
                                  )
                                : (showBracketTab && (currentIndex == tabsCount - 1)
                                    ? const BracketScreen()
                                    : _ResultGridTab(
                                        state: state,
                                        sorted: sorted,
                                        playerNumbers: playerNumbers,
                                        playerRanks: playerRanks,
                                        verticalController: ScrollController(),
                                        horizontalController: ScrollController(),
                                        onResultTap: (_, __, ___) {},
                                        isExport: true,
                                      )))),
                  ],
                ),
              ),
            );

            // 전체 길이를 위해 예상 높이 계산
            double estimatedHeight = 300; 
            double estimatedWidth = 1200;

            if (isLeagueStage || (currentIndex == 1 && showLeagueGridWithBracket)) {
              final Map<String, int> groupCounts = {};
              for (var p in sorted) {
                final gid = p.groupId ?? "A";
                groupCounts[gid] = (groupCounts[gid] ?? 0) + 1;
              }
              for (var count in groupCounts.values) {
                estimatedHeight += 150 + (count * 80);
              }
            } else if (showBracketTab && currentIndex == tabsCount - 1) {
              // 대진표 캡처 크기 계산
              final qCount = currentData.knockoutQualifiers.isNotEmpty ? currentData.knockoutQualifiers.length : players.length;
              final n = qCount > 1 ? (math.log(qCount) / math.log(2)).ceil() : 1;
              if (currentData.bracketStyle == BracketStyle.compact) {
                estimatedWidth = (320.0 + 50.0) * math.pow(2, n - 1).toInt() + 250;
                estimatedHeight = n * (140.0 + 120.0) + 400;
              } else {
                final expectedLeafs = math.pow(2, n).toInt();
                final isVertical = currentData.bracketStyle == BracketStyle.classicVertical;
                if (isVertical) {
                  estimatedWidth = (280.0 + 100.0) * expectedLeafs + 250;
                  estimatedHeight = (n + 1) * (70.0 + 100.0) + 300;
                } else {
                  estimatedWidth = n * (280.0 + 100.0) + 280.0 + 250;
                  estimatedHeight = (expectedLeafs - 1) * (70.0 + 100.0) + 70.0 + 250;
                }
              }
            } else {
              estimatedHeight += 200 + (sorted.length * 80);
            }
            estimatedHeight += 300; 

            // 명시적인 크기를 가진 컨테이너로 감싸서 캡처 라이브러리의 오동작 방지
            final wrapperWidget = Container(
              width: estimatedWidth,
              height: estimatedHeight,
              color: AppTheme.surface,
              alignment: Alignment.topCenter,
              child: exportWidget,
            );
            
            final fileNameSuffix = isLeagueStage ? "리그표" : (currentIndex == 0 ? "순위표" : (currentIndex == 1 && showLeagueGridWithBracket ? "리그표" : (showBracketTab && (currentIndex == tabsCount - 1) ? "대진표" : "대국결과표")));

            final imageBytes = await _screenshotController.captureFromWidget(
              wrapperWidget,
              context: context,
              targetSize: Size(estimatedWidth + 100, estimatedHeight + 100),
              delay: const Duration(milliseconds: 300),
            );

            final path = await ExportService.saveImageBytes(
              imageBytes,
              '${state.tournamentName.isNotEmpty ? state.tournamentName : "tournament"}_$fileNameSuffix',
            );
            
            if (path != null && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('이미지가 저장되었습니다: $path')),
              );
            }
          },
        ),
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
                        if (showLeagueGridWithBracket)
                          _LeagueMatrixTab(
                            state: state,
                            sorted: sorted,
                            playerNumbers: playerNumbers,
                            playerRanks: playerRanks,
                            onResultTap: (_, __, ___) {}, // 조회용
                          ),
                        if (!showBracketTab)
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
                        if (showBracketTab) const BracketScreen(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );

    if (isLeagueStage) {
      return Scaffold(
        appBar: appBar,
        body: content,
      );
    }

    return DefaultTabController(
      initialIndex: widget.initialIndex.clamp(0, tabsCount - 1),
      length: tabsCount,
      child: Builder(builder: (context) {
        return Scaffold(
          appBar: appBar,
          body: content,
        );
      }),
    );
  }

  Future<void> _handleAdvanceAndPairing(
      BuildContext context, WidgetRef ref, bool isLastRound) async {
    final title = isLastRound ? '대회 종료' : '라운드 종료 및 다음 대진 생성';
    final content = isLastRound
        ? '마지막 라운드입니다. 대회를 종료하고 최종 순위를 확정하시겠습니까?'
        : '현재 라운드를 종료하고 다음 라운드 대진을 자동으로 생성하시겠습니까?\n\n(더 이상 라운드를 진행하지 않고 여기서 대회를 종료할 수도 있습니다.)';

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 0),
              child: const Text('취소')),
          if (!isLastRound)
            TextButton(
                onPressed: () => Navigator.pop(ctx, 2),
                child: const Text('대회 종료', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 1),
              child: Text(isLastRound ? '종료 및 확정' : '종료 후 대진 생성')),
        ],
      ),
    );

    if (result != null && result > 0) {
      final notifier = ref.read(macmahonProvider.notifier);
      // 1. 라운드 종료
      notifier.advanceRound();

      if (result == 2) {
        // 조기 종료의 경우
        notifier.toggleTournamentStatus(); // 대회를 종료 상태로 전환
        ref.read(tournamentHistoryProvider.notifier).loadHistory();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('대회가 종료되었습니다. 최종 순위가 확정되었습니다.')),
          );
        }
      } else {
        // 2. 마지막 라운드가 아니면 즉시 다음 대진 생성
        if (!isLastRound) {
          await notifier.generatePairing();
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isLastRound ? '대회가 종료되었습니다.' : '다음 라운드 대진이 생성되었습니다.')),
          );
        }
      }
    }
  }

  Future<void> _handleGeneratePairing(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('다음 대진 생성'),
        content: const Text('다음 라운드 대진을 자동으로 생성하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('생성하기')),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(macmahonProvider.notifier).generatePairing();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('새로운 대진이 생성되었습니다.')),
        );
      }
    }
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
              Navigator.pop(ctx);
              ref
                  .read(macmahonProvider.notifier)
                  .recordResultByPlayers(p1.id, p2.id, p1.id);
            },
          ),
          _ResultButton(
            label: 'X (패)',
            color: Colors.red,
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(macmahonProvider.notifier)
                  .recordResultByPlayers(p1.id, p2.id, p2.id);
            },
          ),
          _ResultButton(
            label: '△ (무)',
            color: Colors.orange,
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(macmahonProvider.notifier)
                  .recordResultByPlayers(p1.id, p2.id, null);
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

        // 3차: 다중 조건 정렬
        tiedPlayers.sort((a, b) {
          if (!isLeague) {
            // 맥마흔 & 스위스리그: 선승(누진) -> 승자승(1:1 및 다자간) -> SODOS -> SOS
            final cumCmp = b.cumulativeScore.compareTo(a.cumulativeScore);
            if (cumCmp != 0) return cumCmp;

            if (a.defeatedOpponents.contains(b.id)) return -1;
            if (b.defeatedOpponents.contains(a.id)) return 1;

            final wA = internalWins[a.id]!;
            final wB = internalWins[b.id]!;
            if (wA != wB) return wB.compareTo(wA);

            final sodosCmp = b.sodos.compareTo(a.sodos);
            if (sodosCmp != 0) return sodosCmp;

            final sosCmp = b.sos.compareTo(a.sos);
            if (sosCmp != 0) return sosCmp;
          } else {
            // 풀리그: 승자승 -> 내부 승수 -> SODOS
            if (a.defeatedOpponents.contains(b.id)) return -1;
            if (b.defeatedOpponents.contains(a.id)) return 1;

            final wA = internalWins[a.id]!;
            final wB = internalWins[b.id]!;
            if (wA != wB) return wB.compareTo(wA);

            final sodosCmp = b.sodos.compareTo(a.sodos);
            if (sodosCmp != 0) return sodosCmp;
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
    Map<String, int> playerRanks,
    bool isLeague,
  ) async {
    try {
      final path = await ExportService.exportToExcel(
        sorted,
        tournamentName.isEmpty ? 'macmahon_tournament' : tournamentName,
        history: history,
        playerNumbers: playerNumbers,
        playerRanks: playerRanks,
        isLeague: isLeague,
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
                SizedBox(
                  width: 40,
                  child: Center(
                    child: Text(
                      '순위',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
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

    // 선수별 라운드 종료 후 MMS 히스토리 계산 (O(R*N)으로 최적화)
    final playerMmsByRound = <String, List<double>>{};
    for (final p in sorted) {
      playerMmsByRound[p.id] = [p.initialMms];
    }

    // 각 라운드별 선수 대진 맵 사전 생성 (연산량 대폭 감소)
    final List<Map<String, MacmahonPair>> roundPairMaps = [];

    for (int r = 0; r < state.history.length; r++) {
      final roundResult = state.history[r];
      final Map<String, MacmahonPair> roundPairMap = {};
      for (final pair in roundResult.pairs) {
        roundPairMap[pair.black.id] = pair;
        roundPairMap[pair.white.id] = pair;
      }
      roundPairMaps.add(roundPairMap);

      for (final p in sorted) {
        double current = playerMmsByRound[p.id]!.last;
        final pair = roundPairMap[p.id];

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
      // 현재 진행 중인 대진도 맵에 추가
      final Map<String, MacmahonPair> currentPairMap = {};
      for (final pair in state.currentPairing!.pairs) {
        currentPairMap[pair.black.id] = pair;
        currentPairMap[pair.white.id] = pair;
      }
      roundPairMaps.add(currentPairMap);
    }
    final roundsCount = allRounds.length;
    const headerGreen = Color(0xFFDCEDC8);

    // 순번(playerNum) 기준으로 정렬
    final gridPlayers = List<MacmahonPlayer>.from(sorted)
      ..sort((a, b) =>
          (playerNumbers[a.id] ?? 999).compareTo(playerNumbers[b.id] ?? 999));

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
            for (final player in gridPlayers)
              _buildDataRow(
                context,
                player,
                playerNumbers[player.id]!,
                playerNumbers,
                allRounds,
                roundPairMaps,
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
    List<Map<String, MacmahonPair>> roundPairMaps,
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
            roundPairMaps[r],
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
    Map<String, MacmahonPair> roundPairMap,
    Map<String, int> playerNumbers,
    double? mmsAfterRound,
  ) {
    final pair = roundPairMap[player.id];

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

    final players = state.currentSectionPlayers;

    // 조별로 분류
    final Map<String, List<MacmahonPlayer>> groups = {};
    for (final p in sorted) {
      final gId = p.groupId ?? "전체";
      groups.putIfAbsent(gId, () => []).add(p);
    }

    // 리그 매트릭스 행/열 순서는 선수 번호(등록 순서) 기준으로 '고정'
    // → 결과 입력/수정 시 순위가 변해도 행/열이 움직이지 않음
    final Map<String, List<MacmahonPlayer>> stableGroups = {};
    for (final entry in groups.entries) {
      final stablePlayers = List<MacmahonPlayer>.from(entry.value)
        ..sort((a, b) => (playerNumbers[a.id] ?? 0).compareTo(playerNumbers[b.id] ?? 0));
      stableGroups[entry.key] = stablePlayers;
    }
    // 조 이름도 알파벳 순 정렬
    final sortedGroupKeys = stableGroups.keys.toList()..sort();


    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 승자승 적용 여부 토글 (리그전 전용) ──
        if (!isExport)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: state.currentSectionData.useHeadToHead
                  ? AppTheme.primary.withValues(alpha: 0.08)
                  : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: state.currentSectionData.useHeadToHead
                    ? AppTheme.primary.withValues(alpha: 0.3)
                    : Colors.grey.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.compare_arrows,
                  size: 20,
                  color: state.currentSectionData.useHeadToHead
                      ? AppTheme.primary
                      : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '동률 시 승자승 적용',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: state.currentSectionData.useHeadToHead
                              ? AppTheme.primary
                              : Colors.grey[700],
                        ),
                      ),
                      Text(
                        state.currentSectionData.useHeadToHead
                            ? '동점자 간 직접 대결 결과로 순위를 결정합니다'
                            : '동점자는 공동 순위로 처리됩니다',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: state.currentSectionData.useHeadToHead,
                  activeColor: AppTheme.primary,
                  onChanged: (val) {
                    ref.read(macmahonProvider.notifier)
                        .updateSectionSettings(useHeadToHead: val);
                  },
                ),
              ],
            ),
          ),
        ...sortedGroupKeys.map((groupName) {
          final groupPlayers = stableGroups[groupName]!;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (stableGroups.length > 1)
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
                onPressed: (() {
                  final sectionPlayers = players;
                  final playerGroupMap = {for (var p in sectionPlayers) p.id: p.groupId ?? ""};
                  
                  final Map<String, bool> pairEnteredStatus = {};
                  
                  // 1. 현재 대진표 기준 초기화
                  for (final p in state.currentPairs) {
                    final bId = p.black.id;
                    final wId = p.white.id;
                    if (playerGroupMap.containsKey(bId) && 
                        playerGroupMap.containsKey(wId) &&
                        playerGroupMap[bId] == playerGroupMap[wId]) {
                      final ids = [bId, wId]..sort();
                      pairEnteredStatus[ids.join('|')] = p.isResultEntered;
                    }
                  }
                  
                  // 2. 과거 기록(history) 우선순위 적용 (매트릭스 렌더링과 동일한 로직)
                  for (final round in state.history) {
                    for (final p in round.pairs) {
                      final bId = p.black.id;
                      final wId = p.white.id;
                      if (playerGroupMap.containsKey(bId) && 
                          playerGroupMap.containsKey(wId) &&
                          playerGroupMap[bId] == playerGroupMap[wId]) {
                        final ids = [bId, wId]..sort();
                        final key = ids.join('|');
                        // 현재 대상인 대진이면서 과거에 이미 완료된 상태라면 덮어씀
                        if (pairEnteredStatus.containsKey(key) && p.isResultEntered) {
                          pairEnteredStatus[key] = true;
                        }
                      }
                    }
                  }
                  
                  if (pairEnteredStatus.isEmpty) return null;
                  return pairEnteredStatus.values.every((entered) => entered)
                      ? () {
                          ref.read(macmahonProvider.notifier).advanceRound();
                          
                          // 리그+토너먼트에서 예선 종료 시 바로 본선 선발 화면으로 이동
                          if (state.format == TournamentFormat.leagueAndKnockout && state.stage == 1) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const KnockoutSelectionScreen()),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('라운드가 종료되었습니다.')),
                            );
                          }
                        }
                      : null;
                })(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: (() {
                  final sectionPlayers = players;
                  final playerGroupMap = {for (var p in sectionPlayers) p.id: p.groupId ?? ""};
                  
                  final Map<String, bool> pairEnteredStatus = {};
                  
                  for (final p in state.currentPairs) {
                    final bId = p.black.id;
                    final wId = p.white.id;
                    if (playerGroupMap.containsKey(bId) && 
                        playerGroupMap.containsKey(wId) &&
                        playerGroupMap[bId] == playerGroupMap[wId]) {
                      final ids = [bId, wId]..sort();
                      pairEnteredStatus[ids.join('|')] = p.isResultEntered;
                    }
                  }
                  
                  for (final round in state.history) {
                    for (final p in round.pairs) {
                      final bId = p.black.id;
                      final wId = p.white.id;
                      if (playerGroupMap.containsKey(bId) && 
                          playerGroupMap.containsKey(wId) &&
                          playerGroupMap[bId] == playerGroupMap[wId]) {
                        final ids = [bId, wId]..sort();
                        final key = ids.join('|');
                        if (pairEnteredStatus.containsKey(key) && p.isResultEntered) {
                          pairEnteredStatus[key] = true;
                        }
                      }
                    }
                  }
                  
                  final total = pairEnteredStatus.length;
                  final done = pairEnteredStatus.values.where((entered) => entered).length;
                  final remaining = total - done;
                  
                  if (remaining == 0) {
                    return Text(
                      '결과 확정 / 다음 단계로 진행',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    );
                  }
                  return Text(
                    '결과 입력 대기 ($remaining경기 미입력)',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  );
                })(),
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

    MacmahonPair? targetPair;
    String resultText = '';
    Color? textColor;
    bool alreadyPlayed = false;
    for (final round in state.history) {
      for (final pair in round.pairs) {
        if ((pair.black.id == p1.id && pair.white.id == p2.id) ||
            (pair.black.id == p2.id && pair.white.id == p1.id)) {
          alreadyPlayed = true;
          targetPair = pair;
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
      if (alreadyPlayed) break;
    }

    if (!alreadyPlayed && state.currentPairing != null) {
      for (final pair in state.currentPairing!.pairs) {
        if ((pair.black.id == p1.id && pair.white.id == p2.id) ||
            (pair.black.id == p2.id && pair.white.id == p1.id)) {
          targetPair = pair;
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
      onTap: targetPair == null
          ? null
          : () => onResultTap(p1, p2, targetPair!),
      child: Container(
        height: 70,
        color: targetPair != null && !targetPair.isResultEntered ? AppTheme.primary.withOpacity(0.05) : null,
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
