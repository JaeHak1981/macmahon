import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_pair.dart';
import '../providers/macmahon_provider.dart';

class PairingScreen extends ConsumerWidget {
  const PairingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);
    final notifier = ref.read(macmahonProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('라운드 ${state.currentRound} 대진표'),
        actions: const [
          // '결과 입력' 버튼 제거 (내부 통합됨)
        ],
      ),
      body: Column(
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
                    '${state.players.length}명의 선수가 등록되어 있습니다.',
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '안티그래비티 규칙을 적용하여\n최적의 대진표를 생성합니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state.isLoading
                          ? null
                          : () => notifier.generatePairing(),
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
                    '${state.byePlayer != null ? " · 부전승: ${state.byePlayer!.name}" : ""}',
                    style: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '총 비용: ${state.currentPairing!.totalCost.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),

            // ── 대진표 목록 ───────────────────────────
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: state.currentPairs.length +
                    (state.byePlayer != null ? 1 : 0),
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
                  return _ByeCard(playerName: state.byePlayer!.name);
                },
              ),
            ),

            // ── 라운드 종료 버튼 ───────────────────────
            if (state.currentPairing != null)
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: state.currentPairs.every((p) => p.isResultEntered)
                          ? () {
                              notifier.advanceRound();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('라운드가 종료되었습니다.')),
                              );
                            }
                          : null,
                      icon: const Icon(Icons.check_circle),
                      label: Text(state.currentPairs.every((p) => p.isResultEntered)
                          ? '라운드 종료 및 다음 대진'
                          : '모든 결과를 입력하세요 (${state.currentPairs.where((p) => p.isResultEntered).length}/${state.currentPairs.length})'),
                    ),
                  ),
                ),
              ),
          ],
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
                  label: '흑 승',
                  isSelected: pair.isResultEntered && pair.winnerId == pair.black.id,
                  color: AppTheme.black,
                  onTap: () => onResultSelected(pair.black.id),
                ),
                const SizedBox(width: 8),
                _QuickResultButton(
                  label: '무승부',
                  isSelected: pair.isResultEntered && pair.winnerId == null,
                  color: Colors.orange,
                  onTap: () => onResultSelected(null),
                ),
                const SizedBox(width: 8),
                _QuickResultButton(
                  label: '백 승',
                  isSelected: pair.isResultEntered && pair.winnerId == pair.white.id,
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
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _QuickResultButton({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : AppTheme.textSecondary,
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
