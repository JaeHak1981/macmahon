import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:screenshot/screenshot.dart';
import 'dart:math' as math;
import '../app_theme.dart';
import '../providers/macmahon_provider.dart';
import '../models/macmahon_pair.dart';
import '../models/macmahon_player.dart';
import '../utils/macmahon_utils.dart';
import '../services/export_service.dart';

class BracketScreen extends ConsumerStatefulWidget {
  const BracketScreen({super.key});

  @override
  ConsumerState<BracketScreen> createState() => _BracketScreenState();
}

enum DraftStyle { table, direct }

class _BracketScreenState extends ConsumerState<BracketScreen> {
  final TransformationController _transformationController = TransformationController();
  final ScreenshotController _screenshotController = ScreenshotController();
  bool _isManualMode = false;
  DraftStyle _draftStyle = DraftStyle.table;
  List<MacmahonPlayer?>? _draftPlayers;
  bool _isUserInteracting = false;

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _updateFitScale(MacmahonState state, BoxConstraints constraints, List<PairingResult?> displayRounds, int totalRounds, int qCount) {
    if (_isUserInteracting) return;
    
    final currentData = state.currentSectionData;
    final n = totalRounds;
    final leafSlotW = (320.0 + 50.0);
    final expectedNodesAtRound0 = math.pow(2, n - 1).toInt();
    double bW = 0, bH = 0;
    
    final isVertical = currentData.bracketStyle == BracketStyle.classicVertical;
    final isClassic = currentData.bracketStyle == BracketStyle.classic;

    if (currentData.bracketStyle == BracketStyle.compact) {
      bW = leafSlotW * expectedNodesAtRound0 + 400; // 여백 확대
      bH = n * (140.0 + 120.0) + 400;
    } else {
      final expectedLeafs = math.pow(2, n).toInt();
      final isVertical = currentData.bracketStyle == BracketStyle.classicVertical;
      if (isVertical) {
        bW = (280.0 + 100.0) * expectedLeafs + 400;
        bH = (n + 1) * (70.0 + 100.0) + 400;
      } else {
        bW = n * (280.0 + 100.0) + 280.0 + 400;
        bH = (expectedLeafs - 1) * (70.0 + 100.0) + 70.0 + 400;
      }
    }

    final scaleX = (constraints.maxWidth - 40) / bW;
    final scaleY = (constraints.maxHeight - 40) / bH;
    double fitScale = math.min(scaleX, scaleY).clamp(0.001, 1.0);
    
    // 중앙 정렬을 위한 이동값 계산
    final double tx = (constraints.maxWidth - bW * fitScale) / 2;
    final double ty = (constraints.maxHeight - bH * fitScale) / 2;
    
    final Matrix4 targetMatrix = Matrix4.identity()
      ..translate(tx, ty)
      ..scale(fitScale);

    final currentMatrix = _transformationController.value;
    if (currentMatrix != targetMatrix) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _transformationController.value = targetMatrix;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(macmahonProvider);
    final qualifiers = state.currentSectionData.knockoutQualifiers;
    final currentData = state.currentSectionData;

    bool isKnockoutMatch(PairingResult r) {
      if (qualifiers.isEmpty) return true;
      final allKnockoutPlayers = r.pairs.every((p) => 
        qualifiers.contains(p.black.id) && qualifiers.contains(p.white.id));
      final byeKnockout = r.byePlayers.every((b) => qualifiers.contains(b.id));
      return allKnockoutPlayers && byeKnockout;
    }

    final knockoutHistory = state.history.where(isKnockoutMatch).toList();
    final currentPairing = state.currentPairing;
    final currentIsKnockout = currentData.stage == 2 && currentPairing != null;

    final qCount = qualifiers.isNotEmpty
        ? qualifiers.length
        : state.currentSectionPlayers.length;
    
    final totalRounds = qCount > 1 ? (math.log(qCount) / math.log(2)).ceil() : 1;
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
        final allPossible = qualifiers.isNotEmpty
            ? state.currentSectionPlayers.where((p) => qualifiers.contains(p.id)).toList()
            : state.currentSectionPlayers;
        
        _draftPlayers ??= List.filled(qCount, null);
        final usedIds = _draftPlayers!.where((p) => p != null).map((p) => p!.id).toSet();
        final available = allPossible.where((p) => !usedIds.contains(p.id)).toList();

        return Column(
          children: [
            Row(
              children: [
                const Text('대진 추첨 모드', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)),
                const Spacer(),
                SegmentedButton<DraftStyle>(
                  segments: const [
                    ButtonSegment(value: DraftStyle.table, label: Text('테이블형'), icon: Icon(Icons.table_rows_rounded)),
                    ButtonSegment(value: DraftStyle.direct, label: Text('직관형(드래그)'), icon: Icon(Icons.account_tree_rounded)),
                  ],
                  selected: {_draftStyle},
                  onSelectionChanged: (set) => setState(() => _draftStyle = set.first),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _draftPlayers!.any((p) => p != null)
                      ? () async {
                          final finalOrder = _draftPlayers!.map<MacmahonPlayer>((p) => p ?? MacmahonPlayer(
                            id: 'bye_${DateTime.now().millisecondsSinceEpoch}', 
                            name: '(부전)', 
                            section: state.selectedSection,
                            initialMms: 0,
                            currentMms: 0,
                          )).toList();
                          await ref.read(macmahonProvider.notifier).generateManualPairing(finalOrder);
                          if (mounted) {
                            setState(() {
                              _isManualMode = false;
                              _draftPlayers = null;
                            });
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
                  child: const Text('대진 확정'),
                ),
                const SizedBox(width: 8),
                TextButton(onPressed: () => setState(() => _isManualMode = false), child: const Text('취소')),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 200,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                          child: const Center(child: Text('선수 명단', style: TextStyle(fontWeight: FontWeight.bold))),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: available.length,
                            itemBuilder: (context, index) {
                              final p = available[index];
                              return Draggable<MacmahonPlayer>(
                                data: p,
                                feedback: Material(
                                  elevation: 8,
                                  borderRadius: BorderRadius.circular(4),
                                  color: Colors.transparent,
                                  child: Container(
                                    width: 100,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withOpacity(0.8),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(p.name, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900)),
                                  ),
                                ),
                                childWhenDragging: Opacity(opacity: 0.3, child: ListTile(title: Text(p.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)), dense: true)),
                                child: ListTile(
                                  title: Text(p.name, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
                                  dense: true,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_draftStyle == DraftStyle.table) ...[
                    Container(
                      width: 300,
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(top: Radius.circular(12))),
                            child: const Center(child: Text('추첨 테이블', style: TextStyle(fontWeight: FontWeight.bold))),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              itemCount: qCount,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final selected = _draftPlayers![index];
                                return DragTarget<MacmahonPlayer>(
                                  onAccept: (data) => setState(() {
                                    for (int i = 0; i < _draftPlayers!.length; i++) {
                                      if (_draftPlayers![i]?.id == data.id) _draftPlayers![i] = null;
                                    }
                                    _draftPlayers![index] = data;
                                  }),
                                  builder: (context, candidate, _) => ListTile(
                                    dense: true,
                                    leading: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                    title: Text(selected?.name ?? (candidate.isNotEmpty ? '여기에 놓으세요' : '-'), style: TextStyle(color: selected == null ? Colors.grey : Colors.black, fontWeight: selected == null ? FontWeight.normal : FontWeight.bold)),
                                    trailing: selected != null ? IconButton(icon: const Icon(Icons.close, size: 14), onPressed: () => setState(() => _draftPlayers![index] = null)) : null,
                                    tileColor: candidate.isNotEmpty ? AppTheme.primary.withOpacity(0.05) : null,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: _DraftPreviewBracket(
                            draftPlayers: _draftPlayers!,
                            totalRounds: totalRounds,
                            style: currentData.bracketStyle == BracketStyle.compact 
                                ? BracketStyle.classicVertical 
                                : currentData.bracketStyle,
                            onPlayerDropped: (index, player) => setState(() {
                              for (int i = 0; i < _draftPlayers!.length; i++) {
                                if (_draftPlayers![i]?.id == player.id) _draftPlayers![i] = null;
                              }
                              _draftPlayers![index] = player;
                            }),
                            onPlayerRemoved: (index) => setState(() => _draftPlayers![index] = null),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      }

      final selectedPlayers = qualifiers.isNotEmpty 
          ? state.currentSectionPlayers.where((p) => qualifiers.contains(p.id)).toList()
          : state.currentSectionPlayers;

      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.account_tree_outlined, size: 64, color: AppTheme.primaryLight),
              const SizedBox(height: 16),
              Text('$qCount강 토너먼트 대기', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              const Text('본선 진출자 명단을 확인하고 대진 생성 방식을 선택하세요.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              
              // 진출자 명단 박스
              Container(
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('본선 진출 선수', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('${selectedPlayers.length}명', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary)),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(8),
                        itemCount: selectedPlayers.length,
                        itemBuilder: (context, index) {
                          final p = selectedPlayers[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(radius: 10, backgroundColor: AppTheme.primaryLight, child: Text('${index + 1}', style: const TextStyle(fontSize: 10, color: Colors.white))),
                                const SizedBox(width: 12),
                                Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                const Spacer(),
                                Text(p.groupId != null ? '${p.groupId}조' : '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(state.errorMessage!, style: const TextStyle(color: Colors.red)),
                ),
              if (state.isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await ref.read(macmahonProvider.notifier).generatePairing();
                        },
                        icon: const Icon(Icons.auto_awesome),
                        label: const Text('자동 시드 배정 생성', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: () => setState(() => _isManualMode = true),
                        icon: const Icon(Icons.edit_note),
                        label: const Text('수동 대진 추첨 (드래그)', style: TextStyle(fontSize: 15)),
                        style: OutlinedButton.styleFrom(side: const BorderSide(color: AppTheme.primary), foregroundColor: AppTheme.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      );
    }

    final body = Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SegmentedButton<BracketStyle>(
                segments: [
                  if (!_isManualMode)
                    const ButtonSegment(value: BracketStyle.compact, label: Text('컴팩트', style: TextStyle(fontSize: 12)), icon: Icon(Icons.grid_view_rounded, size: 16)),
                  const ButtonSegment(value: BracketStyle.classic, label: Text('클래식(가로)', style: TextStyle(fontSize: 12)), icon: Icon(Icons.account_tree_rounded, size: 16)),
                  const ButtonSegment(value: BracketStyle.classicVertical, label: Text('클래식(세로)', style: TextStyle(fontSize: 12)), icon: Icon(Icons.vertical_split_rounded, size: 16)),
                ],
                selected: {
                  _isManualMode && currentData.bracketStyle == BracketStyle.compact 
                      ? BracketStyle.classicVertical 
                      : currentData.bracketStyle
                },
                onSelectionChanged: (Set<BracketStyle> newSelection) {
                  ref.read(macmahonProvider.notifier).updateBracketStyle(newSelection.first);
                },
                style: SegmentedButton.styleFrom(visualDensity: VisualDensity.compact, selectedBackgroundColor: AppTheme.primary.withOpacity(0.1), selectedForegroundColor: AppTheme.primary),
              ),
            ],
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              if (displayRounds.any((r) => r != null)) {
                _updateFitScale(state, constraints, displayRounds, totalRounds, qCount);
              }
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: displayRounds.every((r) => r == null)
                    ? buildEmptyState()
                    : Listener(
                        onPointerSignal: (pointerSignal) {
                          if (pointerSignal is PointerScrollEvent) {
                            final double zoomFactor = 1.1;
                            final double scaleDelta = pointerSignal.scrollDelta.dy > 0 ? 1 / zoomFactor : zoomFactor;
                            final Offset localPosition = pointerSignal.localPosition;
                            
                            final Matrix4 matrix = _transformationController.value.clone();
                            final double currentScale = matrix.getMaxScaleOnAxis();
                            final double targetScale = (currentScale * scaleDelta).clamp(0.001, 5.0);
                            final double actualDelta = targetScale / currentScale;

                            // 마우스 커서 위치를 중심으로 확대/축소
                            matrix.translate(localPosition.dx, localPosition.dy);
                            matrix.scale(actualDelta);
                            matrix.translate(-localPosition.dx, -localPosition.dy);
                            
                            _transformationController.value = matrix;
                            _isUserInteracting = true;
                          }
                        },
                        child: InteractiveViewer(
                          transformationController: _transformationController,
                          minScale: 0.001,
                          maxScale: 5.0,
                          boundaryMargin: const EdgeInsets.all(2000),
                          constrained: false,
                          onInteractionStart: (_) => _isUserInteracting = true,
                          child: Container(
                            child: _buildMainBracket(
                              style: currentData.bracketStyle,
                              displayRounds: displayRounds,
                              totalRounds: totalRounds,
                              currentRoundIdx: currentRoundIdx,
                              qCount: qCount,
                              onMatchTap: onMatchTap,
                            ),
                          ),
                        ),
                      ),
              );
            },
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
                          final newHist = s.history.where(isKnockoutMatch).toList();
                          if (newHist.length < totalRounds) {
                            await ref.read(macmahonProvider.notifier).generatePairing();
                          }
                        }
                      : null,
                  icon: const Icon(Icons.arrow_upward),
                  label: Text(currentRoundDone ? '다음 라운드 진행' : '결과를 모두 입력하세요', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white, disabledBackgroundColor: Colors.grey.shade300, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ),
          ),
        if (tournamentDone && knockoutHistory.isNotEmpty)
          _ChampionBanner(round: knockoutHistory.last),
      ],
    );

    final hasScaffold = context.findAncestorWidgetOfExactType<Scaffold>() != null;
    if (hasScaffold) return Center(child: body);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text('${state.selectedSection} 대진표'),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: '이미지로 저장',
            icon: const Icon(Icons.image_outlined),
            onPressed: () async {
              final state = ref.read(macmahonProvider);
              final currentData = state.currentSectionData;
              final qCount = currentData.knockoutQualifiers.isNotEmpty ? currentData.knockoutQualifiers.length : state.currentSectionPlayers.length;
              final n = qCount > 1 ? (math.log(qCount) / math.log(2)).ceil() : 1;
              
              double bW = 0, bH = 0;
              if (currentData.bracketStyle == BracketStyle.compact) {
                bW = (320.0 + 50.0) * math.pow(2, n - 1).toInt() + 200;
                bH = n * (140.0 + 120.0) + 300;
              } else {
                final expectedLeafs = math.pow(2, n).toInt();
                final isVertical = currentData.bracketStyle == BracketStyle.classicVertical;
                if (isVertical) {
                  bW = (280.0 + 100.0) * expectedLeafs + 200;
                  bH = (n + 1) * (70.0 + 100.0) + 300;
                } else {
                  bW = n * (280.0 + 100.0) + 280.0 + 200;
                  bH = (expectedLeafs - 1) * (70.0 + 100.0) + 70.0 + 250;
                }
              }

              final exportWidget = Material(
                color: AppTheme.background,
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(state.tournamentName.isNotEmpty ? state.tournamentName : '대진표', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      Text('${state.selectedSection} - 토너먼트 대진표', style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 30),
                      _buildMainBracket(
                        style: currentData.bracketStyle,
                        displayRounds: displayRounds,
                        totalRounds: totalRounds,
                        currentRoundIdx: currentRoundIdx,
                        qCount: qCount,
                        onMatchTap: onMatchTap,
                      ),
                    ],
                  ),
                ),
              );

              final imageBytes = await _screenshotController.captureFromWidget(
                exportWidget,
                context: context,
                targetSize: Size(bW + 400, bH + 400),
                delay: const Duration(milliseconds: 300),
              );

              final path = await ExportService.saveImageBytes(
                imageBytes,
                '${state.tournamentName.isNotEmpty ? state.tournamentName : "tournament"}_대진표',
              );
              
              if (path != null && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('이미지가 저장되었습니다: $path')));
              }
            },
          ),
          IconButton(
            tooltip: '화면에 맞춤',
            icon: const Icon(Icons.fullscreen_exit),
            onPressed: () {
              setState(() {
                _isUserInteracting = false;
              });
            },
          ),
          IconButton(
            tooltip: '본선 초기화',
            icon: const Icon(Icons.history),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('본선 초기화'),
                  content: const Text('현재 본선 대진을 삭제하고 예선 결과 화면으로 돌아가시겠습니까?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), style: TextButton.styleFrom(foregroundColor: Colors.red), child: const Text('초기화')),
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
      body: Center(child: body),
    );
  }

  Widget _buildMainBracket({
    required BracketStyle style,
    required List<PairingResult?> displayRounds,
    required int totalRounds,
    required int currentRoundIdx,
    required int qCount,
    required void Function(MacmahonPair) onMatchTap,
  }) {
    switch (style) {
      case BracketStyle.compact:
        return _CompactBracketTree(
          displayRounds: displayRounds,
          totalRounds: totalRounds,
          currentRoundIdx: currentRoundIdx,
          qCount: qCount,
          onMatchTap: onMatchTap,
        );
      case BracketStyle.classic:
        return _ClassicBracketTree(
          displayRounds: displayRounds,
          totalRounds: totalRounds,
          currentRoundIdx: currentRoundIdx,
          qCount: qCount,
          onMatchTap: onMatchTap,
          isVertical: false,
        );
      case BracketStyle.classicVertical:
        return _ClassicBracketTree(
          displayRounds: displayRounds,
          totalRounds: totalRounds,
          currentRoundIdx: currentRoundIdx,
          qCount: qCount,
          onMatchTap: onMatchTap,
          isVertical: true,
        );
    }
  }
}

// ── 컴팩트 브라켓 트리 ────────────────────────────────────────────────────────
class _CompactBracketTree extends StatelessWidget {
  final List<PairingResult?> displayRounds;
  final int totalRounds;
  final int currentRoundIdx;
  final int qCount;
  final void Function(MacmahonPair) onMatchTap;
  static const double kW = 320.0, kH = 140.0, kVGap = 120.0, kHGap = 50.0;
  const _CompactBracketTree({required this.displayRounds, required this.totalRounds, required this.currentRoundIdx, required this.qCount, required this.onMatchTap});

  @override
  Widget build(BuildContext context) {
    final n = totalRounds;
    final leafSlotW = kW + kHGap;
    final expectedLeafs = math.pow(2, n - 1).toInt();
    final winnerMap = <int, Map<int, String>>{};
    for (int r = 0; r < n; r++) {
      final round = displayRounds[r];
      if (round == null) continue;
      winnerMap[r] = {};
      for (int m = 0; m < round.pairs.length; m++) {
        final p = round.pairs[m];
        if (p.isResultEntered && p.winnerId != null) winnerMap[r]![m] = p.winnerId == p.black.id ? p.black.name : p.white.name;
      }
    }
    double cx(int r, int m) {
      final slots = math.pow(2, r).toDouble();
      return (m * slots + slots / 2.0) * leafSlotW + 200;
    }
    double yTop(int r) => (n - r) * (kH + kVGap) + 200;
    final lines = <_Line>[];
    final cards = <Widget>[];
    for (int r = 0; r < n; r++) {
      final round = displayRounds[r], y = yTop(r), expected = math.pow(2, n - 1 - r).toInt(), isCurrent = r == currentRoundIdx;
      final rName = MacmahonUtils.getRoundName(currentRound: r + 1, totalRounds: n, format: TournamentFormat.knockout, playerCount: qCount, stage: 2);
      cards.add(Positioned(left: 0, right: 0, top: y - 25, child: Center(child: Text(rName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isCurrent ? AppTheme.primary : Colors.grey)))));
      for (int m = 0; m < expected; m++) {
        final xc = cx(r, m), pair = (round != null && m < round.pairs.length) ? round.pairs[m] : null;
        String? pA = pair != null ? pair.black.name : (r > 0 && winnerMap.containsKey(r - 1) ? winnerMap[r - 1]![m * 2] : null);
        String? pB = pair != null ? pair.white.name : (r > 0 && winnerMap.containsKey(r - 1) ? winnerMap[r - 1]![m * 2 + 1] : null);
        String? winner;
        if (pair != null && pair.isResultEntered && pair.winnerId != null) winner = pair.winnerId == pair.black.id ? pair.black.name : pair.white.name;
        final tappable = isCurrent && pair != null;
        cards.add(Positioned(left: xc - kW / 2, top: y, width: kW, height: kH, child: _MatchSlot(playerA: pA, playerB: pB, winnerName: winner, isCurrent: isCurrent, isCompleted: pair != null && pair.isResultEntered, onTap: tappable ? () => onMatchTap(pair) : null)));
        
        if (r < n - 1) {
          final pm = m ~/ 2, pxc = cx(r + 1, pm), pyNext = yTop(r + 1), midY = y - kVGap / 2;
          lines.add(_Line(xc, y, xc, midY));
          if (m % 2 == 0) {
            final sib = cx(r, m + 1);
            lines.add(_Line(xc, midY, sib, midY));
            lines.add(_Line(pxc, midY, pxc, pyNext + kH));
          }
          } else if (r == n - 1) {
            // 결승전에서 우승자로 이어지는 마지막 선과 우승자 박스
            final yChamp = yTop(n);
            if (winner != null) {
              final champW = kW * 1.2;
              final champH = 80.0;
              lines.add(_Line(xc, y, xc, yChamp + champH));
              cards.add(Positioned(
                left: xc - champW / 2, 
                top: yChamp, 
                width: champW, 
                height: champH, 
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50, 
                    borderRadius: BorderRadius.circular(16), 
                    border: Border.all(color: Colors.amber.shade600, width: 3), 
                    boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 12, spreadRadius: 2)]
                  ), 
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center, 
                      children: [
                        const Icon(Icons.emoji_events, color: Colors.amber, size: 36), 
                        const SizedBox(width: 12), 
                        Flexible(
                          child: Text(
                            winner, 
                            textAlign: TextAlign.center, 
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 32, color: Colors.black)
                          ),
                        ),
                      ]
                    )
                  )
                )
              ));
              cards.add(Positioned(left: 0, right: 0, top: yChamp - 35, child: const Center(child: Text('🏆 최종 우승', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orange)))));
            }
          }
      }
    }
    final totalW = leafSlotW * expectedLeafs + 400;
    final totalH = n * (kH + kVGap) + 400;
    return SizedBox(width: totalW, height: totalH, child: Stack(clipBehavior: Clip.none, children: [CustomPaint(size: Size(totalW, totalH), painter: _LinePainter(lines: lines)), ...cards]));
  }
}

