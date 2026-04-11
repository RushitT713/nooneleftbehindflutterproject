import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_selfie_segmentation/google_mlkit_selfie_segmentation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../constants.dart';

/// Automatic face extraction screen.
/// 1) Runs face detection on the full-res image to find the face bounding box
/// 2) Runs selfie segmentation to create a person mask
/// 3) Combines both: crops to head area + removes background
/// Returns a transparent PNG of just the face.
class FaceCropScreen extends StatefulWidget {
  final File imageFile;

  const FaceCropScreen({super.key, required this.imageFile});

  @override
  State<FaceCropScreen> createState() => _FaceCropScreenState();
}

class _FaceCropScreenState extends State<FaceCropScreen>
    with SingleTickerProviderStateMixin {
  File? _resultFile;
  bool _isProcessing = true;
  String _statusMessage = 'Detecting face...';
  double _progress = 0.0;

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _processImage();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _processImage() async {
    try {
      final inputImage = InputImage.fromFilePath(widget.imageFile.path);

      // ── Step 1: Face Detection ──────────────────────────
      setState(() {
        _statusMessage = 'Detecting face...';
        _progress = 0.15;
      });

      final faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableLandmarks: true,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );
      final faces = await faceDetector.processImage(inputImage);
      faceDetector.close();

      if (faces.isEmpty) {
        throw Exception(
            'No face detected. Please use a clear photo of your face.');
      }

      // Use the largest face found
      final face = faces.reduce(
          (a, b) => a.boundingBox.width > b.boundingBox.width ? a : b);
      final faceBox = face.boundingBox;

      // ── Step 2: Selfie Segmentation ────────────────────
      setState(() {
        _statusMessage = 'Removing background...';
        _progress = 0.40;
      });

      final segmenter = SelfieSegmenter(mode: SegmenterMode.single);
      final mask = await segmenter.processImage(inputImage);
      segmenter.close();

      if (mask == null) {
        throw Exception(
            'Background removal failed. Please try a different photo.');
      }

      // ── Step 3: Load image & apply mask ────────────────
      setState(() {
        _statusMessage = 'Processing...';
        _progress = 0.65;
      });

      final bytes = await widget.imageFile.readAsBytes();
      final original = img.decodeImage(bytes);
      if (original == null) throw Exception('Failed to decode image');

      final imgW = original.width;
      final imgH = original.height;
      final maskW = mask.width;
      final maskH = mask.height;

      // ── Step 4: Calculate head crop area ───────────────
      // Expand the face bounding box to include hair, ears, and chin
      final faceW = faceBox.width;
      final faceH = faceBox.height;
      final faceCx = faceBox.center.dx;
      final faceCy = faceBox.center.dy;

      // Expand: more on top for hair, slightly wider for ears
      final cropLeft = (faceCx - faceW * 0.75).round().clamp(0, imgW);
      final cropTop = (faceCy - faceH * 0.85).round().clamp(0, imgH); // extra for hair
      final cropRight = (faceCx + faceW * 0.75).round().clamp(0, imgW);
      final cropBottom = (faceCy + faceH * 0.65).round().clamp(0, imgH); // chin area

      final cropW = cropRight - cropLeft;
      final cropH = cropBottom - cropTop;

      if (cropW <= 0 || cropH <= 0) {
        throw Exception('Face area too small. Try a closer photo.');
      }

      setState(() {
        _statusMessage = 'Creating cutout...';
        _progress = 0.80;
      });

      // ── Step 5: Create the transparent face cutout ─────
      final result = img.Image(width: cropW, height: cropH, numChannels: 4);

      for (int y = 0; y < cropH; y++) {
        for (int x = 0; x < cropW; x++) {
          final srcX = cropLeft + x;
          final srcY = cropTop + y;

          if (srcX < 0 || srcX >= imgW || srcY < 0 || srcY >= imgH) continue;

          // Map to mask coordinates
          final mX = (srcX * maskW / imgW).round().clamp(0, maskW - 1);
          final mY = (srcY * maskH / imgH).round().clamp(0, maskH - 1);

          final confidence = mask.confidences[mY * maskW + mX];
          final pixel = original.getPixel(srcX, srcY);

          if (confidence > 0.5) {
            result.setPixelRgba(
                x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), 255);
          } else if (confidence > 0.1) {
            // Smooth edge blending
            final alpha =
                ((confidence - 0.1) / 0.4 * 255).round().clamp(0, 255);
            result.setPixelRgba(
                x, y, pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt(), alpha);
          }
        }
      }

      // ── Step 6: Trim transparent edges ─────────────────
      final trimmed = _trimTransparent(result);

      // ── Step 7: Save PNG ───────────────────────────────
      setState(() {
        _statusMessage = 'Saving...';
        _progress = 0.95;
      });

      final pngBytes = img.encodePng(trimmed);
      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
          '${tempDir.path}/face_${DateTime.now().millisecondsSinceEpoch}.png');
      await outputFile.writeAsBytes(pngBytes);

      if (mounted) {
        setState(() {
          _resultFile = outputFile;
          _isProcessing = false;
          _progress = 1.0;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '$e';
        });
      }
    }
  }

  /// Trim fully transparent rows/columns from edges
  img.Image _trimTransparent(img.Image src) {
    int top = 0, bottom = src.height - 1;
    int left = 0, right = src.width - 1;

    // Find top
    outer:
    for (int y = 0; y < src.height; y++) {
      for (int x = 0; x < src.width; x++) {
        if (src.getPixel(x, y).a > 10) {
          top = y;
          break outer;
        }
      }
    }

    // Find bottom
    outer:
    for (int y = src.height - 1; y >= top; y--) {
      for (int x = 0; x < src.width; x++) {
        if (src.getPixel(x, y).a > 10) {
          bottom = y;
          break outer;
        }
      }
    }

    // Find left
    outer:
    for (int x = 0; x < src.width; x++) {
      for (int y = top; y <= bottom; y++) {
        if (src.getPixel(x, y).a > 10) {
          left = x;
          break outer;
        }
      }
    }

    // Find right
    outer:
    for (int x = src.width - 1; x >= left; x--) {
      for (int y = top; y <= bottom; y++) {
        if (src.getPixel(x, y).a > 10) {
          right = x;
          break outer;
        }
      }
    }

    // Add small padding
    final pad = 4;
    left = math.max(0, left - pad);
    top = math.max(0, top - pad);
    right = math.min(src.width - 1, right + pad);
    bottom = math.min(src.height - 1, bottom + pad);

    final w = right - left + 1;
    final h = bottom - top + 1;

    if (w <= 0 || h <= 0) return src;

    return img.copyCrop(src, x: left, y: top, width: w, height: h);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        backgroundColor: kBackground,
        foregroundColor: kTextPrimary,
        title: Text(_isProcessing ? 'Processing...' : 'Result'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: _isProcessing ? _buildProcessingView() : _buildResultView(),
    );
  }

  Widget _buildProcessingView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated photo preview
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Opacity(
                  opacity: 0.4 + _pulseController.value * 0.3,
                  child: child,
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  widget.imageFile,
                  width: 180,
                  height: 220,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 36),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _progress,
                minHeight: 6,
                backgroundColor: kSurfaceBorder,
                valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
              ),
            ),
            const SizedBox(height: 16),

            Text(
              _statusMessage,
              style: const TextStyle(
                  color: kTextPrimary, fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              '${(_progress * 100).round()}%',
              style: const TextStyle(color: kTextTertiary, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultView() {
    if (_resultFile == null) {
      // Error state
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.face_retouching_off,
                  color: Colors.redAccent, size: 56),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                style: const TextStyle(color: kTextSecondary, fontSize: 15),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                label: const Text('Pick Another Photo',
                    style: TextStyle(color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kTextSecondary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        const Text(
          'Your face cutout is ready!',
          style: TextStyle(
              color: kTextSecondary, fontSize: 14, fontWeight: FontWeight.w500),
        ),

        // Result preview with checkerboard
        Expanded(
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kSurfaceBorder),
                boxShadow: [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.08),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(300, 380),
                      painter: _CheckerboardPainter(),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Image.file(
                        _resultFile!,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom actions
        Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          color: kSurface,
          child: Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.refresh, color: kTextSecondary),
                label: const Text('Retake',
                    style: TextStyle(color: kTextSecondary)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kSurfaceBorder),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, _resultFile),
                icon: const Icon(Icons.check, color: Colors.white),
                label: const Text(
                  'Use This',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Subtle checkerboard to visualize transparency
class _CheckerboardPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 12.0;
    final light = Paint()..color = const Color(0xFFEEEEEE);
    final dark = Paint()..color = const Color(0xFFE0E0E0);

    for (double y = 0; y < size.height; y += tileSize) {
      for (double x = 0; x < size.width; x += tileSize) {
        final isLight = ((x ~/ tileSize) + (y ~/ tileSize)) % 2 == 0;
        canvas.drawRect(
          Rect.fromLTWH(x, y, tileSize, tileSize),
          isLight ? light : dark,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
