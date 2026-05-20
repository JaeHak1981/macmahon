import 'package:flutter_test/flutter_test.dart';
import 'package:macmahon/features/tournament/data/models/macmahon_models.dart';
import 'dart:math' as math;

void main() {
  group('Serialization Tests', () {
    test('MacmahonPlayer serialization', () {
      final player = MacmahonPlayerModel(
        id: '1',
        name: 'Test Player',
        initialMms: 10.0,
        currentMms: 11.0,
        isTopBar: true,
        opponents: {'2'},
        floatHistory: [1],
      );

      final json = player.toJson();
      final restored = MacmahonPlayerModel.fromJson(json);

      expect(restored.id, player.id);
      expect(restored.name, player.name);
      expect(restored.currentMms, player.currentMms);
      expect(restored.isTopBar, player.isTopBar);
      expect(restored.opponents.contains('2'), true);
      expect(restored.floatHistory.last, 1);
    });

    test('PairingResult serialization', () {
      final p1 = MacmahonPlayerModel(id: '1', name: 'P1', initialMms: 10.0, currentMms: 10.0);
      final p2 = MacmahonPlayerModel(id: '2', name: 'P2', initialMms: 10.0, currentMms: 10.0);
      final players = [p1, p2];

      final pair = MacmahonPairModel(black: p1, white: p2, cost: 0.0);
      final result = PairingResultModel(round: 1, pairs: [pair]);

      final json = result.toJson();
      final restored = PairingResultModel.fromJson(json, players);

      expect(restored.round, 1);
      expect(restored.pairs.length, 1);
      expect(restored.pairs.first.black.name, 'P1');
    });
    group('Round Recommendation Test', () {
      test('calculate recommended rounds', () {
        int getRec(int n) => n < 2 ? 0 : (math.log(n) / math.log(2)).ceil();
        
        expect(getRec(2), 1);
        expect(getRec(4), 2);
        expect(getRec(8), 3);
        expect(getRec(16), 4);
        expect(getRec(32), 5);
        expect(getRec(64), 6);
        expect(getRec(10), 4); // 8 < 10 <= 16
      });
    });
  });
}
