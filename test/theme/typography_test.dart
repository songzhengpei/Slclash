import 'package:fl_clash/theme/typography/type_scale.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Typography font contract', () {
    test('rootAppBarTitle is 20sp / w600', () {
      expect(SlclashTypeScale.rootAppBarTitle.fontSize, 20);
      expect(SlclashTypeScale.rootAppBarTitle.fontWeight, FontWeight.w600);
    });

    test('appBarTitle is 19sp / w500', () {
      expect(SlclashTypeScale.appBarTitle.fontSize, 19);
      expect(SlclashTypeScale.appBarTitle.fontWeight, FontWeight.w500);
    });

    test('sheetTitle is 18sp / w500', () {
      expect(SlclashTypeScale.sheetTitle.fontSize, 18);
      expect(SlclashTypeScale.sheetTitle.fontWeight, FontWeight.w500);
    });
  });
}
