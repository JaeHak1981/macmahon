import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../app_theme.dart';
import '../providers/macmahon_provider.dart';
import '../models/macmahon_pair.dart';
import '../models/macmahon_player.dart';
import '../utils/macmahon_utils.dart';

class BracketScreen extends ConsumerStatefulWidget {
  const BracketScreen({super.key});

  @override
  ConsumerState<BracketScreen> createState() => _BracketScreenState();
}

class _BracketScreenState extends ConsumerState<BracketScreen> {
  bool _isManualMode = false;
  List<MacmahonPlayer>? _manualPlayers;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);
    final qualifiers = state.currentSectionData.knockoutQualifiers;
    final currentData = state.currentSectionData;

    // 토너먼트 대국인지 판별 (본선 진출자들끼리의 대국이며, 조별 리그가 아닌 대국)
    // LeagueAndKnockout 방식에서 Stage 2의 기록만 가져오기 위해
    // 예선 종료 시점 이후의 히스토리만 고려하거나, 선수 구성을 확인
    bool isKnockoutMatch(PairingResult r) {
      if (qualifiers.isEmpty) return true; // 전체 토너먼트인 경우
      // 모든 대진의 선수가 본선 진출자 명단에 있어야 하며, 부전승자도 진출자여야 함
      final allKnockoutPlayers = r.pairs.every((p) => 
        qualifiers.contains(p.black.id) && qualifiers.contains(p.white.id));
      final byeKnockout = r.byePlayers.every((b) => qualifiers.contains(b.id));
      
      // 추가로, 예선(Stage 1)은 보통 조별 리그이므로 
      // 본선 단계(Stage 2)의 히스토리인지 확인하는 것이 가장 정확함
      // 현재 PairingResult에 stage 정보가 없으므로, 선수 구성을 주 기준으로 함
      return allKnockoutPlayers && byeKnockout;
    }

    // 본선 히스토리 추출
    final knockoutHistory = state.history.where(isKnockoutMatch).toList();
    final currentPairing = state.currentPairing;
    
    // 현재 페어링이 본선 페어링인지 확인
    final currentIsKnockout = currentData.stage == 2 && currentPairing != null;

    final qCount = qualifiers.isNotEmpty
        ? qualifiers.length
        : state.currentSectionPlayers.length;
    
    // 강수 계산 (8강 -> 3라운드, 16강 -> 4라운드)
    final totalRounds = qCount > 1 ? (math.log(qCount) / math.log(2)).ceil() : 1;

    // 본선용 라운드 배열 ([0]=8강, [1]=4강, [2]=결승)
    final List<PairingResult?> displayRounds = List.filled(totalRounds, null);
    
    // 히스토리 채우기
    for (int i = 0; i < knockoutHistory.length && i < totalRounds; i++) {
      displayRounds[i] = knockoutHistory[i];
    }
    
    // 현재 진행 중인 라운드 채우기
    if (currentIsKnockout && knockoutHistory.length < totalRounds) {
      displayRounds[knockoutHistory.length] = currentPairing;
    }

    final currentRoundIdx = currentIsKnockout ? knockoutHistory.length : -1;
    final currentRoundDone = currentIsKnockout &&
        currentPairing.pairs.every((p) => p.isResultEntered);
    final tournamentDone = knockoutHistory.length >= totalRounds;

    void onMatchTap(MacmahonPair pair) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('경기 결과 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('${pair.black.name} 승리'),
                onTap: () {
                  ref.read(macmahonProvider.notifier).recordResult(
                        blackId: pair.black.id,
                        whiteId: pair.white.id,
                        winnerId: pair.black.id,
                      );
                  Navigator.pop(context);
                },
              ),
              ListTile(
                title: Text('${pair.white.name} 승리'),
                onTap: () {
                  ref.read(macmahonProvider.notifier).recordResult(
                        blackId: pair.black.id,
                        whiteId: pair.white.id,
                        winnerId: pair.white.id,
                      );
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      );
    }

    Widget buildEmptyState() {
      if (_isManualMode) {
        final players = _manualPlayers ?? state.currentSectionPlayers;
        return Container(
          width: 350,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Row(
                children: [
                  Icon(Icons.sort, color: AppTheme.primary, size: 20),
                  SizedBox(width: 8),
                  Text('대진 순서 직접 조정',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text('드래그하여 선수들의 위치를 바꾸세요.\n상단부터 2명씩 경기가 생성됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              ),
              const Divider(),
              SizedBox(
                height: 350,
                child: ReorderableListView.builder(
                  itemCount: players.length,
                  onReorder: (oldIndex, newIndex) {
                    setState(() {
                      if (newIndex > oldIndex) newIndex -= 1;
                      final list = List<MacmahonPlayer>.from(players);
                      final player = list.removeAt(oldIndex);
                      list.insert(newIndex, player);
                      _manualPlayers = list;
                    });
                  },
                  itemBuilder: (context, index) {
                    final p = players[index];
                    final isEven = (index ~/ 2) % 2 == 0;
                    return Card(
                      key: ValueKey(p.id),
                      elevation: 0,
                      color: isEven ? Colors.blue.shade50 : Colors.green.shade50,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      child: ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primary,
                          child: Text('${index + 1}',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.white)),
                        ),
                        title: Text(p.name,
                            style:
                                const TextStyle(fontWeight: FontWeight.w500)),
                        trailing: const Icon(Icons.drag_handle, size: 20),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() {
                        _isManualMode = false;
                        _manualPlayers = null;
                      }),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => ref
                          .read(macmahonProvider.notifier)
                          .generateManualPairing(players),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('확정'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }

      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_tree_outlined,
                size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('본선 대진이 아직 생성되지 않았습니다.',
                style: TextStyle(color: Colors.grey, fontSize: 16)),
            const SizedBox(height: 24),
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(state.errorMessage!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (state.isLoading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      await ref
                          .read(macmahonProvider.notifier)
                          .generatePairing();
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('자동 시드 배정 생성',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => setState(() => _isManualMode = true),
                    icon: const Icon(Icons.edit_note),
                    label: const Text('선수 순서 직접 조정하기 (수동)'),
                  ),
                ],
              ),
          ],
        ),
      );
    }

    final body = Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              padding: const EdgeInsets.all(32),
              child: displayRounds.every((r) => r == null)
                  ? buildEmptyState()
                  : _BracketTree(
                      displayRounds: displayRounds,
                      totalRounds: totalRounds,
                      currentRoundIdx: currentRoundIdx,
                      qCount: qCount,
                      onMatchTap: onMatchTap,
                    ),
            ),
          ),
        ),
        if (!tournamentDone && currentIsKnockout)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: currentRoundDone
                      ? () async {
                          ref.read(macmahonProvider.notifier).advanceRound();
                          final s = ref.read(macmahonProvider);
                          final newHist =
                              s.history.where(isKnockoutMatch).toList();
                          if (newHist.length < totalRounds) {
                            await ref.read(macmahonProvider.notifier).generatePairing();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                  label: Text(
                    currentRoundDone ? '다음 라운드 진행' : '결과를 모두 입력하세요',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey.shade300,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ),
          ),
        if (tournamentDone && knockoutHistory.isNotEmpty)
          _ChampionBanner(round: knockoutHistory.last),
      ],
    );

    final hasScaffold = context.findAncestorWidgetOfExactType<Scaffold>() != null;
    if (hasScaffold) return body;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${state.selectedSection} 토너먼트 대진표'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '본선 초기화 (예선으로 돌아가기)',
            icon: const Icon(Icons.history),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('본선 초기화'),
                  content: const Text('현재 본선 대진을 삭제하고 예선 결과(진출자 선택) 화면으로 돌아가시겠습니까?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: TextButton.styleFrom(foregroundColor: Colors.red),
                      child: const Text('초기화'),
                    ),
                  ],
                ),
              );

              if (confirmed == true) {
                await ref.read(macmahonProvider.notifier).resetKnockoutStage();
              }
            },
          ),
        ],
      ),
      body: body,
    );
  }
}

