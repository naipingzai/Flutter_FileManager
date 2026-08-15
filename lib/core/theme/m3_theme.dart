import 'package:flutter/material.dart';

/// Material 3 (M3) 主题 —— 严格遵循官方设计令牌。
/// 参考：https://m3.material.io/ 与 Flutter Material 3 迁移指南
/// https://docs.flutter.dev/release/breaking-changes/material-3-migration
class M3Theme {
  M3Theme._();

  /// M3 色彩系统：由 seed color 生成完整的 tonal palette。
  /// 亮色主题。
  static ThemeData light() => _build(Brightness.light);

  /// M3 色彩系统：暗色主题。
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    // ---- M3 颜色系统 ----
    // ColorScheme.fromSeed 依据 M3 色彩规范生成 Primary/Secondary/Tertiary
    // 及其 tonal palettes，保证可达性对比度。
    final seeded = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5), // Indigo seed
      brightness: brightness,
    );
    final colorScheme = seeded.copyWith(
      surfaceTint: seeded.primary, // M3: 用 surfaceTint 表示 elevation
    );

    // ---- M3 形状系统 ----
    // 角尺寸（M3 shape scale）：
    //   small=4, medium=8, large=12, extraLarge=16, full=28
    final shapeScale = _M3ShapeScale();
    final cardShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(shapeScale.large),
    );
    final dialogShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(shapeScale.extraLarge),
    );

    // ---- M3 排版系统 ----
    // 使用 M3 类型刻度（TypeScale）：display/large→body/small。
    final textTheme = _m3TextTheme();

    // ---- M3 组件主题 ----
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      textTheme: textTheme,
    );

    return base.copyWith(
      // M3 Top App Bar：surface 背景，无阴影，用 surfaceTint 与内容分层。
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: colorScheme.primary,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      // M3 Card：elevation 1，surfaceContainerLow 背景，large 圆角，surfaceTint。
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 1,
        shadowColor: colorScheme.shadow,
        shape: cardShape,
        margin: EdgeInsets.zero,
      ),
      // M3 Navigation Bar：surfaceContainer 背景，full 圆角，elevation 3。
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        surfaceTintColor: colorScheme.surfaceTint,
        elevation: 3,
        height: 80,
        indicatorColor: colorScheme.secondaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            color: selected
                ? colorScheme.onSecondaryContainer
                : colorScheme.onSurfaceVariant,
          );
        }),
      ),
      // M3 Chips：medium 圆角(8)，surfaceContainer 背景，outline 描边。
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedColor: colorScheme.secondaryContainer,
        checkmarkColor: colorScheme.onSecondaryContainer,
        side: BorderSide(color: colorScheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapeScale.medium),
        ),
        labelStyle: TextStyle(color: colorScheme.onSurface, fontSize: 13),
        secondaryLabelStyle: TextStyle(color: colorScheme.onSurface),
      ),
      // M3 FilledButton（primary 强调按钮）：extraLarge 圆角(20)。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapeScale.extraLarge),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      // M3 TextButton：extraLarge 圆角(20)。
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(shapeScale.extraLarge),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
      // M3 Dialog：extraLarge 圆角(28)，surfaceContainerLow 背景。
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: dialogShape,
      ),
      // M3 Bottom Sheet：顶部 extraLarge(28) 圆角，surfaceContainerLow 背景。
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        surfaceTintColor: colorScheme.surfaceTint,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        showDragHandle: true,
      ),
      // M3 SnackBar：inverseSurface 背景，onInverseSurface 文字。
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(shapeScale.medium),
        ),
      ),
      // M3 ListTile：用 surface 背景、onSurfaceVariant 次要文字。
      listTileTheme: ListTileThemeData(
        textColor: colorScheme.onSurface,
        iconColor: colorScheme.onSurfaceVariant,
        selectedTileColor: colorScheme.secondaryContainer,
      ),
    );
  }

  /// M3 类型刻度（Type scale）映射到 Flutter TextTheme。
  /// 参考 https://m3.material.io/styles/typography/type-scale-tokens
  static TextTheme _m3TextTheme() {
    // 用 Material 默认的 M3 TextTheme（Roboto、正确的字号/字重/行高）即可，
    // 无需覆盖 —— 默认值即遵循 M3 类型刻度。
    return ThemeData.light().textTheme;
  }
}

/// M3 形状刻度（Shape scale）的角尺寸。
class _M3ShapeScale {
  final double none = 0;
  final double small = 4;
  final double medium = 8;
  final double large = 12;
  final double extraLarge = 16;
  final double full = 28;
}
