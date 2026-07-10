import 'package:fl_clash/widgets/surge/surge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SurgeBottomNavLayout', () {
    test('has expected horizontal inset', () {
      expect(SurgeBottomNavLayout.horizontalInset, 21);
    });

    test('lifts no-gesture navigation to the gesture baseline', () {
      expect(SurgeBottomNavLayout.navBottomInsetFor(0), 16);
      expect(SurgeBottomNavLayout.navBottomInsetFor(24), 29);
    });

    test('keeps main page content close to the bottom nav top', () {
      expect(SurgeBottomNavLayout.mainPageBottomPaddingFor(0), 16 + 56 + 9);
      expect(SurgeBottomNavLayout.mainPageBottomPaddingFor(24), 29 + 56 + 9);
    });
  });
}