// ── 클래식 브라켓 트리 ────────────────────────────────────────────────
class _ClassicBracketTree extends StatelessWidget {
  final List<PairingResult?> displayRounds;
  final int totalRounds;
  final int currentRoundIdx;
  final int qCount;
  final void Function(MacmahonPair) onMatchTap;
  final bool isVertical;
  static const double kW = 280.0, kH = 70.0, kHGap = 100.0, kVGap = 100.0;
  const _ClassicBracketTree({required this.displayRounds, required this.totalRounds, required this.currentRoundIdx, required this.qCount, required this.onMatchTap, required this.isVertical});

  @override
  Widget build(BuildContext context) {
    final n = totalRounds, totalLevels = n + 1;
    final cards = <Widget>[], lines = <_Line>[];
    final nodes = List.generate(totalLevels, (_) => <_NodeData?>[]);
    final round1 = displayRounds.isNotEmpty ? displayRounds[0] : null;
    final expectedLeafs = math.pow(2, n).toInt();

    for (int m = 0; m < expectedLeafs / 2; m++) {
      final pair = (round1 != null && m < round1.pairs.length) ? round1.pairs[m] : null;
      nodes[0].add(_NodeData(name: pair?.black.name, isWinner: pair?.winnerId == pair?.black.id && pair?.winnerId != null, pair: pair, isCurrentMatch: currentRoundIdx == 0));
      nodes[0].add(_NodeData(name: pair?.white.name, isWinner: pair?.winnerId == pair?.white.id && pair?.winnerId != null, pair: pair, isCurrentMatch: currentRoundIdx == 0));
    }
    
    for (int level = 1; level < totalLevels; level++) {
      final round = level <= displayRounds.length ? displayRounds[level - 1] : null;
      final nextRound = level < displayRounds.length ? displayRounds[level] : null;
      final expectedNodes = math.pow(2, n - level).toInt();
      for (int m = 0; m < expectedNodes; m++) {
        final pair = (round != null && m < round.pairs.length) ? round.pairs[m] : null;
        String? winnerName;
        if (pair != null && pair.isResultEntered && pair.winnerId != null) winnerName = (pair.winnerId == pair.black.id) ? pair.black.name : pair.white.name;
        bool isWinner = false;
        if (nextRound != null) {
          final nextMatchIdx = m ~/ 2;
          if (nextMatchIdx < nextRound.pairs.length) {
            final nextMatch = nextRound.pairs[nextMatchIdx];
            if (nextMatch.isResultEntered && (nextMatch.winnerId == pair?.winnerId && pair?.winnerId != null)) isWinner = true;
          }
        } else if (level == n) isWinner = pair?.winnerId != null && pair?.isResultEntered == true;
        bool isCurrent = (level - 1) == currentRoundIdx;
        MacmahonPair? activePair = pair;
        if (!isCurrent && level == currentRoundIdx && nextRound != null && m < nextRound.pairs.length * 2) { isCurrent = true; activePair = nextRound.pairs[m ~/ 2]; }
        nodes[level].add(_NodeData(name: winnerName, isWinner: isWinner, pair: activePair, isCurrentMatch: isCurrent));
      }
    }

    double cx(int level, int m) {
      if (isVertical) {
        final step = math.pow(2, level).toDouble();
        return (m * step + (step - 1) / 2.0) * (kW + kHGap) + 200; // 여백 확대
      }
      return level * (kW + kHGap) + 200; // 여백 확대
    }
    double cy(int level, int m) {
      if (isVertical) return (totalLevels - 1 - level) * (kH + kVGap) + 200; // 여백 확대
      final step = math.pow(2, level).toDouble();
      return (m * step + (step - 1) / 2.0) * (kH + kVGap) + 200; // 여백 확대
    }

    // 라운드 이름 추가 (선을 완전히 가리고 여러 곳에 반복 배치하여 시인성 확보)
    for (int level = 1; level <= n; level++) {
      final rName = MacmahonUtils.getRoundName(currentRound: level, totalRounds: n, format: TournamentFormat.knockout, playerCount: qCount, stage: 2);
      final isCurrent = (level - 1) == currentRoundIdx;
      final expectedNodes = math.pow(2, n - level).toInt();
      
      // 반복 배치할 위치 리스트 생성 (더 촘촘하게 배치하여 빈 곳 제거)
      final List<double> xPositions = [];
      if (isVertical) {
        // 최소 2~3경기마다 하나씩 배치되도록 간격 조정
        int step = (expectedNodes > 4) ? expectedNodes ~/ 3 : 1;
        if (step < 1) step = 1;
        
        for (int m = 0; m < expectedNodes; m += step) {
          xPositions.add(cx(level, m));
        }
        // 마지막 칸이 빠졌다면 추가
        if (xPositions.isNotEmpty && xPositions.last != cx(level, expectedNodes - 1)) {
          xPositions.add(cx(level, expectedNodes - 1));
        }
      } else {
        xPositions.add(cx(level, 0));
      }

      for (final xPos in xPositions) {
        final double labelY = isVertical 
            ? cy(level, 0) + kH + 25 
            : 40.0;

        cards.add(Positioned(
          left: xPos - 125,
          top: labelY,
          width: 250,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrent ? AppTheme.primary : Colors.white,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: isCurrent ? AppTheme.primary : Colors.blueGrey.shade400, width: 3),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))
                ],
              ),
              child: Text(
                rName,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: isCurrent ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
        ));
      }
    }

    // 카드 및 선 생성
    for (int level = 0; level < totalLevels; level++) {
      for (int m = 0; m < nodes[level].length; m++) {
        final node = nodes[level][m], x = cx(level, m), y = cy(level, m);
        cards.add(Positioned(
          left: x - kW / 2, 
          top: y, 
          width: kW, 
          height: kH, 
          child: _ClassicNodeBox(
            name: node?.name, 
            isWinner: node?.isWinner ?? false, 
            isLeaf: level == 0, 
            isChampion: level == n, 
            isCurrent: node?.isCurrentMatch ?? false, 
            onTap: (node?.pair != null && node!.isCurrentMatch) ? () => onMatchTap(node.pair!) : null
          )
        ));
        
        if (level < n) {
          if (isVertical) {
            final nextX = cx(level + 1, m ~/ 2), nextY = cy(level + 1, m ~/ 2), midY = y - kVGap / 2;
            lines.add(_Line(x, y, x, midY));
            if (m % 2 == 0) {
              final sibX = cx(level, m + 1);
              lines.add(_Line(x, midY, sibX, midY));
              lines.add(_Line(nextX, midY, nextX, nextY + kH));
            }
          } else {
            final nextX = cx(level + 1, m ~/ 2), nextY = cy(level + 1, m ~/ 2), midX = x + (nextX - x) / 2;
            lines.add(_Line(x + kW / 2, y + kH / 2, midX, y + kH / 2));
            if (m % 2 == 0) {
              final sibY = cy(level, m + 1);
              lines.add(_Line(midX, y + kH / 2, midX, sibY + kH / 2));
              lines.add(_Line(midX, nextY + kH / 2, nextX - kW / 2, nextY + kH / 2));
            }
          }
        }
      }
    }

    final totalWidth = isVertical ? (kW + kHGap) * expectedLeafs + 400 : cx(n, 0) + kW + 400;
    final totalHeight = isVertical ? (totalLevels) * (kH + kVGap) + 400 : cy(0, expectedLeafs - 1) + kH + 400;
    
    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CustomPaint(
            size: Size(totalWidth, totalHeight),
            painter: _BracketPainter(lines: lines, color: AppTheme.primary, strokeWidth: 2.5),
          ),
          ...cards,
        ],
      ),
    );
  }
}

