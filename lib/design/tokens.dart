import 'package:flutter/material.dart';

class AppColors {
  // Base colors - React parity near-black background
  static const Color baseDark1 = Color(0xFF0A0A0A); // React: #0a0a0a
  static const Color baseDark2 = Color(0xFF0B0B0B); // Slightly varied
  static const Color baseDark3 = Color(0xFF0A0A0A); // Keep consistent
  
  // Accent colors - emerald and cyan (Emerald Edition)
  static const Color emerald = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF34D399);
  static const Color emeraldDark = Color(0xFF059669);
  
  static const Color cyan = Color(0xFF06B6D4);
  static const Color cyanLight = Color(0xFF22D3EE);
  static const Color cyanDark = Color(0xFF0891B2);
  
  // Glass colors
  static const Color glassBackground = Color(0x0FFFFFFF); // white/6%
  static const Color glassBorder = Color(0x1FFFFFFF); // white/12%
  static const Color glassHighlight = Color(0x0FFFFFFF); // white/6%
  
  // Text colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF); // white/70%
  static const Color textTertiary = Color(0x99FFFFFF); // white/60%
  static const Color textQuaternary = Color(0x66FFFFFF); // white/40%
  
  // Status colors
  static const Color success = emerald;
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  
  // Additional colors for habit picker
  static const Color purple = Color(0xFF8B5CF6);
  static const Color rose = Color(0xFFF43F5E);
  
  // OS Metrics colors
  static const Color amber = Color(0xFFFBBF24); // Yellow/amber for mid-range metrics
  static const Color fire = Color(0xFFFF6B35); // Fire orange for streak
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [emerald, cyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Emerald Edition: Main gradient for headers, CTAs
  static const LinearGradient emeraldGradient = LinearGradient(
    colors: [emeraldLight, emerald, emeraldDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [baseDark1, baseDark2, baseDark3],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient fulfillmentGradient = LinearGradient(
    colors: [emeraldLight, cyanLight, emerald],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
  
  static const LinearGradient driftGradient = LinearGradient(
    colors: [Color(0xFFFB7185), Color(0xFFFCD34D), Color(0xFFFDE047)],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
}

class AppBorderRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double xxl = 24.0;
  static const double full = 999.0;
}

class AppShadows {
  static const List<BoxShadow> glass = [
    BoxShadow(
      color: Color(0x0FFFFFFF), // inset highlight
      offset: Offset(0, 1),
      blurRadius: 0,
      spreadRadius: 0,
    ),
    BoxShadow(
      color: Color(0x59000000), // outer shadow
      offset: Offset(0, 25),
      blurRadius: 50,
      spreadRadius: -12,
    ),
  ];
  
  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x8810B981), // emerald glow
      offset: Offset(0, 0),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];
  
  static const List<BoxShadow> glowCyan = [
    BoxShadow(
      color: Color(0x8806B6D4), // cyan glow
      offset: Offset(0, 0),
      blurRadius: 20,
      spreadRadius: 0,
    ),
  ];
}

class AppTextStyles {
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle body = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodyMedium = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle bodySemiBold = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );
  
  static const TextStyle caption = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );
  
  static const TextStyle captionSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textTertiary,
  );
  
  static const TextStyle label = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: AppColors.textQuaternary,
  );
}
