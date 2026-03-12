import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/macmahon_provider.dart';

class StorageService {
  static const String _keyHistory = 'macmahon_tournaments_history';

  /// 모든 저장된 토너먼트 데이터를 가져옵니다.
  Future<List<MacmahonState>> getTournaments() async {
    final prefs = await SharedPreferences.getInstance();
    final String? historyJson = prefs.getString(_keyHistory);
    
    if (historyJson == null) return [];
    
    try {
      final List<dynamic> historyList = jsonDecode(historyJson);
      return historyList
          .map((data) => MacmahonState.fromJson(data as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Error loading history: $e');
      return [];
    }
  }

  /// 토너먼트 데이터를 저장합니다. 
  /// 이미 존재하는 (같은 이름/날짜) 토너먼트라면 업데이트하고, 아니면 추가합니다.
  Future<void> saveTournament(MacmahonState state) async {
    final prefs = await SharedPreferences.getInstance();
    final tournaments = await getTournaments();
    
    // 동일한 토너먼트인지는 이름, 날짜, 장소로 판단 (단순화)
    final existingIndex = tournaments.indexWhere((t) =>
        t.tournamentName == state.tournamentName &&
        t.tournamentDate == state.tournamentDate);
    
    if (existingIndex >= 0) {
      tournaments[existingIndex] = state;
    } else {
      tournaments.add(state);
    }
    
    // 최근 기록이 위로 오게 저장하려면? 여기서는 단순히 리스트로 저장.
    final String jsonString = jsonEncode(tournaments.map((t) => t.toJson()).toList());
    await prefs.setString(_keyHistory, jsonString);
  }

  /// 특정 토너먼트 삭제
  Future<void> deleteTournament(String name, String date) async {
    final prefs = await SharedPreferences.getInstance();
    final tournaments = await getTournaments();
    
    tournaments.removeWhere((t) => t.tournamentName == name && t.tournamentDate == date);
    
    final String jsonString = jsonEncode(tournaments.map((t) => t.toJson()).toList());
    await prefs.setString(_keyHistory, jsonString);
  }
}
