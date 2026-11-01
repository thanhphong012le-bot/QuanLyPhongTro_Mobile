import 'dart:math' as math;
import 'package:flutter/painting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'meter_ocr_models.dart';

class WaterMeterOcrService {
  MeterOcrResult recognize(
    RecognizedText recognized,
    int previousReading, {
    required WaterReadMode mode,
    required bool manualRegion,
  }) {
    final m3Boxes = <Rect>[];
    Rect? allBounds;
    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        allBounds = allBounds == null ? line.boundingBox : allBounds!.expandToInclude(line.boundingBox);
        if (RegExp(r'm\s*(?:3|³)', caseSensitive: false).hasMatch(line.text)) {
          m3Boxes.add(line.boundingBox);
        }
      }
    }

    final runs = <DigitRun>[];

    bool rejectContext(String text) => RegExp(
      r'(serial|s\s*/\s*n|dn\s*\d|mm\b|\b20\d\d\b|x\s*0[.,]0|model|type)',
      caseSensitive: false,
    ).hasMatch(text);

    String normalize(String raw) {
      var s = raw.toUpperCase().replaceAll(RegExp(r'[\s|:_-]+'), '');
      s = s.replaceAll('O', '0').replaceAll('Q', '0').replaceAll('D', '0');
      s = s.replaceAll('I', '1').replaceAll('L', '1');
      s = s.replaceAll('S', '5').replaceAll('B', '8');
      return s.replaceAll(RegExp(r'[^0-9]'), '');
    }

    double score(Rect box, String context, int len) {
      var s = manualRegion ? 100.0 : 30.0;
      final ratio = box.height > 0 ? box.width / box.height : 0.0;
      if (ratio >= 2.0) s += 18;
      if (ratio >= 3.0) s += 12;
      if (len >= 5 && len <= 8) s += 18;
      var nearest = double.infinity;
      for (final m3 in m3Boxes) {
        final dx = box.center.dx - m3.center.dx;
        final dy = box.center.dy - m3.center.dy;
        nearest = math.min(nearest, math.sqrt(dx * dx + dy * dy));
      }
      if (nearest < 150) s += 22;
      if (nearest < 80) s += 12;
      if (allBounds != null && allBounds!.height > 0) {
        final y = (box.center.dy - allBounds!.top) / allBounds!.height;
        if (y < 0.55) s += 10;
      }
      if (RegExp(r'm\s*(?:3|³)', caseSensitive: false).hasMatch(context)) s += 30;
      return s;
    }

    void addRun(String raw, Rect box, String context) {
      if (rejectContext(context) && !RegExp(r'm\s*(?:3|³)', caseSensitive: false).hasMatch(context)) return;
      final digits = normalize(raw);
      if (digits.length < 4 || digits.length > 9) return;
      // Loại năm sản xuất đứng riêng.
      if (digits.length == 4 && RegExp(r'^20\d\d$').hasMatch(digits)) return;
      runs.add(DigitRun(digits: digits, bounds: box, score: score(box, context, digits.length)));
    }

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();
        final noUnit = text.replaceAll(RegExp(r'm\s*(?:3|³)', caseSensitive: false), '').trim();

        // Cả dòng chỉ được dùng nếu phần còn lại chủ yếu là ký tự giống chữ số.
        if (!RegExp(r'[A-CE-HJ-KM-NP-RT-ZÀ-ỹ]', caseSensitive: false).hasMatch(noUnit)) {
          addRun(noUnit, line.boundingBox, text);
        }

        final group = <TextElement>[];
        void flush() {
          if (group.isEmpty) return;
          final raw = group.map((e) => e.text).join('');
          final left = group.map((e) => e.boundingBox.left).reduce(math.min);
          final top = group.map((e) => e.boundingBox.top).reduce(math.min);
          final right = group.map((e) => e.boundingBox.right).reduce(math.max);
          final bottom = group.map((e) => e.boundingBox.bottom).reduce(math.max);
          addRun(raw, Rect.fromLTRB(left, top, right, bottom), text);
          group.clear();
        }
        for (final e in line.elements) {
          final t = e.text.trim().toUpperCase();
          if (RegExp(r'^[0-9OQDILSB|:_-]+$').hasMatch(t)) {
            group.add(e);
          } else {
            flush();
          }
        }
        flush();
      }
    }

    final bestByDigits = <String, DigitRun>{};
    for (final r in runs) {
      if (bestByDigits[r.digits] == null || bestByDigits[r.digits]!.score < r.score) {
        bestByDigits[r.digits] = r;
      }
    }
    final ranked = bestByDigits.values.toList()..sort((a, b) => b.score.compareTo(a.score));

    if (ranked.isEmpty) {
      return MeterOcrResult(
        rawText: recognized.text.trim(), candidates: const [], suggestedValue: null,
        choices: const [], waterChoices: const [], inferredMode: null,
        message: 'Không khóa được cửa sổ chỉ số nước. Hãy chụp gần hơn hoặc khoanh riêng dãy số ngang.',
      );
    }

    final source = ranked.first.digits;
    final choices = <WaterOcrChoice>[];
    void add(int count) {
      if (source.length < count) return;
      final value = int.tryParse(source.substring(0, count));
      if (value == null) return;
      choices.add(WaterOcrChoice(value: value, source: source, digitCount: count));
    }

    switch (mode) {
      case WaterReadMode.roundFourDigits:
        add(4);
        break;
      case WaterReadMode.blueFiveDigits:
        add(5);
        break;
      case WaterReadMode.automatic:
        // Với ảnh thực tế: nếu OCR thấy 6+ bánh (5 đen + bánh đỏ), ưu tiên 5 số đầu.
        // Vẫn giữ lựa chọn 4 số để hỗ trợ mẫu 4 số cũ.
        if (source.length >= 6) {
          add(5);
          add(4);
        } else if (source.length == 5) {
          add(5);
          add(4);
        } else {
          add(4);
        }
        break;
    }

    int? suggestion;
    if (choices.isNotEmpty) {
      final preferred = choices.first;
      if ((preferred.value >= previousReading || previousReading == 0) &&
          (manualRegion || ranked.first.score >= 78)) {
        suggestion = preferred.value;
      }
    }

    final message = 'Đã khóa vào một dãy số ngang duy nhất: "$source". '
        '${choices.isNotEmpty ? 'Ưu tiên ${choices.first.digitCount} số đầu = ${choices.first.value}; phần bánh đỏ phía sau không tính.' : ''} '
        'Không dùng năm, serial, kích thước hoặc số trên mặt kim.';

    return MeterOcrResult(
      rawText: recognized.text.trim(),
      candidates: choices.map((e) => e.value).toSet().toList(),
      suggestedValue: suggestion,
      choices: const [],
      waterChoices: choices,
      inferredMode: null,
      message: message,
    );
  }
}
