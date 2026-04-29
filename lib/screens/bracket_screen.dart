import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../providers/macmahon_provider.dart';
import '../models/macmahon_pair.dart';

class BracketScreen extends ConsumerWidget {
  const BracketScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);
    final history = state.history;
    final currentPairing = state.currentPairing;

    // 모든 라운드 데이터를 합침 (히스토리 + 현재 진행 중인 라운드)
    final List<PairingResult> allRounds = [...history];
    if (currentPairing != null) {
      allRounds.add(currentPairing);
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${state.selectedSection} 토너먼트 대진표'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: allRounds.isEmpty
          ? const Center(child: Text('진행 중인 토너먼트가 없습니다.'))
          : Scrollbar(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: allRounds.map((roundResult) {
                    return _RoundColumn(
                      roundResult: roundResult,
                      isLast: roundResult == allRounds.last,
                    );
                  }).toList(),
                ),
              ),
            ),
    );
  }
}

class _RoundColumn extends StatelessWidget {
  final PairingResult roundResult;
  final bool isLast;

  const _RoundColumn({required this.roundResult, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      margin: const EdgeInsets.only(right: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${roundResult.round}라운드',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 24),
          ...roundResult.pairs.map((pair) => _BracketMatchTile(pair: pair)),
          if (roundResult.byePlayer != null)
            _BracketByeTile(playerName: roundResult.byePlayer!.name),
        ],
      ),
    );
  }
}

class _BracketMatchTile extends StatelessWidget {
  final MacmahonPair pair;
  const _BracketMatchTile({required this.pair});

  @override
  Widget build(BuildContext context) {
    final hasResult = pair.isResultEntered;
    final blackWon = pair.winnerId == pair.black.id;
    final whiteWon = pair.winnerId == pair.white.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          _PlayerRow(
            name: pair.black.name,
            isWinner: blackWon,
            isLoser: hasResult && !blackWon,
            isBlack: true,
          ),
          Divider(height: 1, color: Colors.grey.shade100),
          _PlayerRow(
            name: pair.white.name,
            isWinner: whiteWon,
            isLoser: hasResult && !whiteWon,
            isBlack: false,
          ),
        ],
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final String name;
  final bool isWinner;
  final bool isLoser;
  final bool isBlack;

  const _PlayerRow({
    required this.name,
    required this.isWinner,
    required this.isLoser,
    required this.isBlack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isBlack ? Colors.black : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                color: isLoser ? Colors.grey : AppTheme.textPrimary,
                decoration: isLoser ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (isWinner)
            const Icon(Icons.check_circle, color: Colors.green, size: 16),
        ],
      ),
    );
  }
}

class _BracketByeTile extends StatelessWidget {
  final String playerName;
  const _BracketByeTile({required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.byeColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.byeColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star, color: AppTheme.byeColor, size: 16),
          const SizedBox(width: 8),
          Text(playerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const Spacer(),
          const Text('부전승', style: TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      ),
    );
  }
}
