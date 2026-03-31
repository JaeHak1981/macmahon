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
  /// 식별자(id)가 동일한 토너먼트라면 업데이트하고, 없으면 새로 추가합니다.
  Future<void> saveTournament(MacmahonState state) async {
    final prefs = await SharedPreferences.getInstance();
    final tournaments = await getTournaments();
    
    // id를 기준으로 검색하여 정보 수정 시에도 동일 대회로 인식하게 함
    final existingIndex = tournaments.indexWhere((t) => t.id == state.id);
    
    if (existingIndex >= 0) {
      tournaments[existingIndex] = state;
    } else {
      tournaments.add(state);
    }
    
    final String jsonString = jsonEncode(tournaments.map((t) => t.toJson()).toList());
    await prefs.setString(_keyHistory, jsonString);
  }

  /// 특정 토너먼트 삭제
  Future<void> deleteTournament(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final tournaments = await getTournaments();
    
    tournaments.removeWhere((t) => t.id == id);
    
    final String jsonString = jsonEncode(tournaments.map((t) => t.toJson()).toList());
    await prefs.setString(_keyHistory, jsonString);
  }
}
