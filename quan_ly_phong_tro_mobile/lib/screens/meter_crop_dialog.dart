import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

Future<String?> showMeterReadingCropDialog(
  BuildContext context,
  String imagePath,
) async {
  final input = await File(imagePath).readAsBytes();

  final completer = Completer<ui.Image>();
  ui.decodeImageFromList(input, completer.complete);
  final image = await completer.future;

  try {
    if (!context.mounted) return null;

    Rect normalized = const Rect.fromLTWH(
      0.18,
      0.32,
      0.64,
      0.28,
    );

    Offset? dragStart;

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, change) {
            final availableWidth = math.min(
              MediaQuery.sizeOf(dialogContext).width - 120,
              450.0,
            );

            final displayHeight =
                availableWidth * image.height / image.width;

            Offset normalize(Offset position) {
              return Offset(
                (position.dx / availableWidth).clamp(0.0, 1.0),
                (position.dy / displayHeight).clamp(0.0, 1.0),
              );
            }

            return AlertDialog(
              title: const Text('Chọn vùng chỉ số'),
              content: SizedBox(
                width: availableWidth,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Khoanh sát dãy số cần đọc. '
                        'Không lấy chữ, serial hoặc thông số xung quanh.',
                      ),
                      const SizedBox(height: 10),

                      SizedBox(
                        width: availableWidth,
                        height: displayHeight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,

                          onPanStart: (details) {
                            change(() {
                              dragStart =
                                  normalize(details.localPosition);

                              normalized = Rect.fromPoints(
                                dragStart!,
                                dragStart!,
                              );
                            });
                          },

                          onPanUpdate: (details) {
                            if (dragStart == null) return;

                            change(() {
                              normalized = Rect.fromPoints(
                                dragStart!,
                                normalize(details.localPosition),
                              );
                            });
                          },

                          onPanEnd: (_) {
                            dragStart = null;
                          },

                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: RawImage(
                                  image: image,
                                  fit: BoxFit.fill,
                                ),
                              ),

                              Positioned.fromRect(
                                rect: Rect.fromLTRB(
                                  normalized.left * availableWidth,
                                  normalized.top * displayHeight,
                                  normalized.right * availableWidth,
                                  normalized.bottom * displayHeight,
                                ),
                                child: IgnorePointer(
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: Colors.lightBlueAccent
                                          .withValues(alpha: 0.15),
                                      border: Border.all(
                                        color: Colors.yellowAccent,
                                        width: 3,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 8),

                      const Text(
                        'Khoanh càng sát cửa sổ số càng tốt.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, false);
                  },
                  child: const Text('Hủy'),
                ),

                FilledButton(
                  onPressed:
                      normalized.width > 0.025 &&
                              normalized.height > 0.015
                          ? () {
                              Navigator.pop(
                                dialogContext,
                                true,
                              );
                            }
                          : null,
                  child: const Text('Quét vùng đã chọn'),
                ),
              ],
            );
          },
        );
      },
    );

    if (approved != true) return null;

    // =========================================================
    // TÍNH VÙNG CROP TRÊN ẢNH GỐC
    // =========================================================

    final left = (normalized.left * image.width)
        .floor()
        .clamp(0, image.width - 1)
        .toInt();

    final top = (normalized.top * image.height)
        .floor()
        .clamp(0, image.height - 1)
        .toInt();

    final right = (normalized.right * image.width)
        .ceil()
        .clamp(left + 1, image.width)
        .toInt();

    final bottom = (normalized.bottom * image.height)
        .ceil()
        .clamp(top + 1, image.height)
        .toInt();

    final cropWidth = right - left;
    final cropHeight = bottom - top;

    if (cropWidth < 12 || cropHeight < 12) {
      return null;
    }

    // =========================================================
    // PHÓNG LỚN ẢNH TRƯỚC KHI OCR
    //
    // Đây là phần quan trọng.
    // Không lưu vùng crop nhỏ như code cũ.
    // =========================================================

    const scale = 4;

    final outputWidth = cropWidth * scale;
    final outputHeight = cropHeight * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Nền trắng để tránh pixel trong suốt.
    canvas.drawRect(
      Rect.fromLTWH(
        0,
        0,
        outputWidth.toDouble(),
        outputHeight.toDouble(),
      ),
      Paint()..color = Colors.white,
    );

    final sourceRect = Rect.fromLTWH(
      left.toDouble(),
      top.toDouble(),
      cropWidth.toDouble(),
      cropHeight.toDouble(),
    );

    final destinationRect = Rect.fromLTWH(
      0,
      0,
      outputWidth.toDouble(),
      outputHeight.toDouble(),
    );

    final paint = Paint()
      ..filterQuality = FilterQuality.high
      ..isAntiAlias = true;

    canvas.drawImageRect(
      image,
      sourceRect,
      destinationRect,
      paint,
    );

    final processed = await recorder
        .endRecording()
        .toImage(
          outputWidth,
          outputHeight,
        );

    try {
      final bytes = await processed.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (bytes == null) return null;

      final output = File(
        '${Directory.systemTemp.path}'
        '${Platform.pathSeparator}'
        'meter_crop_${DateTime.now().microsecondsSinceEpoch}.png',
      );

      await output.writeAsBytes(
        bytes.buffer.asUint8List(),
        flush: true,
      );

      return output.path;
    } finally {
      processed.dispose();
    }
  } finally {
    image.dispose();
  }
}