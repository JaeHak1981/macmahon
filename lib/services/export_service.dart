import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/macmahon_player.dart';

/// 맥마흔 토너먼트 결과 엑셀 내보내기 서비스
class ExportService {
  /// 순위표 데이터를 엑셀 파일로 내보냅니다.
  /// 
  /// [players]: 정렬된 선수 목록
  /// [tournamentName]: 대회 명칭 (파일명에 사용)
  static Future<String?> exportToExcel(
    List<MacmahonPlayer> players,
    String tournamentName,
  ) async {
    try {
      final excel = Excel.createExcel();
      final sheetName = 'Standings';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      // ── 헤더 추가 ──────────────────────────────────────────
      final headers = [
        'Rank',
        'Name',
        'MMS',
        'SOS',
        'SODOS',
        'Cumulative',
        'Wins',
        'Losses',
        'Initial MMS',
      ];
      
      for (var i = 0; i < headers.length; i++) {
        var cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
        // 간단한 스타일 적용 (볼드 등은 패키지 버전에 따라 다를 수 있음)
      }

      // ── 데이터 추가 ────────────────────────────────────────
      // 공동 순위 계산을 포함하여 데이터 작성
      for (var i = 0; i < players.length; i++) {
        final player = players[i];
        
        // 순위 계산 로직 (StandingsScreen과 동일하게 적용)
        int displayRank = 1;
        if (i > 0) {
          final prev = players[i - 1];
          bool isSame = player.currentMms == prev.currentMms &&
              player.sos == prev.sos &&
              player.cumulativeScore == prev.cumulativeScore && // 누진점수 추가
              player.sodos == prev.sodos &&
              !player.defeatedOpponents.contains(prev.id) &&
              !prev.defeatedOpponents.contains(player.id) &&
              player.initialMms == prev.initialMms &&
              player.wins == prev.wins;

          if (isSame) {
            // 앞 선수와 동일 순위라면 i 위치를 직접 찾지 않고 이전 순위 재사용이 필요하나, 
            // 여기서는 단순화하여 i=0부터 다시 체크하거나 캐싱 가능.
            // 일단 정확한 로직을 위해 다시 루프
            for (int j = i; j > 0; j--) {
              final p1 = players[j];
              final p2 = players[j - 1];
              bool same = p1.currentMms == p2.currentMms &&
                  p1.sos == p2.sos &&
                  p1.cumulativeScore == p2.cumulativeScore &&
                  p1.sodos == p2.sodos &&
                  !p1.defeatedOpponents.contains(p2.id) &&
                  !p2.defeatedOpponents.contains(p1.id) &&
                  p1.initialMms == p2.initialMms &&
                  p1.wins == p2.wins;
              if (!same) {
                displayRank = j + 1;
                break;
              }
            }
          } else {
            displayRank = i + 1;
          }
        }

        final rowIndex = i + 1;
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex)).value = IntCellValue(displayRank);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex)).value = TextCellValue(player.name);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex)).value = DoubleCellValue(player.currentMms);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex)).value = DoubleCellValue(player.sos);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: rowIndex)).value = DoubleCellValue(player.sodos);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: rowIndex)).value = DoubleCellValue(player.cumulativeScore);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 6, rowIndex: rowIndex)).value = IntCellValue(player.wins);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 7, rowIndex: rowIndex)).value = IntCellValue(player.losses);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: 8, rowIndex: rowIndex)).value = DoubleCellValue(player.initialMms);
      }

      // ── 파일 저장 ──────────────────────────────────────────
      final fileName = '${tournamentName.replaceAll(' ', '_')}_results.xlsx';
      
      // 데스크탑/모바일 환경에 따라 다르게 처리할 수 있으나, 
      // 사용자에게 위치를 묻는 file_picker 방식이 가장 범용적임
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '엑셀 결과 저장',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile == null) return null; // 취소됨

      // 확장자 자동 추가 처리 (일부 플랫폼 대응)
      if (!outputFile.endsWith('.xlsx')) {
        outputFile = '$outputFile.xlsx';
      }

      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(outputFile)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);
        return outputFile;
      }
      
      return null;
    } catch (e) {
      rethrow;
    }
  }
}
