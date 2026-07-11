import 'package:flutter/material.dart';

class SurgeMotion {
  const SurgeMotion._();

  static const press = Duration(milliseconds: 110);
  static const state = Duration(milliseconds: 160);
  static const reveal = Duration(milliseconds: 180);
  static const container = Duration(milliseconds: 220);
  static const pageEnter = Duration(milliseconds: 280);
  static const pageExit = Duration(milliseconds: 210);
  static const sheetEnter = Duration(milliseconds: 300);
  static const sheetExit = Duration(milliseconds: 200);

  static const enterCurve = Curves.easeOutCubic;
  static const exitCurve = Curves.easeInCubic;
  static const stateCurve = Curves.easeOutCubic;

  static const double pressedScale = 0.98;
  static const double compactPressedScale = 0.985;
  static const double pressedOverlayOpacity = 0.07;
  static const double revealOffset = 10;
  static const double modalBarrierOpacity = 0.52;
}