// ── 브라켓 트리 ────────────────────────────────────────────────────────────
class _BracketTree extends StatelessWidget {
  final List<PairingResult?> displayRounds;
  final int totalRounds;
  final int currentRoundIdx;
  final int qCount;
  final void Function(MacmahonPair) onMatchTap;

  static const double kW = 168.0;
  static const double kH = 72.0;
  static const double kVGap = 80.0;
  static const double kHGap = 20.0;

  const _BracketTree({
    required this.displayRounds,
    required this.totalRounds,
    required this.currentRoundIdx,
    required this.qCount,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = totalRounds;
    final leafSlotW = kW + kHGap;
    
    // 각 라운드 승자 이름 사전 계산
    final winnerMap = <int, Map<int, String>>{};
    for (int r = 0; r < n; r++) {
      final round = displayRounds[r];
      if (round == null) continue;
      winnerMap[r] = {};
      for (int m = 0; m < round.pairs.length; m++) {
        final p = round.pairs[m];
        if (p.isResultEntered && p.winnerId != null) {
          winnerMap[r]![m] =
              p.winnerId == p.black.id ? p.black.name : p.white.name;
        }
      }
    }

    double cx(int r, int m) {
      final slots = math.pow(2, r).toInt();
      return (m * slots + slots / 2.0) * leafSlotW;
    }

    double yTop(int r) => 80 + (n - 1 - r) * (kH + kVGap);

    final lines = <_Line>[];
    final cards = <Widget>[];

    for (int r = 0; r < n; r++) {
      final round = displayRounds[r];
      final y = yTop(r);
      final expected = math.pow(2, n - 1 - r).toInt();
      final isCurrent = r == currentRoundIdx;

      // 라운드 이름 헤더 추가
      final rName = MacmahonUtils.getRoundName(
        currentRound: r + 1,
        totalRounds: n,
        format: TournamentFormat.knockout,
        playerCount: qCount,
        stage: 2,
      );

      cards.add(Positioned(
        left: 0,
        right: 0,
        top: y - 25,
        child: Center(
          child: Text(
            rName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isCurrent ? AppTheme.primary : Colors.grey,
            ),
          ),
        ),
      ));

      for (int m = 0; m < expected; m++) {
        final xc = cx(r, m);
        final pair = (round != null && m < round.pairs.length) ? round.pairs[m] : null;

        String? pA = pair != null ? pair.black.name : (r > 0 && winnerMap.containsKey(r - 1) ? winnerMap[r - 1]![m * 2] : null);
        String? pB = pair != null ? pair.white.name : (r > 0 && winnerMap.containsKey(r - 1) ? winnerMap[r - 1]![m * 2 + 1] : null);

        String? winner;
        if (pair != null && pair.isResultEntered && pair.winnerId != null) {
          winner = pair.winnerId == pair.black.id ? pair.black.name : pair.white.name;
        }

        final tappable = isCurrent && pair != null && !pair.isResultEntered;

        cards.add(Positioned(
          left: xc - kW / 2,
          top: y,
          width: kW,
          height: kH,
          child: _MatchSlot(
            playerA: pA,
            playerB: pB,
            winnerName: winner,
            isCurrent: isCurrent,
            isCompleted: pair != null && pair.isResultEntered,
            onTap: tappable ? () => onMatchTap(pair) : null,
          ),
        ));

        // 연결선 (결승 제외)
        if (r < n - 1) {
          final pm = m ~/ 2;
          final pxc = cx(r + 1, pm);
          final py = yTop(r + 1);
          final midY = y - kVGap / 2;

          lines.add(_Line(xc, y, xc, midY));
          if (m % 2 == 0) {
            final sib = cx(r, m + 1);
            lines.add(_Line(xc, midY, sib, midY));
            lines.add(_Line(pxc, midY, pxc, py + kH));
          }
        }
      }
    }

    // 최종 우승자 배지
    final finalRound = displayRounds[n - 1];
    if (finalRound != null && finalRound.pairs.isNotEmpty) {
      final fp = finalRound.pairs.first;
      if (fp.isResultEntered && fp.winnerId != null) {
        final name = fp.winnerId == fp.black.id ? fp.black.name : fp.white.name;
        cards.add(Positioned(
          left: cx(n - 1, 0) - 70,
          top: 0,
          width: 140,
          child: _WinnerBadge(name: name),
        ));
      }
    }

    final totalW = leafSlotW * math.pow(2, n - 1);
    final totalH = n * kH + (n - 1) * kVGap + 200;

    return SizedBox(
      width: totalW,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(totalW, totalH),
            painter: _LinePainter(lines: lines),
          ),
          ...cards,
        ],
      ),
    );
  }
}

