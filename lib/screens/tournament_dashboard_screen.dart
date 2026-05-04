import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../providers/macmahon_provider.dart';
import 'player_registration_screen.dart';
import 'pairing_screen.dart';
import 'standings_screen.dart';
import 'round_history_screen.dart';
import 'bracket_screen.dart';
import '../providers/history_provider.dart';
import 'group_assignment_screen.dart';
import 'knockout_selection_screen.dart';

class TournamentDashboardScreen extends ConsumerWidget {
  const TournamentDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);
    final isLeague = (state.format == TournamentFormat.league ||
            state.format == TournamentFormat.leagueAndKnockout) &&
        state.stage == 1;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
          tooltip: '부 관리 화면으로 이동',
        ),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${state.tournamentName} - ${state.selectedSection}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  '${state.tournamentDate} ${state.tournamentLocation.isNotEmpty ? ' | ${state.tournamentLocation}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            if (state.isFinished) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade600,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '종료됨',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppTheme.textSecondary),
            onPressed: () => _showTopMenu(context, ref, state),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              children: [
                _FormatSelector(state: state),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _TournamentStatusHeader(state: state),
                        const SizedBox(height: 28),
                        _CallToActionCard(state: state),
                        const SizedBox(height: 36),
                        const Text(
                          '대회 도구',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 16),
                        GridView(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 220,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 1.2,
                          ),
                          children: [
                            _GridMenuButton(
                              icon: Icons.people_outline,
                              label: '선수 명단',
                              subtitle:
                                  '${state.currentSectionPlayers.length}명 등록됨',
                              color: AppTheme.primary,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PlayerRegistrationScreen(),
                                ),
                              ),
                            ),
                            if (!isLeague)
                              _GridMenuButton(
                                icon: Icons.swap_horiz,
                                label: '페어링',
                                subtitle: '${state.currentRound}R 대진',
                                color: AppTheme.primary,
                                onTap: state.currentSectionPlayers.length >= 2
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const PairingScreen(),
                                        ),
                                      )
                                    : null,
                              ),
                            _GridMenuButton(
                              icon: Icons.leaderboard_outlined,
                              label: '순위표',
                              subtitle: '현재 순위',
                              color: AppTheme.primary,
                              onTap: state.currentSectionPlayers.isNotEmpty
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const StandingsScreen(
                                          initialIndex: 0,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            if (state.format != TournamentFormat.knockout)
                              _GridMenuButton(
                                icon: Icons.grid_on,
                                label: (state.format == TournamentFormat.league ||
                                        state.format ==
                                            TournamentFormat.leagueAndKnockout)
                                    ? '리그표'
                                    : '결과표',
                                subtitle: (state.format == TournamentFormat.league ||
                                        state.format ==
                                            TournamentFormat.leagueAndKnockout)
                                    ? '대진 매트릭스'
                                    : '공식 기록지',
                                color: AppTheme.primary,
                                onTap: state.currentSectionPlayers.isNotEmpty
                                    ? () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const StandingsScreen(
                                            initialIndex: 1,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            _GridMenuButton(
                              icon: Icons.history_edu,
                              label: '라운드 기록',
                              subtitle: '지난 매치 결과',
                              color: AppTheme.primaryLight,
                              onTap: state.history.isNotEmpty
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const RoundHistoryScreen(),
                                      ),
                                    )
                                  : null,
                            ),
                            _GridMenuButton(
                              icon: Icons.account_tree_outlined,
                              label: '토너먼트 대진표',
                              subtitle: '본선 브라켓',
                              color: Colors.deepPurple,
                              onTap: (state.format == TournamentFormat.knockout || 
                                     (state.format == TournamentFormat.leagueAndKnockout && state.stage == 2))
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => const BracketScreen(),
                                      ),
                                    )
                                  : null,
                            ),
                            _GridMenuButton(
                              icon: state.isFinished
                                  ? Icons.play_arrow
                                  : Icons.check_circle_outline,
                              label: state.isFinished ? '대회 재개' : '대회 종료',
                              subtitle: state.isFinished
                                  ? '다시 시작하기'
                                  : '결과 확정하기',
                              color: state.isFinished
                                  ? Colors.green
                                  : Colors.blueAccent,
                              onTap: (state.isFinished ||
                                      state.currentSectionPlayers.isNotEmpty)
                                  ? () async {
                                      await ref
                                          .read(macmahonProvider.notifier)
                                          .toggleTournamentStatus();
                                      ref
                                          .read(
                                            tournamentHistoryProvider.notifier,
                                          )
                                          .loadHistory();

                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              state.isFinished
                                                  ? '대회가 종료되었습니다.'
                                                  : '대회가 다시 시작되었습니다.',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 36),
                        if (isLeague) ...[
                          _LeagueSummaryCard(state: state),
                        ] else if (state.currentPairing != null) ...[
                          const Text(
                            '이번 라운드 대진',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...state.currentPairs.map(
                            (pair) => _PairPreviewTile(
                              black: pair.black.name,
                              white: pair.white.name,
                              mmsDiff: pair.mmsDiff,
                            ),
                          ),
                          if (state.byePlayer != null)
                            _ByeTile(playerName: state.byePlayer!.name),
                        ],
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTopMenu(BuildContext context, WidgetRef ref, MacmahonState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                '대회 관리',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(
                Icons.settings_applications,
                color: AppTheme.primary,
              ),
              title: const Text('부별 대회 방식 설정'),
              subtitle: Text(
                '현재 부: ${state.selectedSection} (${_formatName(state.format)})',
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showSectionSettingsDialog(context, ref, state);
              },
            ),
            if (state.isFinished || state.players.isNotEmpty)
              ListTile(
                leading: Icon(
                  state.isFinished
                      ? Icons.play_arrow
                      : Icons.check_circle_outline,
                  color: state.isFinished ? Colors.green : Colors.blue,
                ),
                title: Text(
                  state.isFinished ? '대회 다시 시작 (재개)' : '대회 종료 (결과 확정)',
                ),
                subtitle: Text(
                  state.isFinished
                      ? '종료 상태를 해제하고 다시 진행합니다.'
                      : '대회를 종료 상태로 표시합니다.',
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref
                      .read(macmahonProvider.notifier)
                      .toggleTournamentStatus();
                  ref
                      .read(tournamentHistoryProvider.notifier)
                      .loadHistory();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          state.isFinished ? '대회가 다시 시작되었습니다.' : '대회가 종료되었습니다.',
                        ),
                      ),
                    );
                  }
                },
              ),
            if (state.currentPairing != null)
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.red),
                title: const Text('현재 라운드 대진 취소'),
                subtitle: const Text('진행 중인 대진을 삭제하고 다시 생성할 수 있습니다.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmCancelPairing(context, ref);
                },
              ),
            if (state.history.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.orange),
                title: const Text('마지막 라운드 취소'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmUndo(context, ref);
                },
              ),
            if (state.players.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.refresh, color: Colors.red),
                title: const Text('현재 부(Section) 초기화'),
                subtitle: const Text('이 부의 모든 경기 기록을 삭제하고 1라운드부터 다시 시작합니다.'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmResetSection(context, ref);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showSectionSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    MacmahonState state,
  ) {
    final currentData = state.currentSectionData;
    TournamentFormat selectedFormat = currentData.format;
    int qualifierCount = currentData.qualifierCount;
    int groupCount = currentData.groupCount;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text('[${state.selectedSection}] 대회 방식 설정'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '진행 방식 선택',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<TournamentFormat>(
                value: selectedFormat,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: TournamentFormat.values
                    .map(
                      (f) => DropdownMenuItem(
                        value: f,
                        child: Text(_formatName(f)),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      selectedFormat = val;
                      // 리그 방식일 경우 기본 조 수를 2개로 제안 (사용자가 인지하도록)
                      if (groupCount <= 1 && (val == TournamentFormat.league || val == TournamentFormat.leagueAndKnockout)) {
                        groupCount = 2;
                      }
                    });
                  }
                },
              ),
              if (selectedFormat == TournamentFormat.league ||
                  selectedFormat == TournamentFormat.leagueAndKnockout) ...[
                const SizedBox(height: 20),
                const Text(
                  '리그 조(Group) 수',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: [1, 2, 4, 8].contains(groupCount) ? groupCount : null,
                        hint: Text('$groupCount개 조'),
                        decoration:
                            const InputDecoration(border: OutlineInputBorder()),
                        items: [1, 2, 4, 8]
                            .map((n) => DropdownMenuItem(value: n, child: Text('$n개 조')))
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => groupCount = val);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      height: 56, // Dropdown과 높이 맞춤
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final val = await _showCustomGroupInputDialog(context, groupCount);
                          if (val != null) setState(() => groupCount = val);
                        },
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('직접 입력'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '※ 전체 인원을 설정된 조 수만큼 나누어 리그전을 진행합니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      ref.read(macmahonProvider.notifier).updateSectionSettings(
                            format: selectedFormat,
                            qualifierCount: qualifierCount,
                            groupCount: groupCount,
                          );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const GroupAssignmentScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('조 편성 관리 (자동/수동)'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
              if (selectedFormat == TournamentFormat.leagueAndKnockout) ...[
                const SizedBox(height: 20),
                const Text(
                  '본선 진출 인원 (예선 통과자)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: qualifierCount,
                  decoration: const InputDecoration(border: OutlineInputBorder()),
                  items: [2, 4, 8, 16, 32]
                      .map((n) => DropdownMenuItem(value: n, child: Text('$n명')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => qualifierCount = val);
                  },
                ),
                const SizedBox(height: 12),
                const Text(
                  '※ 예선 종료 후 본선(토너먼트)으로 전환할 때 진출하는 총 인원입니다.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('취소'),
            ),
            ElevatedButton(
              onPressed: () {
                ref
                    .read(macmahonProvider.notifier)
                    .updateSectionSettings(
                      format: selectedFormat,
                      qualifierCount: qualifierCount,
                      groupCount: groupCount,
                    );
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('설정이 저장되었습니다.')));
              },
              child: const Text('저장'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmUndo(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('라운드 취소'),
        content: const Text(
          '마지막 라운드 결과를 취소하고 이전 상태로 되돌리겠습니까?\n이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              ref.read(macmahonProvider.notifier).undoLastRound();
              Navigator.pop(ctx);
            },
            child: const Text('라운드 취소 실행'),
          ),
        ],
      ),
    );
  }

  void _confirmCancelPairing(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('현재 대진 취소'),
        content: const Text(
          '현재 라운드에서 생성된 대진표를 삭제합니다. 경기 방식이나 조 수를 변경한 후 다시 대진을 생성할 수 있습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(macmahonProvider.notifier).cancelCurrentPairing();
              Navigator.pop(ctx);
            },
            child: const Text('대진 취소'),
          ),
        ],
      ),
    );
  }

  void _confirmResetSection(BuildContext context, WidgetRef ref) {
    final section = ref.read(macmahonProvider).selectedSection;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('[$section] 부 초기화'),
        content: Text(
          '[$section] 부의 모든 경기 기록이 삭제됩니다. (선수 명단은 유지됩니다.) 정말 초기화하시겠습니까?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(macmahonProvider.notifier).resetCurrentSection();
              Navigator.pop(ctx);
            },
            child: const Text('부 초기화'),
          ),
        ],
      ),
    );
  }

  String _formatName(TournamentFormat format) {
    switch (format) {
      case TournamentFormat.undecided:
        return '미정';
      case TournamentFormat.macmahon:
        return '맥마흔 (스위스)';
      case TournamentFormat.league:
        return '풀리그';
      case TournamentFormat.knockout:
        return '토너먼트';
      case TournamentFormat.doubleElimination:
        return '더블 일리미네이션';
      case TournamentFormat.leagueAndKnockout:
        return '풀리그+토너먼트';
    }
  }
}