class _NodeData {
  final String? name; final bool isWinner; final MacmahonPair? pair; final bool isCurrentMatch;
  _NodeData({this.name, this.isWinner = false, this.pair, this.isCurrentMatch = false});
}

class _ClassicNodeBox extends StatelessWidget {
  final String? name; final bool isWinner, isLeaf, isChampion, isCurrent; final VoidCallback? onTap;
  const _ClassicNodeBox({this.name, required this.isWinner, required this.isLeaf, required this.isChampion, required this.isCurrent, this.onTap});
  @override
  Widget build(BuildContext context) {
    final bool isWinnerActive = isWinner || isChampion;
    final Color borderColor = isCurrent ? AppTheme.primary : (isWinnerActive ? Colors.green.shade400 : (isLeaf ? Colors.blue.shade300 : Colors.grey.shade300));
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isWinnerActive ? Colors.blue.shade50 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: isCurrent ? 3 : 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Center(
          child: Text(
            name ?? (isLeaf ? '?' : ''),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: name == null ? Colors.grey : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}

class _MatchSlot extends StatelessWidget {
  final String? playerA, playerB, winnerName; final bool isCurrent, isCompleted; final VoidCallback? onTap;
  const _MatchSlot({this.playerA, this.playerB, this.winnerName, required this.isCurrent, required this.isCompleted, this.onTap});
  @override
  Widget build(BuildContext context) {
    final borderColor = isCurrent && !isCompleted ? AppTheme.primary : (isCompleted ? Colors.green.shade400 : Colors.grey.shade400);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor,
            width: isCurrent && !isCompleted ? 3.5 : 2.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isCurrent && !isCompleted ? AppTheme.primary.withOpacity(0.2) : Colors.black.withOpacity(0.1),
              blurRadius: 6,
              offset: const Offset(0, 3),
            )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            children: [
              _SlotRow(name: playerA ?? '진출자 미정', isEmpty: playerA == null, isWinner: winnerName != null && winnerName == playerA, isLoser: isCompleted && winnerName != playerA && playerA != null, label: '흑'),
              Container(height: 1.5, color: Colors.grey.shade100),
              _SlotRow(name: playerB ?? '진출자 미정', isEmpty: playerB == null, isWinner: winnerName != null && winnerName == playerB, isLoser: isCompleted && winnerName != playerB && playerB != null, label: '백'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  final String name, label; final bool isEmpty, isWinner, isLoser;
  const _SlotRow({required this.name, required this.label, required this.isEmpty, required this.isWinner, required this.isLoser});
  @override
  Widget build(BuildContext context) {
    final Color textColor = isEmpty ? Colors.grey.shade300 : (isLoser ? Colors.grey.shade400 : Colors.black);
    return Expanded(
      child: Container(
        color: isWinner ? Colors.blue.shade50 : null,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: label == '흑' ? Colors.black87 : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Center(child: Text(label[0], style: TextStyle(color: label == '흑' ? Colors.white : Colors.black87, fontSize: 10, fontWeight: FontWeight.bold))),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                textAlign: TextAlign.start,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  fontStyle: isEmpty ? FontStyle.italic : FontStyle.normal,
                  decoration: isLoser ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            if (isWinner) Icon(Icons.emoji_events, color: Colors.amber.shade700, size: 24),
          ],
        ),
      ),
    );
  }
}

class _ChampionBanner extends StatelessWidget {
  final PairingResult round;
  const _ChampionBanner({required this.round});
  @override
  Widget build(BuildContext context) {
    if (round.pairs.isEmpty) return const SizedBox.shrink();
    final fp = round.pairs.first;
    if (!fp.isResultEntered || fp.winnerId == null) return const SizedBox.shrink();
    final name = fp.winnerId == fp.black.id ? fp.black.name : fp.white.name;
    return Container(width: double.infinity, padding: const EdgeInsets.all(20), color: Colors.amber.shade50, child: Column(children: [
      const Text('🏆 최종 우승자', style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
    ]));
  }
}

class _BracketPainter extends CustomPainter {
  final List<_Line> lines; final Color color; final double strokeWidth;
  _BracketPainter({required this.lines, required this.color, this.strokeWidth = 3.0});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color..strokeWidth = strokeWidth..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    for (final l in lines) canvas.drawLine(Offset(l.x1, l.y1), Offset(l.x2, l.y2), p);
  }
  @override
  bool shouldRepaint(_BracketPainter old) => true;
}

class _Line { final double x1, y1, x2, y2; const _Line(this.x1, this.y1, this.x2, this.y2); }

class _LinePainter extends CustomPainter {
  final List<_Line> lines;
  const _LinePainter({required this.lines});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = Colors.grey.shade400..strokeWidth = 2.5..style = PaintingStyle.stroke;
    for (final l in lines) canvas.drawLine(Offset(l.x1, l.y1), Offset(l.x2, l.y2), p);
  }
  @override
  bool shouldRepaint(_LinePainter old) => true;
}

class _DraftPreviewBracket extends StatelessWidget {
  final List<MacmahonPlayer?> draftPlayers;
  final int totalRounds;
  final BracketStyle style;
  final void Function(int index, MacmahonPlayer player)? onPlayerDropped;
  final void Function(int index)? onPlayerRemoved;
  static const double kW = 180.0, kH = 40.0, leafSlotW = 240.0, kVGap = 80.0;
  const _DraftPreviewBracket({required this.draftPlayers, required this.totalRounds, required this.style, this.onPlayerDropped, this.onPlayerRemoved});
  @override
  Widget build(BuildContext context) {
    final n = totalRounds, totalLevels = n + 1, cards = <Widget>[], lines = <_Line>[], isClassic = style == BracketStyle.classic, isClassicVertical = style == BracketStyle.classicVertical, expectedLeafs = math.pow(2, n).toInt();
    final bool isCompact = !isClassic && !isClassicVertical;
    
    double cx(int level, int m) {
      if (isClassic) return level * (kW + 80.0) + 100;
      final step = math.pow(2, level).toDouble();
      if (isClassicVertical) return (m * step + (step - 1) / 2.0) * (kW + 40.0) + 100;
      return (m * step + (step - 1) / 2.0) * leafSlotW + 100;
    }
    double cy(int level, int m) {
      if (isClassic) { 
        final step = math.pow(2, level).toDouble(); 
        return (m * step + (step - 1) / 2.0) * (kH * 2 + 20.0) + 120;
      }
      if (isClassicVertical) return (totalLevels - 1 - level) * (kH + 60.0) + 120;
      return (totalLevels - 1 - level) * (kH * 2 + kVGap) + 120;
    }

    for (int level = 0; level < totalLevels; level++) {
      int expectedNodes;
      if (isCompact) {
        if (level == 0) expectedNodes = math.pow(2, n - 1).toInt();
        else expectedNodes = math.pow(2, math.max(0, n - 1 - level)).toInt();
        if (level == n) expectedNodes = 1;
      } else {
        expectedNodes = math.pow(2, n - level).toInt();
      }

      for (int m = 0; m < expectedNodes; m++) {
        final x = cx(level, m), y = cy(level, m), isLeaf = level == 0;
        
        if (isLeaf && isCompact) {
          final idxA = m * 2, idxB = m * 2 + 1;
          final nameA = idxA < draftPlayers.length ? draftPlayers[idxA]?.name : null;
          final nameB = idxB < draftPlayers.length ? draftPlayers[idxB]?.name : null;
          
          cards.add(Positioned(
            left: x - kW / 2, top: y, width: kW, height: kH * 2,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(4), 
                border: Border.all(color: Colors.grey.shade300),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))],
              ),
              child: Column(children: [
                _DraftSlot(index: idxA, name: nameA, onDropped: onPlayerDropped, onRemoved: onPlayerRemoved, label: 'A'),
                const Divider(height: 1, thickness: 1, color: Colors.grey),
                _DraftSlot(index: idxB, name: nameB, onDropped: onPlayerDropped, onRemoved: onPlayerRemoved, label: 'B'),
              ]),
            ),
          ));
        } else {
          final name = (isLeaf && (isClassic || isClassicVertical) && m < draftPlayers.length) ? draftPlayers[m]?.name : null;
          cards.add(Positioned(
            left: x - kW / 2, top: y, width: kW, height: kH,
            child: isLeaf 
                ? _DraftSlot(index: m, name: name, onDropped: onPlayerDropped, onRemoved: onPlayerRemoved, useBox: true)
                : Container(
                    decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.green.shade200)),
                    child: Center(child: Text(name ?? '', textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold))),
                  ),
          ));
        }
        
        if (level < n) {
          if (isClassic) {
            final nextX = cx(level + 1, m ~/ 2), nextY = cy(level + 1, m ~/ 2), midX = x + (nextX - x) / 2;
            lines.add(_Line(x + kW / 2, y + kH / 2, midX, y + kH / 2));
            if (m % 2 == 0) {
              final sibY = cy(level, m + 1);
              lines.add(_Line(midX, y + kH / 2, midX, sibY + kH / 2));
              lines.add(_Line(midX, nextY + kH / 2, nextX - kW / 2, nextY + kH / 2));
            }
          } else {
            final pyNext = cy(level + 1, m ~/ 2), midY = y - kVGap / 2;
            lines.add(_Line(x, y, x, midY));
            if (m % 2 == 0) {
              final sibX = cx(level, m + 1);
              lines.add(_Line(x, midY, sibX, midY));
              final parentX = cx(level + 1, m ~/ 2);
              lines.add(_Line(parentX, midY, parentX, pyNext + kH));
            }
          }
        }
      }
    }
    
    final totalW = isClassic ? cx(n, 0) + kW + 200 : cx(0, expectedLeafs - 1) + kW + 200;
    final totalH = (isClassic ? cy(0, expectedLeafs - 1) : cy(0, 0)) + kH * 2 + 200;
    return SizedBox(width: totalW, height: totalH, child: Stack(clipBehavior: Clip.none, children: [CustomPaint(size: Size(totalW, totalH), painter: _BracketPainter(lines: lines, color: Colors.blue.shade700, strokeWidth: 2.0)), ...cards]));
  }
}

