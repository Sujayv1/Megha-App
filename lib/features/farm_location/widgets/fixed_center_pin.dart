import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Fixed visual teardrop location pin overlay centered precisely over the map camera target.
class FixedCenterPin extends StatelessWidget {
  final double latitude;
  final double longitude;
  final Color pinColor;

  const FixedCenterPin({
    super.key,
    required this.latitude,
    required this.longitude,
    this.pinColor = const Color(0xFF2E7D32),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: FractionalTranslation(
        translation: const Offset(0.0, -0.5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: pinColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: pinColor.withValues(alpha: 0.65),
                    blurRadius: 16,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.location_on_rounded,
                color: Colors.white,
                size: 26,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pinColor, width: 1),
              ),
              child: Text(
                '${latitude.toStringAsFixed(4)}° N, ${longitude.toStringAsFixed(4)}° E',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