// ── 매치 슬롯 카드 ──────────────────────────────────────────────────────────
class _MatchSlot extends StatelessWidget {
  final String? playerA, playerB, winnerName;
  final bool isCurrent, isCompleted;
  final VoidCallback? onTap;

  const _MatchSlot({
    this.playerA, this.playerB, this.winnerName,
    required this.isCurrent, required this.isCompleted, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent && !isCompleted
        ? AppTheme.primary
        : isCompleted
            ? Colors.green.shade400
            : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isCurrent && !isCompleted ? 2 : 1.5),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.07), blurRadius: 4)],
        ),
        child: Column(
          children: [
            _SlotRow(
              name: playerA ?? '진출자 미정',
              isEmpty: playerA == null,
              isWinner: winnerName != null && winnerName == playerA,
              isLoser: isCompleted && winnerName != playerA && playerA != null,
              label: '흑',
            ),
            Divider(height: 1, thickness: 1, color: Colors.grey.shade200),
            _SlotRow(
              name: playerB ?? '진출자 미정',
              isEmpty: playerB == null,
              isWinner: winnerName != null && winnerName == playerB,
              isLoser: isCompleted && winnerName != playerB && playerB != null,
              label: '백',
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final String name, label;
  final bool isEmpty, isWinner, isLoser;
  const _SlotRow({required this.name, required this.label,
      required this.isEmpty, required this.isWinner, required this.isLoser});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        color: isWinner ? Colors.blue.shade50 : null,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Expanded(
              child: Text(name,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                  color: isEmpty ? Colors.grey.shade400
                      : isLoser ? Colors.grey.shade400
                      : Colors.black87,
                  fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  decoration: isLoser ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isWinner) Icon(Icons.emoji_events, color: Colors.amber.shade600, size: 16),
          ],
        ),
      ),
    );
  }
}

