import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/macmahon_entities.dart';
import '../providers/macmahon_provider.dart';
import '../providers/history_provider.dart';
import '../../../../core/constants/tournament_enums.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  bool _isSequentialR1 = false; // 기본값은 무작위

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);
    final notifier = ref.read(macmahonProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('${state.selectedSection}: 라운드 ${state.currentRound} 대진표'),
        actions: [
          if (state.history.isNotEmpty || state.currentPairing != null)
            IconButton(
              tooltip: '이전 단계로 (라운드 취소)',
              icon: const Icon(Icons.undo),
              onPressed: () => _showUndoConfirmDialog(context, notifier),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
        children: [
          // ── 페어링 실행 버튼 ─────────────────────────
          if (state.currentPairing == null)
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Icon(Icons.shuffle,
                      size: 64, color: AppTheme.primaryLight),
                  const SizedBox(height: 16),
                  Text(
                    '${state.currentSectionPlayers.length}명의 선수가 등록되어 있습니다.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  if (state.currentRound == 1) ...[
                    const Text(
                      '1라운드 매칭 방식을 선택해주세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text('무작위 추첨'),
                          selected: !_isSequentialR1,
                          selectedColor: AppTheme.primary,
                          backgroundColor: Colors.grey[200],
                          checkmarkColor: AppTheme.surface,
                          labelStyle: TextStyle(
                            color: !_isSequentialR1 ? AppTheme.surface : AppTheme.textPrimary,
                            fontWeight: !_isSequentialR1 ? FontWeight.w800 : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _isSequentialR1 = false);
                          },
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('등록순 매칭 (1-2, 3-4)'),
                          selected: _isSequentialR1,
                          selectedColor: AppTheme.primary,
                          backgroundColor: Colors.grey[200],
                          checkmarkColor: AppTheme.surface,
                          labelStyle: TextStyle(
                            color: _isSequentialR1 ? AppTheme.surface : AppTheme.textPrimary,
                            fontWeight: _isSequentialR1 ? FontWeight.w800 : FontWeight.w500,
                          ),
                          onSelected: (val) {
                            if (val) setState(() => _isSequentialR1 = true);
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    const Text(
                      '안티그래비티 규칙을 적용하여\n최적의 대진표를 생성합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => notifier.generatePairing(isSequentialForR1: _isSequentialR1),
                      icon: state.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.play_arrow),
                      label: Text(state.isLoading ? '페어링 중...' : '페어링 시작'),
                    ),
                  ),
                  if (state.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(state.errorMessage!,
                          style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            )
          else ...[
            // ── 총 비용 표시 배너 ─────────────────────
            Container(
              width: double.infinity,
              color: AppTheme.primary.withValues(alpha: 0.08),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  const Icon(Icons.check_circle,
                      color: AppTheme.primary, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${state.currentPairs.length}경기 확정'
                    '${state.currentPairing!.byePlayers.isNotEmpty ? " · 부전승: ${state.currentPairing!.byePlayers.length}명" : ""}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '총 비용: ${state.currentPairing!.totalCost.toStringAsFixed(0)}',
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 대진표 목록 ───────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.currentPairs.length +
                    state.currentPairing!.byePlayers.length,
                itemBuilder: (context, index) {
                  if (index < state.currentPairs.length) {
                    final pair = state.currentPairs[index];
                    return _PairCard(
                      pair: pair,
                      boardNumber: index + 1,
                      onResultSelected: (winnerId) {
                        notifier.recordResult(
                          blackId: pair.black.id,
                          whiteId: pair.white.id,
                          winnerId: winnerId,
                        );
                      },
                    );
                  }
                  final byePlayer = state.currentPairing!.byePlayers[index - state.currentPairs.length];
                  return _ByeCard(playerName: byePlayer.name);
                },
              ),
            ),

            // ── 라운드 종료 버튼 ───────────────────────
            if (state.currentPairing != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: state.currentPairs.every((p) => p.isResultEntered)
                      ? Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  notifier.advanceRound();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('라운드가 종료되었습니다. 다음 대진을 생성해주세요.')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.surface,
                                  foregroundColor: AppTheme.primary,
                                  side: const BorderSide(color: AppTheme.primary),
                                ),
                                icon: const Icon(Icons.navigate_next),
                                label: const Text('다음 라운드 준비'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  notifier.advanceRound();
                                  notifier.toggleTournamentStatus(); // 대회 종료 상태로 전환
                                  ref.read(tournamentHistoryProvider.notifier).loadHistory();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('대회가 종료(결과 확정) 되었습니다.')),
                                  );
                                  Navigator.pop(context); // 이전 화면으로 돌아감
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primary,
                                  foregroundColor: Colors.white,
                                ),
                                icon: const Icon(Icons.emoji_events),
                                label: const Text('대회 종료'),
                              ),
                            ),
                          ],
                        )
                      : SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                                '모든 결과를 입력하세요 (${state.currentPairs.where((p) => p.isResultEntered).length}/${state.currentPairs.length})'),
                          ),
                        ),
                ),
              ),
          ],
        ],
      ),
            ),
          ),
        ),
    );
  }

  void _showUndoConfirmDialog(BuildContext context, MacmahonNotifier notifier) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('라운드 취소', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('현재 대진표 또는 이전 라운드 결과를 취소하고 이전 단계로 돌아가시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('아니오'),
          ),
          TextButton(
            onPressed: () {
              notifier.undoLastRound();
              Navigator.pop(context);
            },
            child: const Text('예, 돌아갑니다', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ── 위젯: 대진 카드 ──────────────────────────────────────────
class _PairCard extends StatelessWidget {
  final MacmahonPair pair;
  final int boardNumber;
  final Function(String? winnerId) onResultSelected;

  const _PairCard({
    required this.pair,
    required this.boardNumber,
    required this.onResultSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                // 판 번호
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text('$boardNumber',
                        style: const TextStyle(
                            color: Colors.white, 
                            fontWeight: FontWeight.bold,
                            fontSize: 14)),
                  ),
                ),
                const SizedBox(width: 12),

                // 흑번 선수
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _StoneCircle(isBlack: true),
                          const SizedBox(width: 8),
                          Text(pair.black.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _FloatBadge(floatResult: pair.blackFloatResult),
                    ],
                  ),
                ),

                const Text('vs',
                    style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.bold)),

                // 백번 선수
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(pair.white.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                          const SizedBox(width: 8),
                          _StoneCircle(isBlack: false),
                        ],
                      ),
                      const SizedBox(height: 4),
                      _FloatBadge(floatResult: pair.whiteFloatResult),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 24),
            
            // 승패 선택 버튼
            Row(
              children: [
                _QuickResultButton(
                  label: pair.black.name,
                  suffix: '승',
                  isSelected:
                      pair.isResultEntered && pair.winnerId == pair.black.id,
                  color: AppTheme.black,
                  onTap: () => onResultSelected(pair.black.id),
                ),
                const SizedBox(width: 8),
                _QuickResultButton(
                  label: '무승부',
                  suffix: '',
                  isSelected: pair.isResultEntered && pair.winnerId == null,
                  color: Colors.orange,
                  isSmall: true,
                  onTap: () => onResultSelected(null),
                ),
                const SizedBox(width: 8),
                _QuickResultButton(
                  label: pair.white.name,
                  suffix: '승',
                  isSelected:
                      pair.isResultEntered && pair.winnerId == pair.white.id,
                  color: Colors.blueGrey,
                  onTap: () => onResultSelected(pair.white.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickResultButton extends StatelessWidget {
  final String label;
  final String suffix;
  final bool isSelected;
  final bool isSmall;
  final Color color;
  final VoidCallback onTap;

  const _QuickResultButton({
    required this.label,
    required this.suffix,
    required this.isSelected,
    this.isSmall = false,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isSmall ? 2 : 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color:
                isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: RichText(
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              style: TextStyle(
                fontSize: isSmall ? 11 : 13,
                fontFamily: 'Pretendard',
                color: isSelected ? color : AppTheme.textSecondary,
              ),
              children: [
                TextSpan(
                  text: label,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
                if (suffix.isNotEmpty)
                  TextSpan(
                    text: ' $suffix',
                    style: TextStyle(
                      fontSize: isSmall ? 11 : 12,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? color : AppTheme.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StoneCircle extends StatelessWidget {
  final bool isBlack;
  const _StoneCircle({required this.isBlack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: isBlack ? AppTheme.black : AppTheme.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400),
        boxShadow: const [
          BoxShadow(
              color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))
        ],
      ),
    );
  }
}

class _FloatBadge extends StatelessWidget {
  final int floatResult;
  const _FloatBadge({required this.floatResult});

  @override
  Widget build(BuildContext context) {
    if (floatResult == 0) return const SizedBox.shrink();
    final isUp = floatResult > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12,
          color: isUp ? AppTheme.floatUp : AppTheme.floatDown,
        ),
        Text(
          isUp ? 'Float Up' : 'Float Down',
          style: TextStyle(
            fontSize: 11,
            color: isUp ? AppTheme.floatUp : AppTheme.floatDown,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ByeCard extends StatelessWidget {
  final String playerName;
  const _ByeCard({required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppTheme.byeColor.withValues(alpha: 0.1),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.airline_seat_flat, color: AppTheme.byeColor),
        title: Text(playerName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: const Chip(
          label: Text('부전승', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppTheme.byeColor,
          labelStyle: TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
