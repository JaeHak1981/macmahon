import '../../../../core/constants/tournament_enums.dart';
import 'macmahon_entities.dart';
import '../../../../core/utils/macmahon_utils.dart';

class SectionData {
  final List<PairingResult> history;
  final PairingResult? currentPairing;
  final int currentRound;
  final bool isFinished;
  final TournamentFormat format;
  final LeagueType leagueType;
  final int stage; // 1: 예선, 2: 본선
  final int qualifierCount;
  final int groupCount;
  final int qualifiersPerGroup;
  final List<String> knockoutQualifiers;
  final bool useHeadToHead;
  final BracketStyle bracketStyle;

  const SectionData({
    this.history = const [],
    this.currentPairing,
    this.currentRound = 1,
    this.isFinished = false,
    this.format = TournamentFormat.undecided,
    this.leagueType = LeagueType.normal,
    this.stage = 1,
    this.qualifierCount = 4,
    this.groupCount = 1,
    this.qualifiersPerGroup = 1,
    this.knockoutQualifiers = const [],
    this.useHeadToHead = true,
    this.bracketStyle = BracketStyle.compact,
  });

  SectionData copyWith({
    List<PairingResult>? history,
    PairingResult? currentPairing,
    bool clearCurrentPairing = false,
    int? currentRound,
    bool? isFinished,
    TournamentFormat? format,
    LeagueType? leagueType,
    int? stage,
    int? qualifierCount,
    int? groupCount,
    int? qualifiersPerGroup,
    List<String>? knockoutQualifiers,
    bool? useHeadToHead,
    BracketStyle? bracketStyle,
  }) {
    return SectionData(
      history: history ?? this.history,
      currentPairing: clearCurrentPairing
          ? null
          : (currentPairing ?? this.currentPairing),
      currentRound: currentRound ?? this.currentRound,
      isFinished: isFinished ?? this.isFinished,
      format: format ?? this.format,
      leagueType: leagueType ?? this.leagueType,
      stage: stage ?? this.stage,
      qualifierCount: qualifierCount ?? this.qualifierCount,
      groupCount: groupCount ?? this.groupCount,
      qualifiersPerGroup: qualifiersPerGroup ?? this.qualifiersPerGroup,
      knockoutQualifiers: knockoutQualifiers ?? this.knockoutQualifiers,
      useHeadToHead: useHeadToHead ?? this.useHeadToHead,
      bracketStyle: bracketStyle ?? this.bracketStyle,
    );
  }
}

class MacmahonState {
  final String id;
  final List<MacmahonPlayer> players;
  final Map<String, SectionData> sectionData;
  final String selectedSection;
  final String tournamentName;
  final String tournamentDate;
  final String tournamentLocation;
  final bool isLoading;
  final String? errorMessage;

  const MacmahonState({
    required this.id,
    this.players = const [],
    this.sectionData = const {'일반부': const SectionData()},
    this.selectedSection = '일반부',
    this.tournamentName = '',
    this.tournamentDate = '',
    this.tournamentLocation = '',
    this.isLoading = false,
    this.errorMessage,
  });

  SectionData get currentSectionData =>
      sectionData[selectedSection] ?? const SectionData();
  List<MacmahonPlayer> get currentSectionPlayers =>
      players.where((p) => p.section == selectedSection).toList();
  TournamentFormat get format => currentSectionData.format;
  int get currentRound => currentSectionData.currentRound;
  List<PairingResult> get history => currentSectionData.history;
  PairingResult? get currentPairing => currentSectionData.currentPairing;
  List<MacmahonPair> get currentPairs => currentPairing?.pairs ?? [];
  MacmahonPlayer? get byePlayer => currentPairing?.byePlayer;
  int get stage => currentSectionData.stage;
  List<String> get sections => sectionData.keys.toList();
  bool get isFinished => currentSectionData.isFinished;

  int get recommendedRounds {
    return MacmahonUtils.calculateRecommendedRounds(
      currentSectionPlayers.length,
    );
  }

  List<String> get availableGroups {
    return List.generate(
      currentSectionData.groupCount,
      (i) => String.fromCharCode(65 + i),
    );
  }

  MacmahonState copyWith({
    String? id,
    List<MacmahonPlayer>? players,
    Map<String, SectionData>? sectionData,
    String? selectedSection,
    String? tournamentName,
    String? tournamentDate,
    String? tournamentLocation,
    bool? isLoading,
    String? errorMessage,
  }) {
    return MacmahonState(
      id: id ?? this.id,
      players: players ?? this.players,
      sectionData: sectionData ?? this.sectionData,
      selectedSection: selectedSection ?? this.selectedSection,
      tournamentName: tournamentName ?? this.tournamentName,
      tournamentDate: tournamentDate ?? this.tournamentDate,
      tournamentLocation: tournamentLocation ?? this.tournamentLocation,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
