// QR Scan Screen — WBS 10.4 (stub)
//
// This file is the navigation target for the "I'll scan their QR" option in
// the QrRolePickModal (WBS 9.6).  The full implementation is in WBS 10.4.
//
// The screen receives a matchId via route arguments:
//   Navigator.pushNamed(context, '/qr/scan', arguments: matchId)
//
// When WBS 10.4 is implemented, replace this stub with the full screen that
// uses mobile_scanner, requests camera permission, and calls validateQRToken.

import 'package:flutter/material.dart';

/// QR Scan screen stub.
///
/// Displays a placeholder until WBS 10.4 is implemented.
/// Accepts a `matchId` argument via route arguments.
class QrScanScreen extends StatelessWidget {
  const QrScanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matchId = ModalRoute.of(context)?.settings.arguments as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR'),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.qr_code_scanner,
                size: 64,
                color: Color(0xFF1D9E75),
              ),
              const SizedBox(height: 16),
              const Text(
                'QR Scan — coming in WBS 10.4',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Match: $matchId',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B6B66)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
