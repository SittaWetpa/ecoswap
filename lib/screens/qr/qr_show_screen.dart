// QR Show Screen — WBS 10.3 (stub)
//
// This file is the navigation target for the "I'll show the QR" option in
// the QrRolePickModal (WBS 9.6).  The full implementation is in WBS 10.3.
//
// The screen receives a matchId via route arguments:
//   Navigator.pushNamed(context, '/qr/show', arguments: matchId)
//
// When WBS 10.3 is implemented, replace this stub with the full screen that
// calls the issueQRToken Cloud Function and renders the QR code.

import 'package:flutter/material.dart';

/// QR Show screen stub.
///
/// Displays a placeholder until WBS 10.3 is implemented.
/// Accepts a `matchId` argument via route arguments.
class QrShowScreen extends StatelessWidget {
  const QrShowScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final matchId = ModalRoute.of(context)?.settings.arguments as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Show QR'),
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
              const Icon(Icons.qr_code, size: 64, color: Color(0xFF1D9E75)),
              const SizedBox(height: 16),
              const Text(
                'QR Show — coming in WBS 10.3',
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
