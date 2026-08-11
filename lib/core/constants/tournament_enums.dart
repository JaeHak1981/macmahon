enum TournamentFormat {
  undecided, // 미정
  macmahon, // 맥마흔 (스위스 리그 변형)
  league, // 풀리그 (Round-robin)
  knockout, // 토너먼트 (Single Elimination)
  doubleElimination, // 더블 일리미네이션
  leagueAndKnockout, // 풀리그 + 토너먼트
}

enum LeagueType {
  normal, // 일반 풀리그
  doubleElimination, // 더블 일리미네이션
}

enum BracketStyle {
  compact, // 기존: 한 칸에 두 명 표시 (세로형)
  classic, // 신규: 가로형 트리 (선수 개별 박스)
  classicVertical, // 신규: 세로형 트리 (선수 개별 박스)
}
