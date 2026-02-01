// ignore_for_file: unnecessary_this

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:pinyin/pinyin.dart';

extension StringHMMSS on Duration {
  /// Returns a string with hours, minutes, seconds,
  /// in the following format: H:MM:SS
  String toStringHMMSS() {
    return toString().split(".").first;
  }
}

/// 把 dec 表示成两位 hex
String _toHexString(int dec) {
  assert(dec >= 0 && dec <= 0xff);

  var hex = dec.toRadixString(16);
  if (hex.length == 1) hex = "0$hex";
  return hex;
}

extension RGBHexString on Color {
  String toRGBHexString() {
    final redHex = _toHexString(red);
    final greenHex = _toHexString(green);
    final blueHex = _toHexString(blue);

    return "#$redHex$greenHex$blueHex";
  }
}

/// [rgbHexStr] 必须是 #RRGGBB
Color? fromRGBHexString(String rgbHexStr) {
  if (rgbHexStr.startsWith("#") && rgbHexStr.length == 7) {
    return Color(0xff000000 + int.parse(rgbHexStr.substring(1), radix: 16));
  }

  return null;
}

Map<String, String> _pinyinCache = {};

extension PinyinCompare on String {
  /// convert str to pinyin, cache it when it hasn't been converted;
  String _getPinyin() {
    final cachedPinyin = _pinyinCache[this];
    if (cachedPinyin != null) return cachedPinyin;

    final splited = this.split("");
    final pinyinBuilder = StringBuffer();

    for (var c in splited) {
      if (ChineseHelper.isChinese(c)) {
        final pinyin = PinyinHelper.convertToPinyinArray(
          c,
          PinyinFormat.WITHOUT_TONE,
        ).firstOrNull;

        pinyinBuilder.write(pinyin ?? c);
      } else {
        pinyinBuilder.write(c);
      }
    }

    final pinyin = pinyinBuilder.toString();

    _pinyinCache[this] = pinyin;

    return pinyin;
  }

  /// Compares this string to [other] with pinyin first, else use the ordering of the code units.
  ///
  /// Returns a negative value if `this` is ordered before `other`,
  /// a positive value if `this` is ordered after `other`,
  /// or zero if `this` and `other` are equivalent.
  int localeCompareTo(String other) {
    final thisContainsChinese = ChineseHelper.containsChinese(this);
    final otherContainsChinese = ChineseHelper.containsChinese(other);

    final thisCmpStr = thisContainsChinese ? this._getPinyin() : this;
    final otherCmpStr = otherContainsChinese ? other._getPinyin() : other;

    return thisCmpStr.compareTo(otherCmpStr);
  }

  int naturalCompareTo(String other) {
    final a = this;
    final b = other;
    final aTokens = _tokenizeForNaturalCompare(a);
    final bTokens = _tokenizeForNaturalCompare(b);

    final len =
        aTokens.length < bTokens.length ? aTokens.length : bTokens.length;
    for (int i = 0; i < len; i++) {
      final ta = aTokens[i];
      final tb = bTokens[i];
      if (ta.isNumber && tb.isNumber) {
        final cmp = ta.number!.compareTo(tb.number!);
        if (cmp != 0) return cmp;
        final lenCmp = ta.text.length.compareTo(tb.text.length);
        if (lenCmp != 0) return lenCmp;
        continue;
      }
      final cmp = ta.text.toLowerCase().localeCompareTo(tb.text.toLowerCase());
      if (cmp != 0) return cmp;
    }
    return aTokens.length.compareTo(bTokens.length);
  }

  String getIndexKey() {
    final s = trimLeft();
    if (s.isEmpty) return "#";
    String first = s.substring(0, 1);
    if (ChineseHelper.isChinese(first)) {
      first = PinyinHelper.convertToPinyinArray(
            first,
            PinyinFormat.WITHOUT_TONE,
          ).firstOrNull ??
          first;
    }
    final code = first.codeUnitAt(0);
    if (code >= 0x41 && code <= 0x5A) return first;
    if (code >= 0x61 && code <= 0x7A) return first.toUpperCase();
    if (code >= 0x30 && code <= 0x39) return "#";
    return "#";
  }
}

class _NaturalToken {
  final bool isNumber;
  final String text;
  final BigInt? number;
  const _NaturalToken._(this.isNumber, this.text, this.number);
  factory _NaturalToken.text(String text) => _NaturalToken._(false, text, null);
  factory _NaturalToken.number(String text) =>
      _NaturalToken._(true, text, BigInt.tryParse(text) ?? BigInt.zero);
}

List<_NaturalToken> _tokenizeForNaturalCompare(String input) {
  if (input.isEmpty) return const [];
  final tokens = <_NaturalToken>[];
  final buffer = StringBuffer();
  bool? inNumber;

  for (int i = 0; i < input.length; i++) {
    final c = input.codeUnitAt(i);
    final isDigit = c >= 0x30 && c <= 0x39;
    if (inNumber == null) {
      inNumber = isDigit;
      buffer.writeCharCode(c);
      continue;
    }

    if (isDigit == inNumber) {
      buffer.writeCharCode(c);
      continue;
    }

    final text = buffer.toString();
    tokens
        .add(inNumber ? _NaturalToken.number(text) : _NaturalToken.text(text));
    buffer.clear();
    inNumber = isDigit;
    buffer.writeCharCode(c);
  }

  final text = buffer.toString();
  tokens.add(
      inNumber == true ? _NaturalToken.number(text) : _NaturalToken.text(text));
  return tokens;
}

final GlobalKey<NavigatorState> ROUTER_KEY = GlobalKey();

final SCAFFOLD_MESSAGER = GlobalKey<ScaffoldMessengerState>();
void showTextOnSnackBar(String text) {
  SCAFFOLD_MESSAGER.currentState?.showSnackBar(SnackBar(content: Text(text)));
}

final LOGGER_MEMORY = MemoryOutput(
  secondOutput: kDebugMode ? ConsoleOutput() : null,
);
final LOGGER = Logger(
  filter: ProductionFilter(),
  printer: SimplePrinter(colors: false),
  output: LOGGER_MEMORY,
  level: Level.all,
);