// ── 보조 위젯들 (HomeScreen에서 복사) ───────────────────────────

class _TournamentStatusHeader extends StatelessWidget {
  final MacmahonState state;
  const _TournamentStatusHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _StatBox(
                icon: Icons.groups,
                label: '참가 선수',
                value: '${state.currentSectionPlayers.length}명',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                icon: Icons.assistant_photo,
                label: '추천 ${state.recommendedRounds}R',
                value: '${state.currentRound}R',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatBox(
                icon: Icons.checklist,
                label: '완료 매치',
                value: '${state.history.length}건',
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.primaryLight, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _GridMenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _GridMenuButton({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = onTap != null;

    return Card(
      color: isEnabled ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide.none,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEnabled
                      ? color.withValues(alpha: 0.15)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: isEnabled ? color : Colors.grey.shade400,
                  size: 28,
                ),
              ),
              const Spacer(),
              Text(
                label,
                style: TextStyle(
                  color: isEnabled
                      ? AppTheme.textPrimary
                      : Colors.grey.shade500,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: isEnabled
                      ? AppTheme.textSecondary
                      : Colors.grey.shade400,
                  fontSize: 12,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CallToActionCard extends ConsumerWidget {
  final MacmahonState state;
  const _CallToActionCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playersCount = state.currentSectionPlayers.length;
    final stage = state.stage;
    final historyCount = state.history.length;
    final recommended = state.recommendedRounds;

    if (playersCount == 0) {
      return _buildCta(
        context,
        icon: Icons.group_add,
        title: '${state.selectedSection}에 등록된 선수가 없습니다.',
        buttonText: '선수 등록하기',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PlayerRegistrationScreen()),
        ),
      );
    }

    if (stage == 1 &&
        historyCount >= recommended &&
        state.format == TournamentFormat.leagueAndKnockout) {
      return _buildCta(
        context,
        icon: Icons.emoji_events,
        title:
            '${state.selectedSection}: 예선(${recommended}R)이 완료되었습니다. 본선 진출자(${state.currentSectionData.qualifierCount}명)를 선발하여 토너먼트를 시작할 수 있습니다.',
        buttonText: '본선 토너먼트 전환하기',
        color: Colors.orange.shade700,
        onTap: () => _confirmStartKnockout(context, ref),
      );
    }

    final format = state.currentSectionData.format;
    final isLeague = (format == TournamentFormat.league || format == TournamentFormat.leagueAndKnockout) && state.stage == 1;
    final isKnockout = format == TournamentFormat.knockout || (format == TournamentFormat.leagueAndKnockout && state.stage == 2);

    if (state.currentPairing == null) {
      return _buildCta(
        context,
        icon: Icons.play_circle_fill,
        title:
            '${state.selectedSection}: 선수 $playersCount명 등록 완료. (권장: ${recommended}라운드)',
        buttonText: isKnockout ? '토너먼트 대진표 진행' : (isLeague ? '리그전 시작 / 결과 입력' : '${state.currentRound}라운드 페어링 생성'),
        onTap: () async {
          if (isLeague) {
            if (state.currentPairing == null) {
              await ref.read(macmahonProvider.notifier).generatePairing();
            }
            if (context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const StandingsScreen(initialIndex: 1),
                ),
              );
            }
          } else if (isKnockout) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const StandingsScreen(initialIndex: 1)),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PairingScreen()),
            );
          }
        },
      );
    }

    return _buildCta(
      context,
      icon: Icons.sports_score,
      title:
          '${state.selectedSection}: 현재 ${state.currentRound}라운드가 진행 중입니다. (권장: ${recommended}라운드)',
      buttonText: isKnockout ? '토너먼트 대진표 확인' : (isLeague ? '리그표 확인 / 결과 입력' : '결과 입력 / 페어링 보기'),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => (isLeague || isKnockout)
              ? const StandingsScreen(initialIndex: 1)
              : const PairingScreen(),
        ),
      ),
    );
  }

  void _confirmStartKnockout(BuildContext context, WidgetRef ref) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KnockoutSelectionScreen()),
    );
  }

  Widget _buildCta(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String buttonText,
    required VoidCallback onTap,
    Color? color,
  }) {
    final themeColor = color ?? AppTheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: themeColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: themeColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: onTap,
              child: Text(
                buttonText,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PairPreviewTile extends StatelessWidget {
  final String black;
  final String white;
  final double mmsDiff;
  const _PairPreviewTile({
    required this.black,
    required this.white,
    required this.mmsDiff,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _StoneChip(label: '흑', isBlack: true),
            const SizedBox(width: 8),
            Text(
              black,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const Spacer(),
            Text(
              'vs',
              style: TextStyle(
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              white,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(width: 8),
            _StoneChip(label: '백', isBlack: false),
            if (mmsDiff > 0) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.floatDown.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.floatDown.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  '±${mmsDiff.toStringAsFixed(0)}',
                  style: const TextStyle(
                    color: AppTheme.floatDown,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StoneChip extends StatelessWidget {
  final String label;
  final bool isBlack;
  const _StoneChip({required this.label, required this.isBlack});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: isBlack ? AppTheme.black : AppTheme.white,
        shape: BoxShape.circle,
        border: Border.all(
          color: isBlack ? Colors.transparent : Colors.grey.shade300,
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          label,
          style: TextStyle(
            color: isBlack ? Colors.white : Colors.black87,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ByeTile extends StatelessWidget {
  final String playerName;
  const _ByeTile({required this.playerName});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      elevation: 0,
      color: AppTheme.byeColor.withValues(alpha: 0.05),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: AppTheme.byeColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              Icons.airline_seat_flat,
              color: AppTheme.byeColor.withValues(alpha: 0.7),
              size: 20,
            ),
            const SizedBox(width: 12),
            Text(
              playerName,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.byeColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                '부전승 (Bye)',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormatSelector extends ConsumerWidget {
  final MacmahonState state;
  const _FormatSelector({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFormat = state.format;
    final notifier = ref.read(macmahonProvider.notifier);
    final isLeague = currentFormat == TournamentFormat.league || currentFormat == TournamentFormat.leagueAndKnockout;
    final currentGroupCount = state.currentSectionData.groupCount;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '대회 방식',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: TournamentFormat.values
                      .where((f) => f != TournamentFormat.undecided)
                      .map((format) {
                    final isSelected = currentFormat == format;
                    return OutlinedButton(
                      onPressed: () {
                        notifier.updateSectionSettings(format: format);
                      },
                      style: OutlinedButton.styleFrom(
                        backgroundColor: isSelected ? AppTheme.primary : Colors.transparent,
                        foregroundColor: isSelected ? Colors.white : AppTheme.textPrimary,
                        side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text(
                        _formatName(format),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          if (isLeague) ...[
            const SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '리그 조 설정',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...({1, 2, 4, 8, currentGroupCount}.toList()..sort()).map((n) {
                        final isSelected = currentGroupCount == n;
                        return OutlinedButton(
                          onPressed: () {
                            notifier.updateSectionSettings(groupCount: n);
                          },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isSelected ? AppTheme.primary : Colors.transparent,
                            foregroundColor: isSelected ? Colors.white : AppTheme.textPrimary,
                            side: BorderSide(color: isSelected ? AppTheme.primary : Colors.grey.shade300),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: Text(
                            '${n}개',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        );
                      }),
                      OutlinedButton(
                        onPressed: () async {
                          final val = await _showCustomGroupInputDialog(context, currentGroupCount);
                          if (val != null) notifier.updateSectionSettings(groupCount: val);
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('+입력', style: TextStyle(fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GroupAssignmentScreen()),
                      ),
                      icon: const Icon(Icons.groups_outlined, size: 14),
                      label: const Text('조 편성하기', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatName(TournamentFormat format) {
    switch (format) {
      case TournamentFormat.undecided: return '미정';
      case TournamentFormat.macmahon: return '맥마흔';
      case TournamentFormat.league: return '풀리그';
      case TournamentFormat.knockout: return '토너먼트';
      case TournamentFormat.doubleElimination: return '더블 일리미네이션';
      case TournamentFormat.leagueAndKnockout: return '풀리그+토너먼트';
    }
  }
}
class _LeagueSummaryCard extends StatelessWidget {
  final MacmahonState state;
  const _LeagueSummaryCard({required this.state});

  @override
  Widget build(BuildContext context) {
    final total = state.currentPairs.length;
    final completed = state.currentPairs.where((p) => p.isResultEntered).length;
    final percent = total > 0 ? (completed / total * 100).toInt() : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '리그전 진행 현황',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '전체 경기 진행도',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  Text(
                    '$percent%',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: total > 0 ? completed / total : 0,
                  minHeight: 10,
                  backgroundColor: Colors.white,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _InfoItem(label: '총 경기', value: '$total'),
                  _InfoItem(label: '완료', value: '$completed', color: Colors.blue),
                  _InfoItem(label: '미진행', value: '${total - completed}', color: Colors.orange),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StandingsScreen(initialIndex: 0),
                    ),
                  ),
                  icon: const Icon(Icons.grid_on),
                  label: const Text('실시간 리그 순위표 / 결과 입력'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;
  const _InfoItem({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            color: color ?? AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
        ),
      ],
    );
  }
}
class _GroupConfigCard extends ConsumerWidget {
  final MacmahonState state;
  const _GroupConfigCard({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentGroupCount = state.currentSectionData.groupCount;
    final notifier = ref.read(macmahonProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '리그 조(Group) 설정',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 12),
                  const Text(
                    '현재 조 구성:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$currentGroupCount개 조',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ...({1, 2, 4, 8, currentGroupCount}.toList()..sort()).map((n) {
                    final isSelected = currentGroupCount == n;
                    return ChoiceChip(
                      label: Text('$n개 조'),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          notifier.updateSectionSettings(groupCount: n);
                        }
                      },
                      selectedColor: AppTheme.primary,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }),
                  ActionChip(
                    label: const Text('+ 직접 입력'),
                    avatar: const Icon(Icons.edit, size: 16),
                    onPressed: () async {
                      final val = await _showCustomGroupInputDialog(context, currentGroupCount);
                      if (val != null) {
                        notifier.updateSectionSettings(groupCount: val);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const GroupAssignmentScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('조 편성 및 선수 관리'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<int?> _showCustomGroupInputDialog(BuildContext context, int initial) {
  final controller = TextEditingController(text: initial.toString());
  return showDialog<int>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('조 개수 직접 입력'),
      content: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: '원하는 조의 수를 입력하세요',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        onSubmitted: (val) {
          final parsed = int.tryParse(val);
          if (parsed != null && parsed > 0) Navigator.pop(ctx, parsed);
        },
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
        ElevatedButton(
          onPressed: () {
            final val = int.tryParse(controller.text);
            if (val != null && val > 0) {
              Navigator.pop(ctx, val);
            }
          },
          child: const Text('확인'),
        ),
      ],
    ),
  );
}
