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

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);

    if (state.tournamentName.isEmpty) {
      return const _SetupView();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        _confirmReset(context, ref);
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary),
          onPressed: () => _confirmReset(context, ref),
          tooltip: '초기 화면으로 이동',
        ),
        title: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  state.tournamentName,
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
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                // ── 부(Section) 선택 UI ─────────────────
                _SectionSelector(state: state),
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
                        // ── 헤더: 선택된 부 요약 통계 ────────────────
                        _TournamentStatusHeader(state: state),
                        const SizedBox(height: 28),

                        // ── 다이내믹 가이드라인 (CTA) ─────────────────
                        _CallToActionCard(state: state),
                        const SizedBox(height: 36),

                        // ── 섹션 타이틀 & 그리드 메뉴 ──────────────────────
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
                                        builder: (_) => StandingsScreen(
                                          initialIndex: (state.format ==
                                                      TournamentFormat.league ||
                                                  state.format ==
                                                      TournamentFormat
                                                          .leagueAndKnockout)
                                              ? 2
                                              : 1,
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
                              onTap: state.format == TournamentFormat.knockout
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
                              onTap:
                                  (state.isFinished ||
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

                        // ── 이번 라운드 대진 미리보기 ─────────────────
                        if (state.currentPairing != null) ...[
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

                        const SizedBox(height: 36),
                        const _HistorySection(),
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
    ),
  );
  }
}

  void _showNewTournamentDialog(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final defaultDate =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final nameController = TextEditingController(text: '새 대회');
    final dateController = TextEditingController(text: defaultDate);
    final locationController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 대회 시작'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '현재 진행 중인 정보가 저장되고 새로운 대회를 시작합니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '대회명',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                readOnly: true,
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.tryParse(dateController.text) ??
                        DateTime.now(),
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                    locale: const Locale('ko', 'KR'),
                  );
                  if (picked != null) {
                    dateController.text =
                        "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                  }
                },
                decoration: const InputDecoration(
                  labelText: '날짜',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: '장소(선택)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final date = dateController.text.trim();
              final location = locationController.text.trim();

              final notifier = ref.read(macmahonProvider.notifier);
              final historyNotifier =
                  ref.read(tournamentHistoryProvider.notifier);

              // 1. 기존 대회 저장 후 초기화
              await notifier.startNewTournament();

              // 2. 입력받은 정보로 업데이트
              notifier.updateTournamentInfo(
                name: name,
                date: date,
                location: location,
              );

              // 3. 즉시 저장소에 반영 및 목록 갱신
              await notifier.saveCurrentTournament();
              historyNotifier.loadHistory();

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('새 대회가 시작되었습니다.')));
              }
            },
            child: const Text('대회 시작'),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 종료'),
        content: const Text(
          '현재 진행 중인 대회를 종료하고 초기 설정 화면으로 돌아가시겠습니까?\n\n(작성 중인 정보는 자동으로 저장됩니다.)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(macmahonProvider.notifier).startNewTournament();
              if (context.mounted) {
                Navigator.pop(ctx);
              }
            },
            child: const Text('확인'),
          ),
        ],
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
            ListTile(
              leading: const Icon(Icons.edit_note, color: AppTheme.primary),
              title: const Text('대회 정보 설정'),
              onTap: () {
                Navigator.pop(ctx);
                _showTournamentInfoDialog(context, ref, state);
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
                      .loadHistory(); // 목록 갱신

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
                title: const Text('대회 초기화 (데이터 삭제)'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmReset(context, ref);
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showTournamentInfoDialog(
    BuildContext context,
    WidgetRef ref,
    MacmahonState state,
  ) {
    final nameController = TextEditingController(text: state.tournamentName);
    final dateController = TextEditingController(text: state.tournamentDate);
    final locationController = TextEditingController(
      text: state.tournamentLocation,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('대회 정보 설정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '대회명',
                  hintText: '예: 제1회 맥마흔 바둑대회',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(
                  labelText: '날짜',
                  hintText: '예: 2024-03-20',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: '장소',
                  hintText: '예: 한국기원',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final date = dateController.text.trim();
              final location = locationController.text.trim();

              final notifier = ref.read(macmahonProvider.notifier);
              notifier.updateTournamentInfo(
                name: name,
                date: date,
                location: location,
              );

              // 즉시 저장소에 반영
              await notifier.saveCurrentTournament();
              // 홈 화면의 기록 목록 갱신
              ref.read(tournamentHistoryProvider.notifier).loadHistory();

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('대회 정보가 수정 및 저장되었습니다.')),
                );
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  String _formatName(TournamentFormat format) {
    switch (format) {
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

  String _leagueTypeName(LeagueType type) {
    switch (type) {
      case LeagueType.normal:
        return '일반 풀리그';
      case LeagueType.doubleElimination:
        return '더블 일리미네이션';
    }
  }

  void _showSectionSettingsDialog(
    BuildContext context,
    WidgetRef ref,
    MacmahonState state,
  ) {
    final currentData = state.currentSectionData;
    TournamentFormat selectedFormat = currentData.format;
    int qualifierCount = currentData.qualifierCount;

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
                  if (val != null) setState(() => selectedFormat = val);
                },
              ),
              const SizedBox(height: 20),
              const Text(
                '본선 진출 인원 (혼합 방식 사용 시)',
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
                '※ 예선 종료 후 본선(토너먼트)으로 전환할 때 사용될 진출 인원입니다.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
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

  void _showAddSectionDialog(
    BuildContext context,
    WidgetRef ref,
    MacmahonState state,
  ) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 참가 부 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '부 이름 (예: 꿈나무부)',
            hintText: '이름을 입력해 주세요',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                ref.read(macmahonProvider.notifier).addSection(name);
                Navigator.pop(ctx);
              }
            },
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

// ── 위젯: 간결해진 대회 상태 헤더 ───────────────────────────
class _TournamentStatusHeader extends StatelessWidget {
  final MacmahonState state;
  const _TournamentStatusHeader({required this.state});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (state.tournamentDate.isNotEmpty ||
            state.tournamentLocation.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 4),
                Text(
                  '${state.tournamentDate} ${state.tournamentLocation.isNotEmpty ? ' | ${state.tournamentLocation}' : ''}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
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

// ── CTA 가이드라인 타일 ────────────────────────────────
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

    // 예선 종료 시점 (추천 라운드 완료) 및 혼합 방식 고려
    if (stage == 1 &&
        historyCount >= recommended &&
        state.format != TournamentFormat.knockout) {
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

    if (state.currentPairing == null) {
      return _buildCta(
        context,
        icon: Icons.play_circle_fill,
        title:
            '${state.selectedSection}: 선수 $playersCount명 등록 완료. 라운드를 시작할 수 있습니다.',
        buttonText: '${state.currentRound}라운드 페어링 생성',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PairingScreen()),
        ),
      );
    }

    return _buildCta(
      context,
      icon: Icons.sports_score,
      title: '${state.selectedSection}: 현재 ${state.currentRound}라운드 가 진행 중입니다.',
      buttonText: '결과 입력 / 페어링 보기',
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PairingScreen()),
      ),
    );
  }

  void _confirmStartKnockout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('본선 전환'),
        content: Text(
          '현재 순위 상위 ${state.currentSectionData.qualifierCount}명을 선발하여 본선 토너먼트를 시작하시겠습니까?\n\n※ 본선 단계로 전환되면 예선 기록은 별도로 관리되며 새로운 토너먼트 대진이 생성됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(macmahonProvider.notifier).startKnockoutStage();
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('본선 토너먼트가 시작되었습니다.')),
              );
            },
            child: const Text('본선 시작'),
          ),
        ],
      ),
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

