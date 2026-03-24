import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../models/macmahon_pair.dart';
import '../providers/macmahon_provider.dart';

class RoundHistoryScreen extends ConsumerWidget {
  const RoundHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);
    final history = state.history;

    return Scaffold(
      appBar: AppBar(
        title: const Text('매칭 기록'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: history.isEmpty
          ? const Center(
              child: Text('완료된 라운드가 없습니다.',
                  style: TextStyle(color: AppTheme.textSecondary)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              itemBuilder: (context, index) {
                // 이력은 0번이 1라운드
                final roundResult = history[index];
                final roundNumber = roundResult.round;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$roundNumber라운드',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${roundResult.pairs.length}경기 진행',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...roundResult.pairs.map((pair) => _HistoryPairCard(pair: pair)),
                    if (roundResult.byePlayer != null)
                      _HistoryByeCard(playerName: roundResult.byePlayer!.name),
                    const SizedBox(height: 16),
                    if (index < history.length - 1)
                      const Divider(),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryPairCard extends StatelessWidget {
  final MacmahonPair pair;
  const _HistoryPairCard({required this.pair});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // 흑번
            Expanded(
              child: _PlayerInHistory(
                name: pair.black.name,
                isWinner: pair.isResultEntered && pair.winnerId == pair.black.id,
                isBlack: true,
              ),
            ),
            
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Text('vs', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            ),
            
            // 백번
            Expanded(
              child: _PlayerInHistory(
                name: pair.white.name,
                isWinner: pair.isResultEntered && pair.winnerId == pair.white.id,
                isBlack: false,
                alignEnd: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerInHistory extends StatelessWidget {
  final String name;
  final bool isWinner;
  final bool isBlack;
  final bool alignEnd;

  const _PlayerInHistory({
    required this.name,
    required this.isWinner,
    required this.isBlack,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: [
            if (!alignEnd) _StoneSmall(isBlack: isBlack),
            if (!alignEnd) const SizedBox(width: 6),
            Flexible(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                  color: isWinner ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (alignEnd) const SizedBox(width: 6),
            if (alignEnd) _StoneSmall(isBlack: isBlack),
          ],
        ),
        if (isWinner)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Winner',
              style: TextStyle(
                color: Colors.orange.shade700,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

class _StoneSmall extends StatelessWidget {
  final bool isBlack;
  const _StoneSmall({required this.isBlack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: isBlack ? AppTheme.black : AppTheme.white,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 1)],
      ),
    );
  }
}

class _HistoryByeCard extends StatelessWidget {
  final String playerName;
  const _HistoryByeCard({required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.byeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.airline_seat_flat, color: AppTheme.byeColor, size: 16),
          const SizedBox(width: 8),
          Text(playerName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          const Spacer(),
          const Text('부전승', style: TextStyle(color: AppTheme.byeColor, fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
