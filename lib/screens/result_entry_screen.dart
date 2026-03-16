import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_pair.dart';
import '../providers/macmahon_provider.dart';

class ResultEntryScreen extends ConsumerStatefulWidget {
  const ResultEntryScreen({super.key});

  @override
  ConsumerState<ResultEntryScreen> createState() => _ResultEntryScreenState();
}

class _ResultEntryScreenState extends ConsumerState<ResultEntryScreen> {
  // pairIndex → 'black' | 'white' | 'draw' | null
  final Map<int, String?> _results = {};

  bool get _allResultsEntered {
    final state = ref.read(macmahonProvider);
    final total = state.currentPairs.length;
    return _results.length == total &&
        _results.values.every((v) => v != null);
  }

  void _submitResults() {
    final state = ref.read(macmahonProvider);
    final notifier = ref.read(macmahonProvider.notifier);

    for (int i = 0; i < state.currentPairs.length; i++) {
      final pair = state.currentPairs[i];
      final result = _results[i];
      String? winnerId;
      if (result == 'black') {
        winnerId = pair.black.id;
      } else if (result == 'white') {
        winnerId = pair.white.id;
      }
      // 'draw'이면 winnerId = null (무승부)

      notifier.recordResult(
        blackId: pair.black.id,
        whiteId: pair.white.id,
        winnerId: winnerId,
      );
    }

    notifier.advanceRound();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('결과가 저장되었습니다. 다음 라운드로 이동합니다.'),
        backgroundColor: AppTheme.primary,
      ),
    );

    // 홈으로 돌아가기
    Navigator.popUntil(context, (route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text('라운드 ${state.currentRound} 결과 입력'),
      ),
      body: Column(
        children: [
          // ── 안내 배너 ──────────────────────────────────
          Container(
            color: AppTheme.accent.withValues(alpha: 0.2),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            width: double.infinity,
            child: const Text(
              '각 대국의 결과를 선택하세요.',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
          ),

          // ── 결과 입력 목록 ─────────────────────────────
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.currentPairs.length +
                  (state.byePlayer != null ? 1 : 0),
              itemBuilder: (context, index) {
                // 부전승 타일
                if (index == state.currentPairs.length) {
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.airline_seat_flat,
                          color: AppTheme.byeColor),
                      title: Text(state.byePlayer!.name,
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      trailing: const Chip(
                        label: Text('부전승 +1',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        backgroundColor: AppTheme.byeColor,
                      ),
                    ),
                  );
                }

                final pair = state.currentPairs[index];
                return _ResultTile(
                  boardNumber: index + 1,
                  pair: pair,
                  selected: _results[index],
                  onSelect: (v) => setState(() => _results[index] = v),
                );
              },
            ),
          ),

          // ── 제출 버튼 ──────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _allResultsEntered ? _submitResults : null,
                  icon: const Icon(Icons.check),
                  label: Text(_allResultsEntered
                      ? '결과 확정 및 다음 라운드'
                      : '모든 결과를 입력하세요 (${_results.values.where((v) => v != null).length}/${state.currentPairs.length})'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 위젯: 결과 입력 타일 ──────────────────────────────────────
class _ResultTile extends StatelessWidget {
  final int boardNumber;
  final MacmahonPair pair;
  final String? selected;
  final ValueChanged<String?> onSelect;

  const _ResultTile({
    required this.boardNumber,
    required this.pair,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 판 번호 및 선수명
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Center(
                    child: Text('$boardNumber',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                _StoneTag(label: '흑', isBlack: true),
                const SizedBox(width: 6),
                Text(pair.black.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Text('vs',
                    style: TextStyle(color: AppTheme.textSecondary)),
                const SizedBox(width: 8),
                Text(pair.white.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 6),
                _StoneTag(label: '백', isBlack: false),
              ],
            ),
            const SizedBox(height: 10),

            // 결과 선택 버튼
            Row(
              children: [
                _ResultButton(
                  label: pair.black.name,
                  suffix: '승',
                  icon: Icons.person,
                  color: AppTheme.black,
                  isSelected: selected == 'black',
                  onTap: () => onSelect('black'),
                ),
                const SizedBox(width: 8),
                _ResultButton(
                  label: '무승부',
                  suffix: '',
                  icon: Icons.remove_circle_outline,
                  color: Colors.orange,
                  isSelected: selected == 'draw',
                  isSmall: true,
                  onTap: () => onSelect('draw'),
                ),
                const SizedBox(width: 8),
                _ResultButton(
                  label: pair.white.name,
                  suffix: '승',
                  icon: Icons.person_outline,
                  color: Colors.blueGrey,
                  isSelected: selected == 'white',
                  onTap: () => onSelect('white'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultButton extends StatelessWidget {
  final String label;
  final String suffix;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isSmall;
  final VoidCallback onTap;

  const _ResultButton({
    required this.label,
    required this.suffix,
    required this.icon,
    required this.color,
    required this.isSelected,
    this.isSmall = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: isSmall ? 2 : 3,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected 
                ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))]
                : null,
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey.shade400, size: 22),
              const SizedBox(height: 6),
              RichText(
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  style: TextStyle(
                    fontSize: isSmall ? 11 : 13,
                    fontFamily: 'Pretendard', // 기본 폰트 사용 시 생략 가능
                    color: isSelected ? color : Colors.grey.shade700,
                  ),
                  children: [
                    TextSpan(
                      text: label,
                      style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                      ),
                    ),
                    if (suffix.isNotEmpty)
                      TextSpan(
                        text: ' $suffix',
                        style: TextStyle(
                          fontSize: isSmall ? 11 : 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? color
                              : Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoneTag extends StatelessWidget {
  final String label;
  final bool isBlack;
  const _StoneTag({required this.label, required this.isBlack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isBlack ? AppTheme.black : AppTheme.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Center(
        child: Text(label,
            style: TextStyle(
              fontSize: 9,
              color: isBlack ? Colors.white : Colors.black54,
              fontWeight: FontWeight.bold,
            )),
      ),
    );
  }
}
