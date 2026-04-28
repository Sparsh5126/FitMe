import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/theme/app_theme.dart';
import '../models/food_item.dart';
import '../services/food_search_service.dart';

/// Full-screen barcode scanner.
///
/// The camera widget is NEVER rebuilt or disposed during the API call.
/// All lookup happens inside this screen; the caller receives a [FoodItem]
/// (or null on cancel / not-found).
///
/// Usage:
///   final food = await BarcodeScannerScreen.scan(context);
///   if (food != null) { /* go to QuantitySelectionScreen */ }
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  static Future<FoodItem?> scan(BuildContext context) {
    return Navigator.push<FoodItem>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerScreen()),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

enum _ScanState { scanning, fetching, notFound }

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  // Controller is created once and kept alive for the lifetime of this screen.
  final MobileScannerController _ctrl = MobileScannerController();

  _ScanState _state = _ScanState.scanning;

  // Guards against duplicate detection callbacks while the API call is running.
  bool _isProcessing = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // Duplicate-scan guard — critical: must check before any async gap.
    if (_isProcessing) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null || raw.isEmpty) return;

    _isProcessing = true;
    HapticFeedback.mediumImpact();

    // Pause camera — widget is NOT rebuilt, just the stream is stopped.
    await _ctrl.stop();

    if (!mounted) return;
    setState(() => _state = _ScanState.fetching);

    // Lookup product. lookupBarcode has its own 2s+2s internal timeouts.
    FoodItem? food;
    try {
      food = await FoodSearchService.lookupBarcode(raw)
          .timeout(const Duration(seconds: 5));
    } catch (_) {
      food = null;
    }

    if (!mounted) return;

    if (food != null) {
      // Return the food item to the caller directly.
      Navigator.pop(context, food);
    } else {
      // Show the "not found" panel — user can rescan or go back to search.
      setState(() => _state = _ScanState.notFound);
    }
  }

  Future<void> _rescan() async {
    _isProcessing = false;
    setState(() => _state = _ScanState.scanning);
    await _ctrl.start();
  }

  @override
  Widget build(BuildContext context) {
    final isFetching = _state == _ScanState.fetching;
    final isNotFound = _state == _ScanState.notFound;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          isFetching ? 'Fetching food…' : 'Scan Barcode',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_state == _ScanState.scanning)
            IconButton(
              icon: const Icon(Icons.flash_on_rounded),
              onPressed: _ctrl.toggleTorch,
              tooltip: 'Toggle flash',
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Camera — stays alive throughout all states ──────────────────
          MobileScanner(
            controller: _ctrl,
            onDetect: _onDetect,
          ),

          // ── Viewfinder frame ────────────────────────────────────────────
          if (!isNotFound)
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 260,
                height: 160,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isFetching
                        ? Colors.white24
                        : AppTheme.accent,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),

          // ── "Scanning" hint ─────────────────────────────────────────────
          if (_state == _ScanState.scanning)
            const Positioned(
              bottom: 72,
              left: 0,
              right: 0,
              child: Text(
                'Point at a product barcode',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),

          // ── "Fetching food…" overlay ─────────────────────────────────────
          if (isFetching)
            Container(
              color: Colors.black54,
              alignment: Alignment.center,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 28),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A2332),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                      color: AppTheme.accent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: AppTheme.accent,
                      strokeWidth: 3,
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Fetching food…',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Looking up product details',
                      style: TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),

          // ── "Not found" bottom panel ─────────────────────────────────────
          if (isNotFound)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {}, // absorb taps on dimmed background
                child: Container(
                  color: Colors.black54,
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    child: Container(
                      width: double.infinity,
                      padding:
                          const EdgeInsets.fromLTRB(24, 24, 24, 28),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A2332),
                        borderRadius: BorderRadius.vertical(
                            top: Radius.circular(24)),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Handle
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(2)),
                          ),
                          const SizedBox(height: 20),
                          const Icon(Icons.search_off_rounded,
                              color: Colors.white38, size: 44),
                          const SizedBox(height: 14),
                          const Text(
                            'Product not found',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            "This product isn't in our database yet.\nYou can search by name or add it manually.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 13,
                                height: 1.5),
                          ),
                          const SizedBox(height: 28),
                          Row(children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () =>
                                    Navigator.pop(context, null),
                                icon: const Icon(Icons.search_rounded,
                                    size: 18),
                                label: const Text('Search by Name'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(
                                      color: Colors.white24),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _rescan,
                                icon: const Icon(
                                    Icons.qr_code_scanner_rounded,
                                    size: 18),
                                label: const Text('Rescan'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accent,
                                  foregroundColor: AppTheme.background,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
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
