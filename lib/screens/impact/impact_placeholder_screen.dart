/// Impact Placeholder Screen
///
/// Temporary screen shown in the Impact tab while WBS 11.3 (Impact Dashboard)
/// is not yet built. Replaced by the real ImpactScreen in WBS 11.3.
library;

import 'package:flutter/material.dart';

// ---------------------------------------------------------------------------
// Design tokens — EcoSwap Style Guide
// ---------------------------------------------------------------------------
const _kSurface = Color(0xFFFFFFFF);
const _kBorder = Color(0xFFE5E5E0);
const _kTextPrimary = Color(0xFF1A1A1A);
const _kTextSecondary = Color(0xFF6B6B66);

/// Placeholder for the Impact dashboard screen (WBS 11.3).
///
/// Shows a title-only top bar matching the style guide rule for top-level
/// screens (no cog or info icons).
class ImpactPlaceholderScreen extends StatelessWidget {
  const ImpactPlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kSurface,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
        title: const Text(
          'Impact',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: _kTextPrimary,
          ),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: _kBorder, height: 1),
        ),
      ),
      body: const Center(
        child: Text(
          'Impact dashboard coming soon',
          style: TextStyle(fontSize: 15, color: _kTextSecondary),
        ),
      ),
    );
  }
}