class _DraftSlot extends StatelessWidget {
  final int index; final String? name; final String? label; final void Function(int, MacmahonPlayer)? onDropped; final void Function(int)? onRemoved; final bool useBox;
  const _DraftSlot({required this.index, this.name, this.label, this.onDropped, this.onRemoved, this.useBox = false});
  @override
  Widget build(BuildContext context) {
    return DragTarget<MacmahonPlayer>(onAccept: (data) => onDropped?.call(index, data), builder: (context, candidate, _) {
      final isHovering = candidate.isNotEmpty;
      final content = GestureDetector(onTap: () => onRemoved?.call(index), child: Container(decoration: useBox ? BoxDecoration(color: isHovering ? AppTheme.primary.withOpacity(0.1) : Colors.red.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: isHovering ? AppTheme.primary : Colors.red.shade200)) : BoxDecoration(color: isHovering ? AppTheme.primary.withOpacity(0.1) : (name == null ? Colors.grey.shade50 : null)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Padding(
          padding: const EdgeInsets.only(left: 6),
          child: Text(label ?? '${index + 1}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red.shade700)),
        ),
        Expanded(child: Text(name ?? (isHovering ? '배정' : '-'), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.black))),
        const SizedBox(width: 8),
      ])));
      return useBox ? content : Expanded(child: content);
    });
  }
}
