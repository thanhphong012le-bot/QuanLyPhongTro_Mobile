import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'meter_ocr_models.dart';

class ElectricMeterOcrService {
  MeterOcrResult recognize(
    RecognizedText recognized, {
    required int previousReading,
    required MeterReadMode mode,
    required bool manualRegion,
  }) {
    final lines = <ReadLine>[];

    Rect? allBounds;

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        allBounds = allBounds == null
            ? line.boundingBox
            : allBounds!.expandToInclude(line.boundingBox);

        lines.add(
          ReadLine(
            line.text,
            line.boundingBox,
          ),
        );
      }
    }

    final kwhBoxes = lines
        .where(
          (l) => RegExp(
            r'k\s*w\s*h',
            caseSensitive: false,
          ).hasMatch(l.text),
        )
        .map((l) => l.bounds)
        .toList();

    final proposals = <MeterOcrChoice>[];

    // ---------------------------------------------------------
    // Loại các dòng rõ ràng là thông số kỹ thuật / serial.
    // ---------------------------------------------------------

    bool technical(String text) {
      return RegExp(
        r'(serial|s\s*/\s*n|'
        r'\b220\s*v|'
        r'\b\d+\s*(?:hz|volt|amp)\b|'
        r'\bv[oò]ng\b|'
        r'\b20\d\d\b|'
        r'\bpdm\s*\d|'
        r'\b\d+\s*\(\s*\d+\s*\)\s*a|'
        r'\bno\.?\s*\d+)',
        caseSensitive: false,
      ).hasMatch(text);
    }

    // ---------------------------------------------------------
    // Chuẩn hóa các ký tự ML Kit thường đọc nhầm.
    // ---------------------------------------------------------

    String normalizeNumericLike(String raw) {
      var s = raw.toUpperCase();

      s = s.replaceAll(
        RegExp(r'[\s|:_-]+'),
        '',
      );

      s = s
          .replaceAll('O', '0')
          .replaceAll('Q', '0')
          .replaceAll('D', '0');

      s = s
          .replaceAll('I', '1')
          .replaceAll('L', '1');

      s = s
          .replaceAll('S', '5')
          .replaceAll('B', '8');

      return s.replaceAll(
        RegExp(r'[^0-9.,]'),
        '',
      );
    }

    // ---------------------------------------------------------
    // Điểm vị trí.
    // ---------------------------------------------------------

    double spatialScore(
      Rect box,
      String text,
    ) {
      // Nếu người dùng đã tự khoanh đúng cửa sổ số
      // thì ưu tiên rất cao.
      var score = manualRegion ? 120.0 : 20.0;

      final ratio =
          box.height > 0 ? box.width / box.height : 0.0;

      if (ratio >= 2.0) {
        score += 20;
      }

      if (ratio >= 3.0) {
        score += 15;
      }

      if (RegExp(
        r'k\s*w\s*h',
        caseSensitive: false,
      ).hasMatch(text)) {
        score += 55;
      }

      var nearest = double.infinity;

      for (final k in kwhBoxes) {
        final dx = box.center.dx - k.center.dx;
        final dy = box.center.dy - k.center.dy;

        nearest = math.min(
          nearest,
          math.sqrt(dx * dx + dy * dy),
        );
      }

      if (nearest < 180) {
        score += 25;
      }

      if (nearest < 100) {
        score += 20;
      }

      if (allBounds != null &&
          allBounds!.height > 0) {
        final y =
            (box.center.dy - allBounds!.top) /
                allBounds!.height;

        // Cửa sổ chỉ số thường nằm ở nửa trên mặt đồng hồ.
        if (y < 0.50) {
          score += 15;
        }
      }

      return score;
    }

    // ---------------------------------------------------------
    // ĐIỆN CƠ
    //
    // Ví dụ:
    //
    // 999853 -> 99985
    // 020322 -> 02032
    //
    // Số thứ 6 là bánh đỏ / 0.1 kWh.
    // ---------------------------------------------------------

    void addMechanical(
      String raw,
      Rect box,
      String context,
    ) {
      if (technical(context) &&
          !RegExp(
            r'k\s*w\s*h',
            caseSensitive: false,
          ).hasMatch(context)) {
        return;
      }

      final digits =
          normalizeNumericLike(raw)
              .replaceAll('.', '')
              .replaceAll(',', '');

      if (digits.length < 6) {
        return;
      }

      // Không lấy một chuỗi quá dài vì khả năng cao là serial.
      if (digits.length > 7) {
        return;
      }

      final six = digits.substring(0, 6);

      final mainFive = six.substring(0, 5);

      final value = int.tryParse(mainFive);

      if (value == null) {
        return;
      }

      var score =
          spatialScore(box, context);

      // Đúng 6 bánh là trường hợp tốt nhất.
      if (digits.length == 6) {
        score += 60;
      }

      if (digits.length == 7) {
        score += 10;
      }

      // Có kWh bên cạnh rất đáng tin.
      if (RegExp(
        r'k\s*w\s*h',
        caseSensitive: false,
      ).hasMatch(context)) {
        score += 40;
      }

      if (previousReading == 0 ||
          value >= previousReading) {
        score += 10;
      }

      proposals.add(
        MeterOcrChoice(
          value: value,
          source: six,
          mode: MeterReadMode.mechanical,
          score: score,
          wheelLayoutHint: true,
        ),
      );
    }

    // ---------------------------------------------------------
    // ĐIỆN TỬ
    // ---------------------------------------------------------

    void addElectronic(
      String raw,
      Rect box,
      String context,
    ) {
      if (technical(context) &&
          !RegExp(
            r'k\s*w\s*h',
            caseSensitive: false,
          ).hasMatch(context)) {
        return;
      }

      final cleaned =
          normalizeNumericLike(raw);

      final match = RegExp(
        r'^(\d{1,9})(?:[.,](\d{1,3}))?$',
      ).firstMatch(cleaned);

      if (match == null) {
        return;
      }

      final value =
          int.tryParse(match.group(1)!);

      if (value == null) {
        return;
      }

      var score =
          spatialScore(box, context);

      final hasDecimal =
          match.group(2) != null;

      if (hasDecimal) {
        score += 18;
      }

      proposals.add(
        MeterOcrChoice(
          value: value,
          source: cleaned,
          mode: MeterReadMode.electronic,
          score: score,
          hasDecimal: hasDecimal,
        ),
      );
    }

    // =========================================================
    // QUÉT TỪNG DÒNG
    // =========================================================

    for (final block in recognized.blocks) {
      for (final line in block.lines) {
        final text = line.text.trim();

        if (text.isEmpty) {
          continue;
        }

        final beforeKwh = text
            .split(
              RegExp(
                r'k\s*w\s*h',
                caseSensitive: false,
              ),
            )
            .first;

        // -----------------------------------------------------
        // 1. Thử cả dòng.
        // -----------------------------------------------------

        if (mode != MeterReadMode.electronic) {
          addMechanical(
            beforeKwh,
            line.boundingBox,
            text,
          );
        }

        if (mode != MeterReadMode.mechanical) {
          for (final m in RegExp(
            r'[0-9OQDILSB]'
            r'[0-9OQDILSB\s.,:_|-]{2,}',
          ).allMatches(
            beforeKwh.toUpperCase(),
          )) {
            addElectronic(
              m.group(0)!,
              line.boundingBox,
              text,
            );
          }
        }

        // -----------------------------------------------------
        // 2. Gom các TextElement LIÊN TIẾP trên cùng một dòng.
        //
        // Không ghép số từ dòng khác.
        // -----------------------------------------------------

        final group = <TextElement>[];

        void flush() {
          if (group.isEmpty) {
            return;
          }

          final raw =
              group.map((e) => e.text).join('');

          final left = group
              .map((e) => e.boundingBox.left)
              .reduce(math.min);

          final top = group
              .map((e) => e.boundingBox.top)
              .reduce(math.min);

          final right = group
              .map((e) => e.boundingBox.right)
              .reduce(math.max);

          final bottom = group
              .map((e) => e.boundingBox.bottom)
              .reduce(math.max);

          final box = Rect.fromLTRB(
            left,
            top,
            right,
            bottom,
          );

          if (mode !=
              MeterReadMode.electronic) {
            addMechanical(
              raw,
              box,
              text,
            );
          }

          if (mode !=
              MeterReadMode.mechanical) {
            addElectronic(
              raw,
              box,
              text,
            );
          }

          group.clear();
        }

        for (final element
            in line.elements) {
          final value =
              element.text.trim().toUpperCase();

          if (RegExp(
            r'^[0-9OQDILSB.,:_|-]+$',
          ).hasMatch(value)) {
            group.add(element);
          } else {
            flush();
          }
        }

        flush();
      }
    }

    // =========================================================
    // XÓA CANDIDATE TRÙNG
    // =========================================================

    final unique =
        <String, MeterOcrChoice>{};

    for (final choice in proposals) {
      final key =
          '${choice.mode.name}:'
          '${choice.value}:'
          '${choice.source}';

      final old = unique[key];

      if (old == null ||
          old.score < choice.score) {
        unique[key] = choice;
      }
    }

    final choices =
        unique.values.toList()
          ..sort(
            (a, b) =>
                b.score.compareTo(a.score),
          );

    final top =
        choices.isEmpty ? null : choices.first;

    int? suggestion;
    MeterReadMode? inferred;

    // ---------------------------------------------------------
    // DEMO:
    // Khoanh thủ công -> ngưỡng thấp hơn.
    // Ảnh toàn đồng hồ -> yêu cầu score cao.
    // ---------------------------------------------------------

    if (top != null) {
      final enoughConfidence =
          manualRegion
              ? top.score >= 100
              : top.score >= 110;

      final validReading =
          previousReading == 0 ||
              top.value >= previousReading;

      if (enoughConfidence &&
          validReading) {
        suggestion = top.value;
        inferred = top.mode;
      }
    }

    String message;

    if (choices.isEmpty) {
      message =
          'Chưa đọc được chỉ số điện. '
          'Hãy khoanh sát cửa sổ chứa các bánh số.';
    } else if (top!.mode ==
        MeterReadMode.mechanical) {
      message =
          'Đọc được cụm ${top.source}. '
          'Bản demo bỏ bánh số cuối và lấy '
          '${top.value}. Hãy đối chiếu ảnh trước khi lưu.';
    } else {
      message =
          'Đọc được vùng LCD/kWh: '
          '${top.source}. '
          'Hãy đối chiếu ảnh trước khi lưu.';
    }

    return MeterOcrResult(
      rawText: recognized.text.trim(),
      candidates:
          choices
              .map((e) => e.value)
              .toSet()
              .toList(),
      suggestedValue: suggestion,
      choices: choices,
      waterChoices: const [],
      inferredMode: inferred,
      message: message,
    );
  }
}