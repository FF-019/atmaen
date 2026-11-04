import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _ctrl = MobileScannerController(
    formats: const [BarcodeFormat.ean13, BarcodeFormat.ean8, BarcodeFormat.upcA, BarcodeFormat.qrCode],
  );
  bool _done = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture cap) {
    if (_done) return;
    final values = cap.barcodes.map((b) => b.rawValue).whereType<String>();
    if (values.isEmpty) return;
    final value = values.first;
    _done = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('وجّه الكاميرا للباركود', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(icon: const Icon(Icons.flash_on_rounded), onPressed: _ctrl.toggleTorch),
        ],
      ),
      body: Stack(children: [
        MobileScanner(controller: _ctrl, onDetect: _onDetect),
        Center(
          child: Container(
            width: 280,
            height: 170,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.aqua, width: 3),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        const Positioned(
          left: 24,
          right: 24,
          bottom: 48,
          child: Text(
            'الباركود عادة يكون خلف العبوة أو في أسفلها',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ]),
    );
  }
}
