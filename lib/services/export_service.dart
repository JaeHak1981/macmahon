import 'dart:io';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import '../models/macmahon_player.dart';
import '../models/macmahon_pair.dart';

/// 맥마흔 토너먼트 결과 엑셀 내보내기 서비스
class ExportService {
  /// 순위표 데이터를 엑셀 파일로 내보냅니다.
  /// 
  /// [players]: 정렬된 선수 목록
  /// [tournamentName]: 대회 명칭 (파일명에 사용)
  /// [history]: 모든 라운드 대진 기록
  /// [playerNumbers]: 선수별 고유 번호 맵
  static Future<String?> exportToExcel(
    List<MacmahonPlayer> players,
    String tournamentName, {
    List<PairingResult> history = const [],
    Map<String, int> playerNumbers = const {},
  }) async {
    try {
      final excel = Excel.createExcel();
      final sheetName = 'Standings';
      excel.rename('Sheet1', sheetName);
      final sheet = excel[sheetName];

      final roundsCount = history.length;

      // ── 헤더 추가 ──────────────────────────────────────────
      final headers = [
        'Rank',
        'No',
        'Name',
        // 라운드별 헤더 추가
        for (int r = 1; r <= roundsCount; r++) ...['${r}R Opponent', '${r}R Result'],
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
      }

      // ── 데이터 추가 ────────────────────────────────────────
      for (var i = 0; i < players.length; i++) {
        final player = players[i];
        
        // 순위 계산
        int displayRank = 1;
        if (i > 0) {
          final prev = players[i - 1];
          bool isSame = player.currentMms == prev.currentMms &&
              player.cumulativeScore == prev.cumulativeScore &&
              player.sos == prev.sos &&
              player.sodos == prev.sodos &&
              !player.defeatedOpponents.contains(prev.id) &&
              !prev.defeatedOpponents.contains(player.id) &&
              player.initialMms == prev.initialMms &&
              player.wins == prev.wins;

          if (isSame) {
            for (int j = i; j > 0; j--) {
              final p1 = players[j];
              final p2 = players[j - 1];
              bool same = p1.currentMms == p2.currentMms &&
                  p1.cumulativeScore == p2.cumulativeScore &&
                  p1.sos == p2.sos &&
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
        int colIndex = 0;

        // 기본 정보
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(displayRank);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(playerNumbers[player.id] ?? 0);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = TextCellValue(player.name);

        // 라운드별 데이터
        for (int r = 0; r < roundsCount; r++) {
          final roundResult = history[r];
          String opponentStr = '-';
          String resultStr = '-';

          MacmahonPair? pair;
          try {
            pair = roundResult.pairs.firstWhere((p) => p.black.id == player.id || p.white.id == player.id);
          } catch (_) {
            pair = null;
          }

          if (pair != null) {
            final opponentId = (pair.black.id == player.id) ? pair.white.id : pair.black.id;
            opponentStr = (playerNumbers[opponentId] ?? 0).toString();
            
            if (pair.isResultEntered) {
              if (pair.winnerId == null) {
                resultStr = 'Draw';
              } else if (pair.winnerId == player.id) {
                resultStr = 'Win';
              } else {
                resultStr = 'Loss';
              }
            }
          } else if (roundResult.byePlayer?.id == player.id) {
            opponentStr = 'BYE';
            resultStr = 'Win';
          }

          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = TextCellValue(opponentStr);
          sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = TextCellValue(resultStr);
        }

        // 집계 정보
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.currentMms);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.sos);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.sodos);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.cumulativeScore);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(player.wins);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(player.losses);
        sheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.initialMms);
      }

      // ── 파일 저장 ──────────────────────────────────────────
      final fileName = '${tournamentName.replaceAll(' ', '_')}_results.xlsx';
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '엑셀 결과 저장',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile == null) return null;

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

  /// 엑셀 파일로부터 선수 명단을 가져옵니다.
  static Future<List<MacmahonPlayer>> importPlayersFromExcel() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result == null || result.files.isEmpty) return [];

      final bytes = result.files.first.bytes;
      if (bytes == null) {
        final file = File(result.files.first.path!);
        final excel = Excel.decodeBytes(file.readAsBytesSync());
        return _parseExcelToPlayers(excel);
      } else {
        final excel = Excel.decodeBytes(bytes);
        return _parseExcelToPlayers(excel);
      }
    } catch (e) {
      rethrow;
    }
  }

  static List<MacmahonPlayer> _parseExcelToPlayers(Excel excel) {
    final List<MacmahonPlayer> players = [];
    final sheet = excel.tables[excel.tables.keys.first];

    if (sheet == null) return [];

    // 데이터 행 시작 (첫 번째 행은 헤더로 간주하고 건너뜀)
    for (int i = 1; i < sheet.maxRows; i++) {
      final row = sheet.rows[i];
      if (row.isEmpty) continue;

      // 이름 (필수)
      final nameCell = row.isNotEmpty ? row[0] : null;
      if (nameCell == null || nameCell.value == null) continue;
      final nameStr = nameCell.value.toString().trim();
      if (nameStr.isEmpty) continue;

      // MMS (선택)
      double mms = 0.0;
      if (row.length > 1 && row[1] != null && row[1]!.value != null) {
        mms = double.tryParse(row[1]!.value.toString()) ?? 0.0;
      }

      // Top Bar 여부 (선택)
      bool isTopBar = false;
      if (row.length > 2 && row[2] != null && row[2]!.value != null) {
        final topStr = row[2]!.value.toString().toUpperCase();
        if (topStr == 'O' || topStr == '1' || topStr == 'Y' || topStr == 'TRUE') {
          isTopBar = true;
        }
      }

      final id = '${DateTime.now().millisecondsSinceEpoch}_${players.length}_$nameStr';
      players.add(MacmahonPlayer(
        id: id,
        name: nameStr,
        initialMms: mms,
        currentMms: mms,
        isTopBar: isTopBar,
      ));
    }
    return players;
  }
}