// ── 위젯: 대진 미리보기 ──────────────────────────────────────
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
        boxShadow: isBlack
            ? [
                BoxShadow(
                  color: AppTheme.black.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(1, 2),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 2,
                  offset: const Offset(1, 1),
                ),
              ],
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

// ── 위젯: 부전승 타일 ────────────────────────────────────────
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

// ── 위젯: 기존 기록 섹션 ──────────────────────────────────
class _HistorySection extends ConsumerWidget {
  const _HistorySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(tournamentHistoryProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '대회 기록 및 관리',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 16),
        historyAsync.when(
          data: (tournaments) {
            if (tournaments.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_toggle_off,
                        size: 48,
                        color: Colors.grey.shade300,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        '저장된 라운드 기록이 없습니다.',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: tournaments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (ctx, index) {
                final t = tournaments[index];
                // 현재 macmahonProvider에 로드된 대회인지 확인
                final currentState = ref.watch(macmahonProvider);
                final isActive = t.id == currentState.id;

                return ListTile(
                  tileColor: isActive
                      ? AppTheme.primary.withValues(alpha: 0.05)
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isActive
                          ? AppTheme.primary.withValues(alpha: 0.3)
                          : Colors.grey.shade200,
                    ),
                  ),
                  leading: Icon(
                    isActive ? Icons.play_circle_fill : Icons.history,
                    color: isActive ? AppTheme.primary : AppTheme.textSecondary,
                  ),
                  title: Row(
                    children: [
                      Text(
                        t.tournamentName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isActive
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                      if (isActive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '작업 중',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                      if (t.isFinished) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade400,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            '종료',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    '${t.tournamentDate} | ${t.players.length}명 참여',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.redAccent,
                        ),
                        onPressed: () => _confirmDelete(context, ref, t),
                      ),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: isActive
                      ? null
                      : () => _loadTournament(context, ref, t),
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, __) => Text('로딩 오류: $e'),
        ),
      ],
    );
  }

