import 'package:flutter/material.dart';

class MotionDuration {
  static const fast = Duration(milliseconds: 140);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
}

class MotionCurve {
  static const standard = Curves.fastOutSlowIn;
  static const emphasized = Curves.easeInOutCubic;
}

