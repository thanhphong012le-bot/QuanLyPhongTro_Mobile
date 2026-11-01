import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'electric_meter_ocr_service.dart';
import 'water_meter_ocr_service.dart';
import 'meter_ocr_models.dart';

export 'meter_ocr_models.dart';

/// Điểm vào chung cho UI.
///
/// BẢN DEMO:
/// - Điện cơ: ưu tiên đọc 6 bánh số trên cùng hàng.
///   Bánh thứ 6 là số đỏ/thập phân -> bỏ.
/// - Điện tử: giữ OCR ML Kit hiện tại.
/// - Nước: giữ nguyên service hiện tại.
class MeterOcrService {
  final ElectricMeterOcrService _electric = ElectricMeterOcrService();
  final WaterMeterOcrService _water = WaterMeterOcrService();

  Future<MeterOcrResult> recognize(
    String imagePath, {
    required int previousReading,
    bool electric = false,
    MeterReadMode mode = MeterReadMode.automatic,
    WaterReadMode waterMode = WaterReadMode.automatic,
    bool manualRegion = false,
  }) async {
    final recognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );

    try {
      final inputImage = InputImage.fromFilePath(imagePath);

      final recognized = await recognizer.processImage(inputImage);

      if (electric) {
        // =========================================================
        // DEMO ĐIỆN CƠ
        // =========================================================
        //
        // Khi người dùng đã chọn "Đồng hồ điện cơ",
        // hoặc đã khoanh vùng thủ công:
        //
        // ElectricMeterOcrService sẽ:
        //   999853 -> 99985
        //   020322 -> 02032
        //
        // Không tự ghép các nhóm số ở nhiều vị trí khác nhau.
        //
        // manualRegion=true giúp vùng người dùng tự khoanh
        // được ưu tiên cao hơn.
        // =========================================================

        return _electric.recognize(
          recognized,
          previousReading: previousReading,
          mode: mode,
          manualRegion: manualRegion,
        );
      }

      // =========================================================
      // NƯỚC
      // Giữ nguyên logic hiện tại.
      // =========================================================
      return _water.recognize(
        recognized,
        previousReading,
        mode: waterMode,
        manualRegion: manualRegion,
      );
    } finally {
      await recognizer.close();
    }
  }
}