// ── 우승자 배지 ────────────────────────────────────────────────────────────
class _WinnerBadge extends StatelessWidget {
  final String name;
  const _WinnerBadge({required this.name});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.amber.shade400, Colors.orange.shade600]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.amber.withValues(alpha: 0.4), blurRadius: 10)],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.emoji_events, color: Colors.white, size: 24),
        const Text('🏆 우승', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
        Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ── 챔피언 배너 ────────────────────────────────────────────────────────────
class _ChampionBanner extends StatelessWidget {
  final PairingResult round;
  const _ChampionBanner({required this.round});
  @override
  Widget build(BuildContext context) {
    if (round.pairs.isEmpty) return const SizedBox.shrink();
    final fp = round.pairs.first;
    if (!fp.isResultEntered || fp.winnerId == null) return const SizedBox.shrink();
    final name = fp.winnerId == fp.black.id ? fp.black.name : fp.white.name;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      color: Colors.amber.shade50,
      child: Column(children: [
        const Text('🏆 최종 우승자', style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      ]),
    );
  }
}

// ── 승자 선택 버튼 ─────────────────────────────────────────────────────────
class _WinnerBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _WinnerBtn({required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ── 연결선 ─────────────────────────────────────────────────────────────────
class _Line { final double x1, y1, x2, y2; const _Line(this.x1, this.y1, this.x2, this.y2); }

class _LinePainter extends CustomPainter {
  final List<_Line> lines;
  const _LinePainter({required this.lines});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.grey.shade500..strokeWidth = 1.8..style = PaintingStyle.stroke;
    for (final l in lines) {
      canvas.drawLine(Offset(l.x1, l.y1), Offset(l.x2, l.y2), p);
    }
  }
  @override
  bool shouldRepaint(_LinePainter old) => true;
}
