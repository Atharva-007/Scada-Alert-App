import 'package:flutter/material.dart';

class AppTheme {
  // Industrial severity colors - high contrast for readability
  static const Color criticalColor = Color(0xFFEF5350);
  static const Color criticalDark = Color(0xFFB71C1C);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color warningDark = Color(0xFFE65100);
  static const Color infoColor = Color(0xFF42A5F5);
  static const Color infoDark = Color(0xFF0D47A1);
  static const Color normalColor = Color(0xFF66BB6A);
  static const Color normalDark = Color(0xFF1B5E20);
  
  // Solid surface colors - no transparency
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color surfaceVariantDark = Color(0xFF2A2A2A);
  static const Color backgroundDark = Color(0xFF0F0F0F);
  static const Color cardDark = Color(0xFF252525);
  
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: Color(0xFF42A5F5),
        primaryContainer: Color(0xFF1565C0),
        secondary: Color(0xFF66BB6A),
        secondaryContainer: Color(0xFF2E7D32),
        error: criticalColor,
        errorContainer: criticalDark,
        surface: surfaceDark,
        surfaceContainerHighest: cardDark,
        onSurface: Color(0xFFFFFFFF),
        onSurfaceVariant: Color(0xFFB0B0B0),
        outline: Color(0xFF3F3F3F),
        shadow: Color(0xFF000000),
      ),
      scaffoldBackgroundColor: backgroundDark,
      cardTheme: CardThemeData(
        color: cardDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Color(0xFF3F3F3F), width: 1),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceDark,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFFFFF),
          letterSpacing: 0,
        ),
        iconTheme: IconThemeData(
          color: Color(0xFFFFFFFF),
          size: 24,
        ),
      ),
      textTheme: _buildTextTheme(),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(0xFF42A5F5),
          foregroundColor: Color(0xFFFFFFFF),
          minimumSize: Size(120, 48),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Color(0xFF42A5F5),
          foregroundColor: Color(0xFFFFFFFF),
          minimumSize: Size(120, 48),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Color(0xFFFFFFFF),
          minimumSize: Size(120, 48),
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          side: BorderSide(color: Color(0xFF42A5F5), width: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      iconTheme: IconThemeData(
        size: 24,
        color: Color(0xFFFFFFFF),
      ),
      dividerTheme: DividerThemeData(
        color: Color(0xFF3F3F3F),
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantDark,
        selectedColor: Color(0xFF42A5F5),
        disabledColor: Color(0xFF2A2A2A),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 0,
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 8,
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: TextStyle(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      displayMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      bodyLarge: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.15,
        height: 1.5,
      ),
      bodyMedium: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.25,
        height: 1.4,
      ),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
        height: 1.4,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
        height: 1.3,
      ),
    );
  }

  static Color getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return criticalColor;
      case 'warning':
        return warningColor;
      case 'info':
        return infoColor;
      default:
        return normalColor;
    }
  }

  static Color getSeverityDarkColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return criticalDark;
      case 'warning':
        return warningDark;
      case 'info':
        return infoDark;
      default:
        return normalDark;
    }
  }

  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'connected':
      case 'healthy':
        return normalColor;
      case 'degraded':
      case 'warning':
        return warningColor;
      case 'offline':
      case 'disconnected':
      case 'error':
        return criticalColor;
      default:
        return Color(0xFF757575);
    }
  }

  static IconData getSeverityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Icons.error;
      case 'warning':
        return Icons.warning;
      case 'info':
        return Icons.info;
      default:
        return Icons.check_circle;
    }
  }

  static IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'online':
      case 'connected':
      case 'healthy':
        return Icons.check_circle;
      case 'degraded':
      case 'warning':
        return Icons.warning_amber;
      case 'offline':
      case 'disconnected':
      case 'error':
        return Icons.error;
      default:
        return Icons.help;
    }
  }
}