  Future<void> _loadTournament(
    BuildContext context,
    WidgetRef ref,
    MacmahonState state,
  ) async {
    // 1. 현재 대회가 있다면 저장
    await ref.read(macmahonProvider.notifier).saveCurrentTournament();

    // 2. 새로운 대회 로드
    ref.read(macmahonProvider.notifier).loadState(state);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${state.tournamentName} 기록을 불러왔습니다.')),
      );
    }
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    MacmahonState state,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('기록 삭제'),
        content: Text('[${state.tournamentName}] 기록을 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref
                  .read(tournamentHistoryProvider.notifier)
                  .deleteTournament(state.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제'),
          ),
        ],
      ),
    );
  }
}

// ── 위젯: 부(Section) 선택기 ────────────────────────────────
class _SectionSelector extends ConsumerWidget {
  final MacmahonState state;
  const _SectionSelector({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: state.sections.length + 1,
        itemBuilder: (ctx, index) {
          if (index == state.sections.length) {
            return Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                onPressed: () => _showAddSectionDialog(context, ref, state),
                icon: const Icon(Icons.add_circle, color: AppTheme.primary),
                tooltip: '부 추가',
              ),
            );
          }

          final section = state.sections[index];
          final isSelected = section == state.selectedSection;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(section),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  ref.read(macmahonProvider.notifier).selectSection(section);
                }
              },
              selectedColor: AppTheme.primary,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.grey.shade300,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── 위젯: 대회 방식 선택기 (부 선택 아래에 표시) ──────────────
