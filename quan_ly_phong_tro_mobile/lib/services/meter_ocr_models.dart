import 'package:flutter/painting.dart';

enum MeterReadMode { automatic, mechanical, electronic }

/// Hai mẫu đồng hồ nước cố định đang sử dụng.
/// roundFourDigits: đồng hồ tròn - lấy 4 số chính từ trái sang phải, bỏ phần đỏ.
/// blueFiveDigits: đồng hồ xanh - lấy 5 số chính từ trái sang phải, bỏ phần đỏ.
enum WaterReadMode { automatic, roundFourDigits, blueFiveDigits }

class MeterOcrChoice {
  const MeterOcrChoice({required this.value, required this.source, required this.mode, required this.score, this.hasDecimal=false, this.wheelLayoutHint=false});
  final int value; final String source; final MeterReadMode mode; final double score; final bool hasDecimal; final bool wheelLayoutHint;

  String get typeLabel => switch (mode) {
    MeterReadMode.mechanical => 'Đồng hồ điện cơ',
    MeterReadMode.electronic => 'Đồng hồ điện tử',
    MeterReadMode.automatic => 'Tự động',
  };
}
class WaterOcrChoice {
  const WaterOcrChoice({required this.value, required this.source, required this.digitCount});
  final int value; final String source; final int digitCount;

  String get typeLabel => digitCount == 4
      ? 'Đồng hồ nước tròn - 4 số'
      : 'Đồng hồ nước xanh - 5 số';
}
class MeterOcrResult {
  const MeterOcrResult({required this.rawText, required this.candidates, required this.suggestedValue, required this.choices, required this.waterChoices, required this.inferredMode, required this.message});
  final String rawText; final List<int> candidates; final int? suggestedValue; final List<MeterOcrChoice> choices; final List<WaterOcrChoice> waterChoices; final MeterReadMode? inferredMode; final String message;
}
class ReadLine { const ReadLine(this.text,this.bounds,{this.separateWheel=false}); final String text; final Rect bounds; final bool separateWheel; }
class DigitRun { const DigitRun({required this.digits,required this.bounds,required this.score}); final String digits; final Rect bounds; final double score; }
