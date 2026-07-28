import 'package:flutter/material.dart';

/// The app's calendar-themed logo mark, reused on the splash screen.
class CalendarLogo extends StatelessWidget {
  const CalendarLogo({super.key, this.size = 120, this.bright = true});

  final double size;

  /// Whether the logo renders against a dark/colored background. Controls
  /// inner contrast (the date card flips from white to colored).
  final bool bright;

  @override
  Widget build(BuildContext context) {
    final day = DateTime.now().day.toString();
    final inner = bright ? Colors.white : const Color(0xFF6C63FF);
    final textColor = bright ? const Color(0xFF4834D4) : Colors.white;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF8E84FF), Color(0xFF6C63FF)],
        ),
        borderRadius: BorderRadius.circular(size * 0.26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4834D4).withOpacity(0.35),
            blurRadius: size * 0.22,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Binder rings at the top.
          Positioned(
            top: size * 0.08,
            left: size * 0.18,
            right: size * 0.18,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _binderRing(size * 0.08),
                _binderRing(size * 0.08),
              ],
            ),
          ),
          // Top header strip (where the rings attach).
          Positioned(
            top: size * 0.06,
            left: size * 0.12,
            right: size * 0.12,
            child: Container(
              height: size * 0.22,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(size * 0.06),
              ),
              alignment: Alignment.center,
              child: Text(
                _monthAbbrev(),
                style: TextStyle(
                  fontSize: size * 0.11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF4834D4),
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
          // Lower day card.
          Positioned(
            bottom: size * 0.1,
            left: size * 0.14,
            right: size * 0.14,
            top: size * 0.32,
            child: Container(
              decoration: BoxDecoration(
                color: inner,
                borderRadius: BorderRadius.circular(size * 0.1),
              ),
              alignment: Alignment.center,
              child: Text(
                day,
                style: TextStyle(
                  fontSize: size * 0.34,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  height: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _monthAbbrev() {
    const months = [
      'JAN','FEB','MAR','APR','MAY','JUN','JUL','AUG','SEP','OCT','NOV','DEC'
    ];
    return months[DateTime.now().month - 1];
  }

  Widget _binderRing(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withOpacity(0.9),
        border: Border.all(
          color: const Color(0xFF4834D4).withOpacity(0.2),
          width: size * 0.1,
        ),
      ),
    );
  }
}