class _FormatSelector extends ConsumerWidget {
  final MacmahonState state;
  const _FormatSelector({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentFormat = state.format;
    final notifier = ref.read(macmahonProvider.notifier);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
            spacing: 8,
            runSpacing: 8,
            children: TournamentFormat.values.map((format) {
              final isSelected = currentFormat == format;
              return OutlinedButton(
                onPressed: () {
                  notifier.updateSectionSettings(format: format);
                },
                style: OutlinedButton.styleFrom(
                  backgroundColor:
                      isSelected ? AppTheme.primary : Colors.transparent,
                  foregroundColor:
                      isSelected ? Colors.white : AppTheme.textPrimary,
                  side: BorderSide(
                    color: isSelected ? AppTheme.primary : Colors.grey.shade300,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _formatName(format),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              );
            }).toList(),
          ),
          if (currentFormat == TournamentFormat.league ||
              currentFormat == TournamentFormat.leagueAndKnockout) ...[
            const SizedBox(height: 16),
            const Text(
              '세부 방식 선택 (리그)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: LeagueType.values.map((type) {
                final isSelected = state.currentSectionData.leagueType == type;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      _leagueTypeName(type),
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(macmahonProvider.notifier)
                            .updateSectionSettings(leagueType: type);
                      }
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              '조 개수 (리그 분할)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [1, 2, 3, 4].map((count) {
                final isSelected = state.currentSectionData.groupCount == count;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '$count개 조',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(macmahonProvider.notifier)
                            .updateSectionSettings(groupCount: count);
                      }
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ],
          if (currentFormat == TournamentFormat.leagueAndKnockout) ...[
            const SizedBox(height: 16),
            const Text(
              '본선 진출 인원 (토너먼트)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [2, 4, 8, 16, 32].map((n) {
                final isSelected = state.currentSectionData.qualifierCount == n;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      '$n명',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        ref
                            .read(macmahonProvider.notifier)
                            .updateSectionSettings(qualifierCount: n);
                      }
                    },
                    selectedColor: AppTheme.primary,
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(
                        color: isSelected
                            ? AppTheme.primary
                            : Colors.grey.shade300,
                      ),
                    ),
                    showCheckmark: false,
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── 위젯: 초기 설정 뷰 ─────────────────────────────────────
class _SetupView extends ConsumerStatefulWidget {
  const _SetupView();

  @override
  ConsumerState<_SetupView> createState() => _SetupViewState();
}

class _SetupViewState extends ConsumerState<_SetupView> {
  final _nameController = TextEditingController();
  final _dateController = TextEditingController();
  final _locationController = TextEditingController();
  final List<String> _sections = [];
  final _sectionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _dateController.text =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  void _addSection() {
    final text = _sectionController.text.trim();
    if (text.isNotEmpty && !_sections.contains(text)) {
      setState(() {
        _sections.add(text);
        _sectionController.clear();
      });
    }
  }

  void _removeSection(String section) {
    setState(() {
      _sections.remove(section);
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('ko', 'KR'),
    );
    if (picked != null) {
      setState(() {
        _dateController.text =
            "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    Icons.emoji_events_outlined,
                    size: 80,
                    color: AppTheme.primary,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '대회 시작',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '대회 정보와 참가 부(Section)를 입력해 주세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 40),

                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: '대회명',
                      hintText: '예: 제1회 맥마흔 바둑대회',
                      prefixIcon: Icon(Icons.edit),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _dateController,
                          readOnly: true,
                          onTap: _selectDate,
                          decoration: const InputDecoration(
                            labelText: '날짜',
                            hintText: '2024-03-20',
                            prefixIcon: Icon(Icons.calendar_today),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _locationController,
                          decoration: const InputDecoration(
                            labelText: '장소',
                            hintText: '한국기원',
                            prefixIcon: Icon(Icons.location_on),
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  const Text(
                    '참가 부 목록',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_sections.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        '등록된 부가 없습니다. 아래에서 추가해 주세요.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      children: _sections
                          .map(
                            (s) => Chip(
                              label: Text(
                                s,
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              onDeleted: () => _removeSection(s),
                              backgroundColor: AppTheme.primary.withValues(
                                alpha: 0.1,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _sectionController,
                          decoration: const InputDecoration(
                            hintText: '추가할 부 이름 (예: 유치부)',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _addSection(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addSection,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 48),

                  ElevatedButton(
                    onPressed: () async {
                      String tournamentName = _nameController.text.trim();
                      if (tournamentName.isEmpty) {
                        tournamentName = '무제';
                      }

                      if (_sections.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('최소 하나 이상의 부를 등록해 주세요.'),
                          ),
                        );
                        return;
                      }

                      final notifier = ref.read(macmahonProvider.notifier);
                      final historyNotifier =
                          ref.read(tournamentHistoryProvider.notifier);

                      await notifier.startNewTournament();
                      notifier.updateTournamentInfo(
                        name: tournamentName,
                        date: _dateController.text.trim(),
                        location: _locationController.text.trim(),
                        sections: _sections,
                      );
                      await notifier.saveCurrentTournament();
                      historyNotifier.loadHistory();
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '대회 시작하기',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const _HistorySection(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
