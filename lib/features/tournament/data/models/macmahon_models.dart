import '../../domain/entities/macmahon_entities.dart';
import '../../domain/entities/tournament_state.dart';
import '../../../../core/constants/tournament_enums.dart';

class MacmahonPlayerModel extends MacmahonPlayer {
  MacmahonPlayerModel({
    required super.id,
    required super.name,
    super.section,
    required super.initialMms,
    required super.currentMms,
    super.isTopBar,
    super.floatHistory,
    super.opponents,
    super.defeatedOpponents,
    super.wins,
    super.losses,
    super.draws,
    super.sos,
    super.sodos,
    super.cumulativeScore,
    super.groupId,
  });

  factory MacmahonPlayerModel.fromJson(Map<String, dynamic> json) {
    return MacmahonPlayerModel(
      id: json['id'] as String,
      name: json['name'] as String,
      section: json['section'] as String? ?? '일반부',
      initialMms: (json['initialMms'] as num).toDouble(),
      currentMms: (json['currentMms'] as num).toDouble(),
      isTopBar: json['isTopBar'] as bool? ?? false,
      floatHistory: List<int>.from(json['floatHistory'] as List),
      opponents: Set<String>.from(json['opponents'] as List),
      defeatedOpponents: json['defeatedOpponents'] != null
          ? Set<String>.from(json['defeatedOpponents'] as List)
          : {},
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
      sos: (json['sos'] as num? ?? 0.0).toDouble(),
      sodos: (json['sodos'] as num? ?? 0.0).toDouble(),
      cumulativeScore: (json['cumulativeScore'] as num? ?? 0.0).toDouble(),
      groupId: json['groupId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'section': section,
    'initialMms': initialMms,
    'currentMms': currentMms,
    'isTopBar': isTopBar,
    'floatHistory': floatHistory,
    'opponents': opponents.toList(),
    'defeatedOpponents': defeatedOpponents.toList(),
    'wins': wins,
    'losses': losses,
    'draws': draws,
    'sos': sos,
    'sodos': sodos,
    'cumulativeScore': cumulativeScore,
    'groupId': groupId,
  };

  factory MacmahonPlayerModel.fromEntity(MacmahonPlayer entity) {
    return MacmahonPlayerModel(
      id: entity.id,
      name: entity.name,
      section: entity.section,
      initialMms: entity.initialMms,
      currentMms: entity.currentMms,
      isTopBar: entity.isTopBar,
      floatHistory: entity.floatHistory,
      opponents: entity.opponents,
      defeatedOpponents: entity.defeatedOpponents,
      wins: entity.wins,
      losses: entity.losses,
      draws: entity.draws,
      sos: entity.sos,
      sodos: entity.sodos,
      cumulativeScore: entity.cumulativeScore,
      groupId: entity.groupId,
    );
  }
}

class MacmahonPairModel extends MacmahonPair {
  MacmahonPairModel({
    required super.black,
    required super.white,
    required super.cost,
    super.winnerId,
    super.isResultEntered,
  });

  factory MacmahonPairModel.fromJson(
    Map<String, dynamic> json,
    List<MacmahonPlayer> players,
  ) {
    return MacmahonPairModel(
      black: players.firstWhere((p) => p.id == json['blackId']),
      white: players.firstWhere((p) => p.id == json['whiteId']),
      cost: (json['cost'] as num).toDouble(),
      winnerId: json['winnerId'] as String?,
      isResultEntered: json['isResultEntered'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'blackId': black.id,
    'whiteId': white.id,
    'cost': cost,
    'winnerId': winnerId,
    'isResultEntered': isResultEntered,
  };

  static MacmahonPairModel fromEntity(MacmahonPair entity) {
    return MacmahonPairModel(
      black: entity.black,
      white: entity.white,
      cost: entity.cost,
      winnerId: entity.winnerId,
      isResultEntered: entity.isResultEntered,
    );
  }
}

class PairingResultModel extends PairingResult {
  PairingResultModel({
    required super.pairs,
    required super.round,
    super.byePlayers,
  });

  factory PairingResultModel.fromJson(
    Map<String, dynamic> json,
    List<MacmahonPlayer> players,
  ) {
    final byePlayerIds = json['byePlayerIds'] as List?;
    final byePlayerId = json['byePlayerId'];

    List<MacmahonPlayer> byes = [];
    if (byePlayerIds != null) {
      byes = byePlayerIds
          .map((id) => players.firstWhere((p) => p.id == id))
          .toList();
    } else if (byePlayerId != null) {
      byes = [players.firstWhere((p) => p.id == byePlayerId)];
    }

    return PairingResultModel(
      round: (json['round'] as num?)?.toInt() ?? 1,
      byePlayers: byes,
      pairs: (json['pairs'] as List? ?? [])
          .map((p) => MacmahonPairModel.fromJson(p, players))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'round': round,
    'byePlayerIds': byePlayers.map((p) => p.id).toList(),
    'pairs': pairs
        .map((p) => MacmahonPairModel.fromEntity(p).toJson())
        .toList(),
  };

  static PairingResultModel fromEntity(PairingResult entity) {
    return PairingResultModel(
      pairs: entity.pairs,
      round: entity.round,
      byePlayers: entity.byePlayers,
    );
  }
}

class SectionDataModel extends SectionData {
  SectionDataModel({
    super.history,
    super.currentPairing,
    super.currentRound,
    super.isFinished,
    super.format,
    super.leagueType,
    super.stage,
    super.qualifierCount,
    super.groupCount,
    super.qualifiersPerGroup,
    super.knockoutQualifiers,
    super.useHeadToHead,
    super.bracketStyle,
  });

  factory SectionDataModel.fromJson(
    Map<String, dynamic> json,
    List<MacmahonPlayer> allPlayers,
  ) {
    return SectionDataModel(
      history: (json['history'] as List? ?? [])
          .map((h) => PairingResultModel.fromJson(h, allPlayers))
          .toList(),
      currentPairing: json['currentPairing'] != null
          ? PairingResultModel.fromJson(json['currentPairing'], allPlayers)
          : null,
      currentRound: (json['currentRound'] as num?)?.toInt() ?? 1,
      isFinished: json['isFinished'] as bool? ?? false,
      format: TournamentFormat.values[(json['format'] as num?)?.toInt() ?? 0],
      leagueType: LeagueType.values[(json['leagueType'] as num?)?.toInt() ?? 0],
      stage: (json['stage'] as num?)?.toInt() ?? 1,
      qualifierCount: (json['qualifierCount'] as num?)?.toInt() ?? 4,
      groupCount: (json['groupCount'] as num?)?.toInt() ?? 1,
      qualifiersPerGroup: (json['qualifiersPerGroup'] as num?)?.toInt() ?? 1,
      knockoutQualifiers: List<String>.from(json['knockoutQualifiers'] ?? []),
      useHeadToHead: json['useHeadToHead'] ?? true,
      bracketStyle:
          BracketStyle.values[(json['bracketStyle'] as num?)?.toInt() ?? 0],
    );
  }

  Map<String, dynamic> toJson() => {
    'history': history
        .map((h) => PairingResultModel.fromEntity(h).toJson())
        .toList(),
    'currentPairing': currentPairing != null
        ? PairingResultModel.fromEntity(currentPairing!).toJson()
        : null,
    'currentRound': currentRound,
    'isFinished': isFinished,
    'format': format.index,
    'leagueType': leagueType.index,
    'stage': stage,
    'qualifierCount': qualifierCount,
    'groupCount': groupCount,
    'qualifiersPerGroup': qualifiersPerGroup,
    'knockoutQualifiers': knockoutQualifiers,
    'useHeadToHead': useHeadToHead,
    'bracketStyle': bracketStyle.index,
  };

  static SectionDataModel fromEntity(SectionData entity) {
    return SectionDataModel(
      history: entity.history,
      currentPairing: entity.currentPairing,
      currentRound: entity.currentRound,
      isFinished: entity.isFinished,
      format: entity.format,
      leagueType: entity.leagueType,
      stage: entity.stage,
      qualifierCount: entity.qualifierCount,
      groupCount: entity.groupCount,
      qualifiersPerGroup: entity.qualifiersPerGroup,
      knockoutQualifiers: entity.knockoutQualifiers,
      useHeadToHead: entity.useHeadToHead,
      bracketStyle: entity.bracketStyle,
    );
  }
}

class MacmahonStateModel extends MacmahonState {
  MacmahonStateModel({
    required super.id,
    super.players,
    super.sectionData,
    super.selectedSection,
    super.tournamentName,
    super.tournamentDate,
    super.tournamentLocation,
  });

  factory MacmahonStateModel.fromJson(Map<String, dynamic> json) {
    final players = (json['players'] as List)
        .map((p) => MacmahonPlayerModel.fromJson(p))
        .toList();
    final sectionData = (json['sectionData'] as Map<String, dynamic>? ?? {})
        .map(
          (k, v) => MapEntry(
            k,
            SectionDataModel.fromJson(v as Map<String, dynamic>, players),
          ),
        );
    return MacmahonStateModel(
      id: json['id'] as String,
      players: players,
      sectionData: sectionData,
      selectedSection: json['selectedSection'] as String? ?? '일반부',
      tournamentName: json['tournamentName'] as String? ?? '',
      tournamentDate: json['tournamentDate'] as String? ?? '',
      tournamentLocation: json['tournamentLocation'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'players': players
        .map((p) => MacmahonPlayerModel.fromEntity(p).toJson())
        .toList(),
    'sectionData': sectionData.map(
      (k, v) => MapEntry(k, SectionDataModel.fromEntity(v).toJson()),
    ),
    'selectedSection': selectedSection,
    'tournamentName': tournamentName,
    'tournamentDate': tournamentDate,
    'tournamentLocation': tournamentLocation,
  };

  static MacmahonStateModel fromEntity(MacmahonState entity) {
    return MacmahonStateModel(
      id: entity.id,
      players: entity.players,
      sectionData: entity.sectionData,
      selectedSection: entity.selectedSection,
      tournamentName: entity.tournamentName,
      tournamentDate: entity.tournamentDate,
      tournamentLocation: entity.tournamentLocation,
    );
  }
}
