import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app_theme.dart';
import '../providers/macmahon_provider.dart';
import '../providers/history_provider.dart';
import 'section_management_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(macmahonProvider);

    if (state.tournamentName.isEmpty) {
      return const _SetupView();
    }

    return const SectionManagementScreen();
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
    await ref.read(macmahonProvider.notifier).saveCurrentTournament();
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
