import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/tournament_state.dart';
import '../../domain/repositories/i_tournament_repository.dart';
import '../models/macmahon_models.dart';

class TournamentRepositoryImpl implements ITournamentRepository {
  static const String _keyHistory = 'macmahon_tournaments_history';

  @override
  Future<List<MacmahonState>> getTournaments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_keyHistory);

    if (historyJson == null) return [];

    try {
      final List<dynamic> historyList = jsonDecode(historyJson);
      return historyList
          .map<MacmahonState>(
            (data) => MacmahonStateModel.fromJson(data as Map<String, dynamic>),
          )
          .toList();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  @override
  Future<void> saveTournament(MacmahonState state) async {
    final prefs = await SharedPreferences.getInstance();
    final tournaments = await getTournaments();

    final existingIndex = tournaments.indexWhere((t) => t.id == state.id);

    if (existingIndex >= 0) {
      tournaments[existingIndex] = state;
    } else {
      tournaments.add(state);
    }

    final String jsonString = jsonEncode(
      tournaments
          .map((t) => MacmahonStateModel.fromEntity(t).toJson())
          .toList(),
    );
    await prefs.setString(_keyHistory, jsonString);
  }

  @override
  Future<void> deleteTournament(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final tournaments = await getTournaments();

    tournaments.removeWhere((t) => t.id == id);

    final String jsonString = jsonEncode(
      tournaments
          .map((t) => MacmahonStateModel.fromEntity(t).toJson())
          .toList(),
    );
    await prefs.setString(_keyHistory, jsonString);
  }
}
