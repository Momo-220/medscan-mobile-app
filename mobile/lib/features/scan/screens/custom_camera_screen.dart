import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/colors.dart';
import '../../../core/constants/text_styles.dart';

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

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Camera Preview ────────────────────────────────────────────────
          Positioned.fill(
            child: CameraPreview(_controller!),
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
            left: 16,
            right: 16,
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
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Scanner de boîte',
                    style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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

          // ── Frame helper description text ──────────────────────────────────
          Positioned(
            top: size.height * 0.23,
            left: 24,
            right: 24,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Cadrez le médicament à l\'intérieur du cadre',
                  style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
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
                        color: Colors.white.withOpacity(0.2),
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
        ],
      ),
    );
  }
}

// ─── Custom Painter for Camera Cadrant Overlay ───────────────────────────────

class CameraOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.65)
      ..style = PaintingStyle.fill;

    // Define the scanning rectangle container shape
    final double rectWidth = size.width * 0.82;
    final double rectHeight = size.height * 0.36;
    final double left = (size.width - rectWidth) / 2;
    final double top = (size.height - rectHeight) / 2;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left, top, rectWidth, rectHeight),
      const Radius.circular(24),
    );

    // Draw opaque mask around the card frame
    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(rrect),
      ),
      paint,
    );

    // Draw elegant neon border around card frame
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(rrect, borderPaint);

    // Draw highlighted neon corner accents
    final cornerPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.5
      ..strokeCap = StrokeCap.round;

    const double cornerLen = 28.0;
    const double radiusOffset = 24.0;

    // Top-Left
    canvas.drawPath(
      Path()
        ..moveTo(left + radiusOffset, top)
        ..lineTo(left + cornerLen, top)
        ..moveTo(left, top + radiusOffset)
        ..lineTo(left, top + cornerLen)
        ..arcToPoint(Offset(left + radiusOffset, top), radius: const Radius.circular(radiusOffset)),
      cornerPaint,
    );

    // Top-Right
    canvas.drawPath(
      Path()
        ..moveTo(left + rectWidth - radiusOffset, top)
        ..lineTo(left + rectWidth - cornerLen, top)
        ..moveTo(left + rectWidth, top + radiusOffset)
        ..lineTo(left + rectWidth, top + cornerLen)
        ..arcToPoint(Offset(left + rectWidth, top + radiusOffset), radius: const Radius.circular(radiusOffset), rotation: 90, clockwise: false),
      cornerPaint,
    );

    // Bottom-Left
    canvas.drawPath(
      Path()
        ..moveTo(left + radiusOffset, top + rectHeight)
        ..lineTo(left + cornerLen, top + rectHeight)
        ..moveTo(left, top + rectHeight - radiusOffset)
        ..lineTo(left, top + rectHeight - cornerLen)
        ..arcToPoint(Offset(left, top + rectHeight - radiusOffset), radius: const Radius.circular(radiusOffset), clockwise: false),
      cornerPaint,
    );

    // Bottom-Right
    canvas.drawPath(
      Path()
        ..moveTo(left + rectWidth - radiusOffset, top + rectHeight)
        ..lineTo(left + rectWidth - cornerLen, top + rectHeight)
        ..moveTo(left + rectWidth, top + rectHeight - radiusOffset)
        ..lineTo(left + rectWidth, top + rectHeight - cornerLen)
        ..arcToPoint(Offset(left + rectWidth - radiusOffset, top + rectHeight), radius: const Radius.circular(radiusOffset)),
      cornerPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
