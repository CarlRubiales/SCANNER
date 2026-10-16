import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/scan_result.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  final bool isActive;
  const ScannerScreen({super.key, this.isActive = true});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late MobileScannerController _cameraController;
  late AnimationController _laserAnimController;
  late Animation<double> _laserPosition;

  bool _isProcessing = false;
  bool _torchOn = false;
  bool _continuousMode = true;
  bool _serverConnected = false;
  String? _lastScannedBarcode;
  DateTime? _lastScannedTime;

  ScannedParcel? _latestParcel;
  String? _latestMessage;
  String? _detectedFormatName;
  bool _showSuccessCard = false;
  bool _isAlreadyScannedResult = false;
  Timer? _autoDismissTimer;
  Timer? _healthCheckTimer;

  int _sessionScanCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _cameraController = MobileScannerController(
      autoStart: true,
      detectionSpeed: DetectionSpeed.unrestricted,
      detectionTimeoutMs: 250,
      facing: CameraFacing.back,
      torchEnabled: false,
      cameraResolution: const Size(1920, 1080),
      autoZoom: true,
      formats: const <BarcodeFormat>[], // Empty list means ALL formats: 1D linear barcodes (Code 128, Code 39, EAN-13, ITF, UPC) + 2D QR codes!
    );

    _laserAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _laserPosition = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _laserAnimController, curve: Curves.easeInOut),
    );

    _loadPreferences();
    _checkServerHealth();

    // Periodic health check every 15s
    _healthCheckTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkServerHealth();
    });
  }

  @override
  void didUpdateWidget(covariant ScannerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _cameraController.start();
      } else {
        _cameraController.stop();
      }
    }
  }

  Future<void> _loadPreferences() async {
    final continuous = await ApiService.getContinuousMode();
    if (mounted) {
      setState(() {
        _continuousMode = continuous;
      });
    }
  }

  Future<void> _checkServerHealth() async {
    final ok = await ApiService.testConnection();
    if (mounted) {
      setState(() {
        _serverConnected = ok;
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoDismissTimer?.cancel();
    _healthCheckTimer?.cancel();
    _laserAnimController.dispose();
    _cameraController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.isActive) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _cameraController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _cameraController.start();
    }
  }

  String _formatBarcodeType(BarcodeFormat format) {
    switch (format) {
      case BarcodeFormat.code128:
        return 'Code 128 (1D Barcode)';
      case BarcodeFormat.code39:
        return 'Code 39 (1D Barcode)';
      case BarcodeFormat.code93:
        return 'Code 93 (1D Barcode)';
      case BarcodeFormat.codabar:
        return 'Codabar (1D Barcode)';
      case BarcodeFormat.ean13:
        return 'EAN-13 (1D Barcode)';
      case BarcodeFormat.ean8:
        return 'EAN-8 (1D Barcode)';
      case BarcodeFormat.upcA:
        return 'UPC-A (1D Barcode)';
      case BarcodeFormat.upcE:
        return 'UPC-E (1D Barcode)';
      case BarcodeFormat.itf14:
      case BarcodeFormat.itf2of5:
      case BarcodeFormat.itf2of5WithChecksum:
        return 'ITF (1D Barcode)';
      case BarcodeFormat.pdf417:
        return 'PDF417 (2D Barcode)';
      case BarcodeFormat.qrCode:
      case BarcodeFormat.microQrCode:
        return 'QR Code';
      case BarcodeFormat.dataMatrix:
        return 'Data Matrix';
      default:
        return 'Standard Barcode';
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing || _showSuccessCard) return;

    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    // Check both rawValue and displayValue to guarantee barcode extraction
    String? code;
    String? formatName;
    for (final b in barcodes) {
      final raw = b.rawValue?.trim();
      final display = b.displayValue?.trim();
      if (raw != null && raw.isNotEmpty) {
        code = raw;
        formatName = _formatBarcodeType(b.format);
        break;
      } else if (display != null && display.isNotEmpty) {
        code = display;
        formatName = _formatBarcodeType(b.format);
        break;
      }
    }

    if (code == null || code.isEmpty) return;

    // Debounce duplicate scans within 2.5 seconds
    final now = DateTime.now();
    if (_lastScannedBarcode == code &&
        _lastScannedTime != null &&
        now.difference(_lastScannedTime!).inSeconds < 3) {
      return;
    }

    _handleBarcode(code, formatName);
  }

  void _resetScanState() {
    _autoDismissTimer?.cancel();
    if (mounted) {
      setState(() {
        _showSuccessCard = false;
        _isProcessing = false;
        _lastScannedBarcode = null;
        _lastScannedTime = null;
        _isAlreadyScannedResult = false;
        _detectedFormatName = null;
      });
    }
  }

  Future<void> _handleBarcode(String code, [String? formatName]) async {
    setState(() {
      _isProcessing = true;
      _lastScannedBarcode = code;
      _lastScannedTime = DateTime.now();
      _detectedFormatName = formatName;
    });

    HapticFeedback.heavyImpact();

    final response = await ApiService.processBarcode(code);

    if (!mounted) return;

    if (response.success && response.parcel != null) {
      if (response.isAlreadyScanned) {
        HapticFeedback.vibrate();
      } else {
        HapticFeedback.lightImpact();
      }

      setState(() {
        _isProcessing = false;
        if (!response.isAlreadyScanned) {
          _sessionScanCount++;
        }
        _latestParcel = response.parcel;
        _latestMessage = response.message;
        _isAlreadyScannedResult = response.isAlreadyScanned;
        _showSuccessCard = true;
      });

      _autoDismissTimer?.cancel();
      // Auto-unlock camera after 3.2 seconds so camera never freezes
      _autoDismissTimer = Timer(const Duration(milliseconds: 3200), () {
        _resetScanState();
      });
    } else {
      HapticFeedback.vibrate();
      _resetScanState();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _toggleTorch() async {
    try {
      await _cameraController.toggleTorch();
      setState(() {
        _torchOn = !_torchOn;
      });
    } catch (_) {}
  }

  void _switchCamera() async {
    try {
      await _cameraController.switchCamera();
    } catch (_) {}
  }

  void _toggleContinuousMode() async {
    final next = !_continuousMode;
    await ApiService.setContinuousMode(next);
    setState(() {
      _continuousMode = next;
    });
  }

  void _showManualEntryDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter Parcel Barcode'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Type barcode or pick a sample code to test:',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'e.g. LM-TRK-000001 or PKG202610150005',
                  filled: true,
                  fillColor: AppTheme.creamBg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.borderLight),
                  ),
                ),
                onSubmitted: (val) {
                  Navigator.of(ctx).pop();
                  if (val.trim().isNotEmpty) _handleBarcode(val.trim());
                },
              ),
              const SizedBox(height: 14),
              const Text(
                'Quick Test Barcodes:',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _buildQuickBarcodeChip('LM-SCAN-TEST-001', textController),
                  _buildQuickBarcodeChip('3948294092', textController),
                  _buildQuickBarcodeChip('PKG202610150005', textController),
                  _buildQuickBarcodeChip('JT002556892205', textController),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final val = textController.text.trim();
              Navigator.of(ctx).pop();
              if (val.isNotEmpty) _handleBarcode(val);
            },
            child: const Text('Submit Scan'),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickBarcodeChip(String code, TextEditingController controller) {
    return InkWell(
      onTap: () {
        controller.text = code;
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.plum.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.plum.withValues(alpha: 0.2)),
        ),
        child: Text(
          code,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.plum),
        ),
      ),
    );
  }

  Widget _buildScannerError(MobileScannerException error) {
    String title = 'Camera Unavailable';
    String message = error.errorCode.message;
    IconData icon = Icons.videocam_off_rounded;

    if (error.errorCode == MobileScannerErrorCode.permissionDenied) {
      title = 'Camera Permission Required';
      message = 'Please grant camera access in app settings to scan parcels.';
      icon = Icons.no_photography_rounded;
    } else if (error.errorCode == MobileScannerErrorCode.unsupported) {
      title = 'Camera Not Supported Here';
      message = 'Camera scanning is supported on physical Android and iOS devices. You can test scanning with sample barcodes below.';
      icon = Icons.devices_rounded;
    }

    return Container(
      color: Colors.black,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: AppTheme.orange, size: 52),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      _cameraController.start();
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Retry Camera'),
                  ),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white54),
                    ),
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.keyboard_alt_outlined, size: 18),
                    label: const Text('Enter Code'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final scanAreaWidth = (size.width * 0.88).clamp(260.0, 350.0);
    final scanAreaHeight = (scanAreaWidth * 0.58).clamp(160.0, 230.0);

    final cutoutRect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2 - 20),
      width: scanAreaWidth,
      height: scanAreaHeight,
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Optical Camera Viewfinder
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _buildScannerError(error),
          ),

          // 2. Custom Cutout Overlay (Safe difference path, never breaks Impeller or Skia)
          CustomPaint(
            size: Size(size.width, size.height),
            painter: ScannerCutoutPainter(
              cutoutRect: cutoutRect,
              borderRadius: 16,
              overlayColor: Colors.black.withValues(alpha: 0.58),
            ),
          ),

          // 3. Scanning Reticle Corners & Animated Laser
          Positioned(
            top: cutoutRect.top,
            left: cutoutRect.left,
            width: cutoutRect.width,
            height: cutoutRect.height,
            child: Stack(
              children: [
                _buildReticleCorners(),

                AnimatedBuilder(
                  animation: _laserPosition,
                  builder: (context, child) {
                    return Positioned(
                      top: cutoutRect.height * _laserPosition.value,
                      left: 10,
                      right: 10,
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: AppTheme.orange,
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.orange.withValues(alpha: 0.9),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    );
                  },
                ),

                if (_isProcessing)
                  const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 3,
                    ),
                  ),
              ],
            ),
          ),

          // 4. Top Header & Camera Action Controls
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        // Autonomous / Live Status Pill
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _serverConnected ? AppTheme.success : const Color(0xFF60A5FA),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _serverConnected ? AppTheme.success : const Color(0xFF60A5FA),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    _serverConnected ? 'Live to Sorting' : 'Offline Ready',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Session Scans Counter
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.plum.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, color: Colors.white70, size: 14),
                              const SizedBox(width: 5),
                              Text(
                                '$_sessionScanCount Scanned',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Quick Camera Utility Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        _buildGlassIconButton(
                          icon: _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                          color: _torchOn ? Colors.amberAccent : Colors.white,
                          onPressed: _toggleTorch,
                        ),
                        const SizedBox(width: 8),
                        _buildGlassIconButton(
                          icon: Icons.flip_camera_ios_rounded,
                          color: Colors.white,
                          onPressed: _switchCamera,
                        ),
                        const SizedBox(width: 8),
                        _buildGlassIconButton(
                          icon: _continuousMode ? Icons.repeat_rounded : Icons.repeat_one_rounded,
                          color: _continuousMode ? AppTheme.orange : Colors.white70,
                          onPressed: _toggleContinuousMode,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 5. Instruction banner (only shown when success card is NOT visible to eliminate layout overlap)
          if (!_showSuccessCard)
            Positioned(
              bottom: 24,
              left: 20,
              right: 20,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white24, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.qr_code_scanner_rounded, color: AppTheme.orange, size: 16),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'Point camera at barcode',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: _showManualEntryDialog,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'Enter Code',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 6. Scanned Parcel Notification Card (Constrained & Scrollable to NEVER overflow)
          if (_showSuccessCard && _latestParcel != null)
            Positioned(
              bottom: 16,
              left: 14,
              right: 14,
              child: _buildSuccessParcelCard(_latestParcel!),
            ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24, width: 1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  Widget _buildReticleCorners() {
    const cornerSize = 22.0;
    const stroke = 3.5;
    const color = AppTheme.orange;

    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: stroke),
                left: BorderSide(color: color, width: stroke),
              ),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(14)),
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: stroke),
                right: BorderSide(color: color, width: stroke),
              ),
              borderRadius: BorderRadius.only(topRight: Radius.circular(14)),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: stroke),
                left: BorderSide(color: color, width: stroke),
              ),
              borderRadius: BorderRadius.only(bottomLeft: Radius.circular(14)),
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            width: cornerSize,
            height: cornerSize,
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: stroke),
                right: BorderSide(color: color, width: stroke),
              ),
              borderRadius: BorderRadius.only(bottomRight: Radius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessParcelCard(ScannedParcel parcel) {
    final media = MediaQuery.of(context);
    final maxHeight = (media.size.height * 0.44).clamp(180.0, 320.0);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with status badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: _isAlreadyScannedResult
                        ? AppTheme.warning.withValues(alpha: 0.12)
                        : AppTheme.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isAlreadyScannedResult
                        ? Icons.warning_amber_rounded
                        : Icons.check_circle_rounded,
                    color: _isAlreadyScannedResult ? AppTheme.warning : AppTheme.success,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              parcel.parcelNumber,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
                                color: AppTheme.plum,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          if (_detectedFormatName != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                              decoration: BoxDecoration(
                                color: AppTheme.plum.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _detectedFormatName!,
                                style: const TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.plum,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        _latestMessage?.isNotEmpty == true
                            ? _latestMessage!
                            : (_isAlreadyScannedResult
                                ? 'Already in Sorting Queue'
                                : 'Queued to Sorting Center'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _isAlreadyScannedResult
                              ? AppTheme.warning
                              : Colors.green.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _isAlreadyScannedResult
                        ? AppTheme.warningLight
                        : AppTheme.orangeLight,
                    borderRadius: BorderRadius.circular(10),
                    border: _isAlreadyScannedResult
                        ? Border.all(color: AppTheme.warning.withValues(alpha: 0.3))
                        : null,
                  ),
                  child: Text(
                    _isAlreadyScannedResult ? 'Already Scanned' : 'Scanned',
                    style: TextStyle(
                      color: _isAlreadyScannedResult ? AppTheme.warning : AppTheme.orange,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 14, color: AppTheme.borderLight),

            // Details: Recipient and Location
            Row(
              children: [
                const Icon(Icons.person_pin_circle_outlined, size: 18, color: AppTheme.textMuted),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        parcel.recipientName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        '${parcel.city}, ${parcel.province}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.creamBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.borderLight),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Area',
                          style: TextStyle(fontSize: 9.5, color: AppTheme.textMuted),
                        ),
                        Text(
                          parcel.areaName.isNotEmpty ? parcel.areaName : parcel.province,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.plum,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Next Step Web Info
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _isAlreadyScannedResult
                    ? AppTheme.warningLight.withValues(alpha: 0.5)
                    : AppTheme.creamBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isAlreadyScannedResult
                      ? AppTheme.warning.withValues(alpha: 0.3)
                      : AppTheme.borderLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAlreadyScannedResult
                        ? Icons.info_outline_rounded
                        : Icons.laptop_chromebook_rounded,
                    size: 16,
                    color: _isAlreadyScannedResult ? AppTheme.warning : AppTheme.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _isAlreadyScannedResult
                          ? 'This parcel was already scanned earlier. It is already in the sorting desk queue.'
                          : (_serverConnected
                              ? 'Updated on web: Admin can sort into bin & assign to rider.'
                              : 'Saved locally on phone · Queued for web sorting desk.'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textDark,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (_continuousMode) ...[
                    const SizedBox(width: 4),
                    const Text(
                      'Next...',
                      style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Action button
            SizedBox(
              width: double.infinity,
              height: 38,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  backgroundColor: AppTheme.plum,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _resetScanState,
                child: Text(
                  _isAlreadyScannedResult ? 'Acknowledge & Scan Next' : 'Scan Next Parcel',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom cutout overlay painter using PathOperation.difference
/// Safe, reliable, and completely eliminates black shader glitching
class ScannerCutoutPainter extends CustomPainter {
  final Rect cutoutRect;
  final double borderRadius;
  final Color overlayColor;

  ScannerCutoutPainter({
    required this.cutoutRect,
    this.borderRadius = 16,
    this.overlayColor = const Color(0x99000000),
  });

  @override
  void paint(Canvas canvas, Size size) {
    final backgroundPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final cutoutPath = Path()
      ..addRRect(RRect.fromRectAndRadius(cutoutRect, Radius.circular(borderRadius)));

    final finalPath = Path.combine(PathOperation.difference, backgroundPath, cutoutPath);
    final paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    canvas.drawPath(finalPath, paint);
  }

  @override
  bool shouldRepaint(covariant ScannerCutoutPainter oldDelegate) {
    return oldDelegate.cutoutRect != cutoutRect ||
        oldDelegate.borderRadius != borderRadius ||
        oldDelegate.overlayColor != overlayColor;
  }
}
