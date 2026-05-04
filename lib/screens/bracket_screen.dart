import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../app_theme.dart';
import '../providers/macmahon_provider.dart';
import '../models/macmahon_pair.dart';

class BracketScreen extends ConsumerWidget {
  const BracketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);
    final qualifiers = state.currentSectionData.knockoutQualifiers;

    // 토너먼트 라운드만 필터링
    bool isKnockout(PairingResult r) =>
        qualifiers.isEmpty || r.pairs.any((p) =>
            qualifiers.contains(p.black.id) || qualifiers.contains(p.white.id));

    final knockoutHistory = state.history.where(isKnockout).toList();
    final currentPairing = state.currentPairing;
    final currentIsKnockout = currentPairing != null && isKnockout(currentPairing);

    final qCount = qualifiers.isNotEmpty ? qualifiers.length : state.currentSectionPlayers.length;
    final totalRounds = qCount > 1 ? (math.log(qCount) / math.log(2)).ceil() : 1;

    // displayRounds[0] = 1라운드(하단), displayRounds[n-1] = 결승(상단)
    final List<PairingResult?> displayRounds = List.filled(totalRounds, null);
    for (int i = 0; i < knockoutHistory.length && i < totalRounds; i++) {
      displayRounds[i] = knockoutHistory[i];
    }
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
          title: const Text('승자를 선택하세요', textAlign: TextAlign.center),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _WinnerBtn(
                label: '흑: ${pair.black.name}',
                color: Colors.black87,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(macmahonProvider.notifier).recordResultByPlayers(
                      pair.black.id, pair.white.id, pair.black.id);
                },
              ),
              const SizedBox(height: 12),
              _WinnerBtn(
                label: '백: ${pair.white.name}',
                color: Colors.indigo,
                onTap: () {
                  Navigator.pop(context);
                  ref.read(macmahonProvider.notifier).recordResultByPlayers(
                      pair.black.id, pair.white.id, pair.white.id);
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
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
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.account_tree_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          const Text('본선 대진이 아직 생성되지 않았습니다.',
                              style: TextStyle(color: Colors.grey, fontSize: 16)),
                          const SizedBox(height: 24),
                          if (state.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                            ),
                          if (state.isLoading)
                            const CircularProgressIndicator()
                          else
                            ElevatedButton.icon(
                              onPressed: () async {
                                await ref.read(macmahonProvider.notifier).generatePairing();
                              },
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('1라운드 대진표 생성', style: TextStyle(fontWeight: FontWeight.bold)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                        ],
                      ),
                    )
                  : _BracketTree(
                      displayRounds: displayRounds,
                      totalRounds: totalRounds,
                      currentRoundIdx: currentRoundIdx,
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
                          final newHist = s.history.where(isKnockout).toList();
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
  final void Function(MacmahonPair) onMatchTap;

  static const double kW = 168.0;
  static const double kH = 72.0;
  static const double kVGap = 80.0;
  static const double kHGap = 20.0;

  const _BracketTree({
    required this.displayRounds,
    required this.totalRounds,
    required this.currentRoundIdx,
    required this.onMatchTap,
  });

  @override
  Widget build(BuildContext context) {
    final n = totalRounds;
    final leafSlotW = kW + kHGap;
    final leafCount = math.pow(2, n - 1).toInt();
    final totalW = leafCount * leafSlotW;
    final totalH = n * kH + (n - 1) * kVGap + 100;

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

      for (int m = 0; m < expected; m++) {
        final xc = cx(r, m);
        final pair = (round != null && m < round.pairs.length) ? round.pairs[m] : null;

        // 선수 이름: pair 있으면 pair에서, 없으면 하위 라운드 승자에서
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

    // 결승 우승자 배지
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
