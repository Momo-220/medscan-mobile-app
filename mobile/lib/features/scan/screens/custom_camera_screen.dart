import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/colors.dart';
import '../../../shared/utils/localization.dart';

class CustomCameraPage extends StatefulWidget {
  const CustomCameraPage({super.key});

  @override
  State<CustomCameraPage> createState() => _CustomCameraPageState();
}

class _CustomCameraPageState extends State<CustomCameraPage> with WidgetsBindingObserver {
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isReady = false;
  bool _isFlashOn = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) return;

      // Select back camera
      final backCam = _cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      if (_isFlashOn) {
        await _controller!.setFlashMode(FlashMode.off);
      } else {
        await _controller!.setFlashMode(FlashMode.torch);
      }
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('Flash error: $e');
    }
  }

  void _capturePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final image = await _controller!.takePicture();
      if (mounted) {
        Navigator.pop(context, image.path);
      }
    } catch (e) {
      debugPrint('Capture error: $e');
    }
  }

  void _pickFromGallery() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
      if (image != null && mounted) {
        Navigator.pop(context, image.path);
      }
    } catch (e) {
      debugPrint('Gallery error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isReady || _controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final topPadding = MediaQuery.of(context).padding.top;

    // Scale preview to prevent stretching (BoxFit.cover behavior)
    final deviceRatio = size.width / size.height;
    double scale = 1.0;
    if (_controller != null && _controller!.value.isInitialized) {
      scale = 1 / (deviceRatio * _controller!.value.aspectRatio);
      if (scale < 1.0) {
        scale = 1.0 / scale;
      }
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Preview ────────────────────────────────────────────────
          Positioned.fill(
            child: ClipRect(
              child: Transform.scale(
                scale: scale,
                child: Center(
                  child: CameraPreview(_controller!),
                ),
              ),
            ),
          ),

          // ── Transparent overlay with cut-out cadrant ──────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: CameraOverlayPainter(),
            ),
          ),

          // ── Header controls (Back + Flash) ────────────────────────────────
          Positioned(
            top: topPadding + 12,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 22),
                        onPressed: () => Navigator.pop(context),
                      ),
                // Custom alignment hint
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    context.t('boxScannerTitle'),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                // Flash Toggle Button
                IconButton(
                  icon: Icon(
                    _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    color: _isFlashOn ? Colors.yellow[600] : Colors.white,
                    size: 24,
                  ),
                        onPressed: _toggleFlash,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Frame helper description text ──────────────────────────────────
          Positioned(
            top: size.height * 0.23,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  context.t('boxScannerInstruction'),
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),

          // ── Footer actions (Gallery, Capture, Flip) ────────────────────────
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 28,
            left: 0,
            right: 0,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Import Gallery Button
                      GestureDetector(
                    onTap: _pickFromGallery,
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.photo_library_outlined, color: Colors.white, size: 24),
                    ),
                  ),

                  // Take Picture Capture Button
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 4.5),
                            ),
                          ),
                          Container(
                            width: 62,
                            height: 62,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Spacer to maintain balance
                  const SizedBox(width: 52),
                ],
              ),
            ),
          ),
        ),
      ),
    ],
  ),
);
  }
}

// ─── Custom Painter for Camera Cadrant Overlay ───────────────────────────────

class CameraOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Dark semi-transparent background around the cutout
    final backdropPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.62)
      ..style = PaintingStyle.fill;

    // Proportions équilibrées pour boîtes, flacons et plaquettes de médicaments (ratio ~1.38:1)
    final double rectWidth = math.min(size.width * 0.84, 420.0);
    final double rectHeight = math.min(rectWidth * 0.72, size.height * 0.42);
    final double left = (size.width - rectWidth) / 2;
    final double top = (size.height - rectHeight) / 2 - 16; // Légèrement rehaussé pour le confort visuel

    const double cornerRadius = 24.0;
    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, rectWidth, rectHeight),
      const Radius.circular(cornerRadius),
    );

    // Découpe centrale transparente (hole cutout)
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(rrect),
      ),
      backdropPaint,
    );

    // 2. Cadre complet délicat et semi-transparent
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.25)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // 3. Coins de visée néon continus et parfaitement raccordés
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    const double armLength = 40.0; // Longueur de chaque branche (horizontale et verticale)

    // ── Coin Supérieur Gauche (Top-Left)
    final pathTL = Path()
      ..moveTo(left + armLength, top)
      ..lineTo(left + cornerRadius, top)
      ..arcToPoint(
        Offset(left, top + cornerRadius),
        radius: const Radius.circular(cornerRadius),
        clockwise: false,
      )
      ..lineTo(left, top + armLength);
    canvas.drawPath(pathTL, cornerPaint);

    // ── Coin Supérieur Droit (Top-Right)
    final pathTR = Path()
      ..moveTo(left + rectWidth - armLength, top)
      ..lineTo(left + rectWidth - cornerRadius, top)
      ..arcToPoint(
        Offset(left + rectWidth, top + cornerRadius),
        radius: const Radius.circular(cornerRadius),
        clockwise: true,
      )
      ..lineTo(left + rectWidth, top + armLength);
    canvas.drawPath(pathTR, cornerPaint);

    // ── Coin Inférieur Gauche (Bottom-Left)
    final pathBL = Path()
      ..moveTo(left, top + rectHeight - armLength)
      ..lineTo(left, top + rectHeight - cornerRadius)
      ..arcToPoint(
        Offset(left + cornerRadius, top + rectHeight),
        radius: const Radius.circular(cornerRadius),
        clockwise: false,
      )
      ..lineTo(left + armLength, top + rectHeight);
    canvas.drawPath(pathBL, cornerPaint);

    // ── Coin Inférieur Droit (Bottom-Right)
    final pathBR = Path()
      ..moveTo(left + rectWidth, top + rectHeight - armLength)
      ..lineTo(left + rectWidth, top + rectHeight - cornerRadius)
      ..arcToPoint(
        Offset(left + rectWidth - cornerRadius, top + rectHeight),
        radius: const Radius.circular(cornerRadius),
        clockwise: true,
      )
      ..lineTo(left + rectWidth - armLength, top + rectHeight);
    canvas.drawPath(pathBR, cornerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
