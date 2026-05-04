import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:screenshot/screenshot.dart';
import 'package:path/path.dart' as p;
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
    Map<String, int> playerRanks = const {},
    bool isLeague = false,
  }) async {
    try {
      final excel = Excel.createExcel();
      
      // 리그전일 경우 대진표(Matrix)를 첫 번째 시트로, 순위표를 두 번째 시트로 구성
      String primarySheetName = isLeague ? 'League_Matrix' : 'Standings';
      excel.rename('Sheet1', primarySheetName);
      final sheet = excel[primarySheetName];

      // 리그전일 때 순위표를 뒤로 보낼 경우 Standings 시트 미리 생성
      final standingsSheet = isLeague ? excel['Standings'] : sheet;
      final targetStandingsSheet = standingsSheet; // For clarity in data loop


      final roundsCount = history.length;

      final centerStyle = CellStyle(
        horizontalAlign: HorizontalAlign.Center,
        verticalAlign: VerticalAlign.Center,
      );

      // ── 헤더 추가 ──────────────────────────────────────────
      final headers = [
        'Rank',
        'No',
        'Name',
        if (isLeague) 'Group',
        // 라운드별 헤더 추가
        for (int r = 1; r <= roundsCount; r++) ...['${r}R Opponent', '${r}R Result'],
        if (isLeague) 'Wins' else 'MMS',
        if (!isLeague) 'SOS',
        'SODOS',
        if (!isLeague) 'Cumulative',
        if (!isLeague) 'Wins',
        'Losses',
        if (!isLeague) 'Initial MMS',
      ];
      
      for (var i = 0; i < headers.length; i++) {
        var cell = targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0));
        cell.value = TextCellValue(headers[i]);
      }

      // ── 데이터 추가 ────────────────────────────────────────
      for (var i = 0; i < players.length; i++) {
        final player = players[i];
        
        // 제공된 playerRanks 사용 (공동 순위 반영)
        final displayRank = playerRanks[player.id] ?? (i + 1);

        final rowIndex = i + 1;
        int colIndex = 0;

        // 기본 정보
        targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(displayRank);
        targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(playerNumbers[player.id] ?? 0);
        targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = TextCellValue(player.name);
        if (isLeague) {
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = TextCellValue(player.groupId ?? '-');
        }

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

          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = TextCellValue(opponentStr);
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = TextCellValue(resultStr);
        }

        // 집계 정보
        if (isLeague) {
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(player.wins);
        } else {
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.currentMms);
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.sos);
        }
        
        targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.sodos);
        
        if (!isLeague) {
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.cumulativeScore);
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(player.wins);
        }
        
        targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = IntCellValue(player.losses);
        
        if (!isLeague) {
          targetStandingsSheet.cell(CellIndex.indexByColumnRow(columnIndex: colIndex++, rowIndex: rowIndex)).value = DoubleCellValue(player.initialMms);
        }
      }

      // ── 리그 매트릭스 시트 구성 ──────────────────────────────────
      // 만약 리그전이면 이미 Sheet1(Primary)이 League_Matrix이므로 그곳에 작성, 아니면 별도 시트 생성
      final matrixSheet = isLeague ? sheet : excel['League_Matrices'];
      
      // 그룹별로 선수 분리
      final Map<String, List<MacmahonPlayer>> groups = {};
      for (var p in players) {
        final gid = p.groupId ?? 'Default';
        groups.putIfAbsent(gid, () => []).add(p);
      }

      int matrixRowOffset = 0;
      for (var entry in groups.entries) {
        final groupId = entry.key;
        final groupPlayers = entry.value;

        // 그룹 제목
        matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: matrixRowOffset)).value = 
            TextCellValue('Group: $groupId');
        matrixRowOffset += 1;

        // 헤더 (이름 + 가로축 선수명 + 순위)
        int headerCol = 0;
        matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: headerCol++, rowIndex: matrixRowOffset)).value = TextCellValue('이름');
        for (int i = 0; i < groupPlayers.length; i++) {
          matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: headerCol++, rowIndex: matrixRowOffset)).value = 
              TextCellValue(groupPlayers[i].name);
        }
        matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: headerCol, rowIndex: matrixRowOffset)).value = TextCellValue('순위');
        
        // 헤더 가운데 정렬
        for (int c = 0; c <= headerCol; c++) {
          matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: matrixRowOffset)).cellStyle = centerStyle;
        }
        matrixRowOffset += 1;

        // 데이터 (이름 + 결과 매트릭스 + 순위)
        for (int i = 0; i < groupPlayers.length; i++) {
          final p1 = groupPlayers[i];
          final rank = playerRanks[p1.id] ?? 0;
          int dataCol = 0;

          // 이름
          var nameCell = matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: dataCol++, rowIndex: matrixRowOffset));
          nameCell.value = TextCellValue(p1.name);
          nameCell.cellStyle = centerStyle;

          for (int j = 0; j < groupPlayers.length; j++) {
            var resCell = matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: dataCol++, rowIndex: matrixRowOffset));
            if (i == j) {
              resCell.value = TextCellValue('-');
              resCell.cellStyle = centerStyle;
              continue;
            }

            final p2 = groupPlayers[j];
            String resultText = '.';

            // 대전 기록 찾기
            for (var round in history) {
              final pair = round.pairs.cast<MacmahonPair?>().firstWhere(
                (p) => p != null && ((p.black.id == p1.id && p.white.id == p2.id) || (p.black.id == p2.id && p.white.id == p1.id)),
                orElse: () => null,
              );

              if (pair != null && pair.isResultEntered) {
                if (pair.winnerId == null) {
                  resultText = 'D';
                } else if (pair.winnerId == p1.id) {
                  resultText = 'O';
                } else {
                  resultText = 'X';
                }
                break;
              }
            }
            var cell = matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: dataCol - 1, rowIndex: matrixRowOffset));
            cell.value = TextCellValue(resultText);
            cell.cellStyle = centerStyle;
          }
          
          // 마지막 칸에 순위 배치
          var rankCell = matrixSheet.cell(CellIndex.indexByColumnRow(columnIndex: dataCol, rowIndex: matrixRowOffset));
          rankCell.value = IntCellValue(rank);
          rankCell.cellStyle = centerStyle;
          
          matrixRowOffset += 1;
        }
        matrixRowOffset += 2; // 그룹 간 간격
      }

      // ── 파일 저장 ──────────────────────────────────────────
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${tournamentName.replaceAll(' ', '_')}_results_$timestamp.xlsx';
      
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

  /// 현재 화면을 이미지(PNG)로 캡처하여 저장합니다.
  static Future<String?> exportToImage(
    ScreenshotController controller,
    String tournamentName,
  ) async {
    try {
      final imageBytes = await controller.capture();
      if (imageBytes == null) return null;

      final fileName = '${tournamentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '이미지 저장',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (outputFile == null) return null;
      if (!outputFile.toLowerCase().endsWith('.png')) {
        outputFile = '$outputFile.png';
      }

      final file = File(outputFile);
      await file.writeAsBytes(imageBytes);
      return outputFile;
    } catch (e) {
      print('Image export error: $e');
      return null;
    }
  }

  /// 이미지 바이트 데이터를 파일로 저장합니다.
  static Future<String?> saveImageBytes(
    Uint8List? imageBytes,
    String tournamentName,
  ) async {
    try {
      if (imageBytes == null) return null;

      final fileName = '${tournamentName.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.png';
      
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: '이미지 저장',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['png'],
      );

      if (outputFile == null) return null;
      if (!outputFile.toLowerCase().endsWith('.png')) {
        outputFile = '$outputFile.png';
      }

      final file = File(outputFile);
      await file.writeAsBytes(imageBytes);
      return outputFile;
    } catch (e) {
      print('Image save error: $e');
      return null;
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
