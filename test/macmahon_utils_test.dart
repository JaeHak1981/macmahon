import 'package:flutter_test/flutter_test.dart';
import 'package:macmahon/utils/macmahon_utils.dart';

void main() {
  group('MacmahonUtils - calculateRecommendedRounds', () {
    test('작은 인원 추천 라운드 계산', () {
      expect(MacmahonUtils.calculateRecommendedRounds(2), 1);
      expect(MacmahonUtils.calculateRecommendedRounds(3), 2);
      expect(MacmahonUtils.calculateRecommendedRounds(4), 3); // 2 -> 보정됨
      expect(MacmahonUtils.calculateRecommendedRounds(8), 3);
    });

    test('대규모 인원 추천 라운드 계산', () {
      expect(MacmahonUtils.calculateRecommendedRounds(16), 4);
      expect(MacmahonUtils.calculateRecommendedRounds(32), 5);
      expect(MacmahonUtils.calculateRecommendedRounds(64), 6);
      expect(MacmahonUtils.calculateRecommendedRounds(128), 7);
    });

    test('Top Bar 기준 추천 라운드 계산', () {
      // 전체 인원은 100명이지만, 우승 가능권(Top Bar)이 8명뿐인 경우
      expect(MacmahonUtils.calculateRecommendedRounds(100, topBarCount: 8), 3);
      
      // Top Bar가 16명인 경우
      expect(MacmahonUtils.calculateRecommendedRounds(100, topBarCount: 16), 4);
    });

    test('예외 케이스 처리', () {
      expect(MacmahonUtils.calculateRecommendedRounds(0), 0);
      expect(MacmahonUtils.calculateRecommendedRounds(1), 0);
    });
  });
}
