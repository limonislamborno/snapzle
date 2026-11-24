import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Accurate procedural cartoonifier that transforms real human photos into
/// authentic cel-shaded, ink-contoured cartoon illustrations.
class CartoonService {
  /// Converts an input [img.Image] into an accurate cartoon portrait
  static img.Image process(img.Image src) {
    // 1. Center crop to square
    final squareSize = min(src.width, src.height);
    final cropped = img.copyCrop(
      src,
      x: (src.width - squareSize) ~/ 2,
      y: (src.height - squareSize) ~/ 2,
      width: squareSize,
      height: squareSize,
    );

    // 2. Resize to 480x480 for fast processing and crisp avatar display
    final resized = img.copyResize(cropped, width: 480, height: 480);

    // 3. Vibrant cartoon color grading: high saturation, warm comic contrast
    final vibrant = img.adjustColor(
      resized,
      contrast: 1.25,
      saturation: 1.40,
      brightness: 1.10,
      gamma: 0.95,
    );

    // 4. Multi-pass smoothing (Simulates bilateral filter for flat cel-painted surfaces)
    var smoothed = img.smooth(vibrant, weight: 2);
    smoothed = img.smooth(smoothed, weight: 2);
    smoothed = img.gaussianBlur(smoothed, radius: 2);

    final width = smoothed.width;
    final height = smoothed.height;

    // 5. Sobel edge detection for comic pen ink outlines
    final edgeMap = List<double>.filled(width * height, 0.0);
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        final tl = smoothed.getPixel(x - 1, y - 1).luminanceNormalized;
        final t  = smoothed.getPixel(x,     y - 1).luminanceNormalized;
        final tr = smoothed.getPixel(x + 1, y - 1).luminanceNormalized;
        final l  = smoothed.getPixel(x - 1, y    ).luminanceNormalized;
        final r  = smoothed.getPixel(x + 1, y    ).luminanceNormalized;
        final bl = smoothed.getPixel(x - 1, y + 1).luminanceNormalized;
        final b  = smoothed.getPixel(x,     y + 1).luminanceNormalized;
        final br = smoothed.getPixel(x + 1, y + 1).luminanceNormalized;

        final gx = (-1.0 * tl - 2.0 * l - 1.0 * bl + 1.0 * tr + 2.0 * r + 1.0 * br);
        final gy = (-1.0 * tl - 2.0 * t - 1.0 * tr + 1.0 * bl + 2.0 * b + 1.0 * br);
        edgeMap[y * width + x] = sqrt(gx * gx + gy * gy);
      }
    }

    // 6. Cel-Shading quantization (12 discrete color bands) + Dark Comic Inking
    const bands = 12;
    const step = 255.0 / (bands - 1);
    final result = img.Image(width: width, height: height);

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final p = smoothed.getPixel(x, y);
        final edge = edgeMap[y * width + x];

        // Quantize colors into cel animation bands
        final qr = ((p.r / step).round() * step).clamp(0, 255).toInt();
        final qg = ((p.g / step).round() * step).clamp(0, 255).toInt();
        final qb = ((p.b / step).round() * step).clamp(0, 255).toInt();

        // Selective ink outline on structural boundaries (hair, silhouette, collar)
        if (edge > 0.34) {
          final inkFactor = ((edge - 0.34) * 3.5).clamp(0.0, 0.88);
          final ir = (qr * (1.0 - inkFactor) + 18 * inkFactor).round().clamp(0, 255);
          final ig = (qg * (1.0 - inkFactor) + 18 * inkFactor).round().clamp(0, 255);
          final ib = (qb * (1.0 - inkFactor) + 28 * inkFactor).round().clamp(0, 255);
          result.setPixelRgb(x, y, ir, ig, ib);
        } else {
          result.setPixelRgb(x, y, qr, qg, qb);
        }
      }
    }

    return result;
  }

  /// Takes raw image bytes, returns JPEG bytes of the cartoonified image
  static Uint8List cartoonifyBytes(Uint8List rawBytes) {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) throw Exception('Failed to decode image');
    final cartoon = process(decoded);
    return Uint8List.fromList(img.encodeJpg(cartoon, quality: 90));
  }
}
