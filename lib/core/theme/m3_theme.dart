import 'package:flutter/material.dart';

/// Material 3 主题 —— 严格对齐官方 M3 基线（material_3_demo）。
///
/// 官方基线只做 `ThemeData(colorSchemeSeed: X, useMaterial3: true)`，
/// M3 的完整视觉（色彩角色/排版/形状/高度）由 Flutter 内置 M3 默认值提供。
/// 这里在基线上补充**统一语义的组件主题**，让各页面不再手写样式：
///   - Card / ListTile / Chip / InputDecoration / Dialog 等组件统一走主题，
///     消除各页面散落的 `Card(每一行)`、`TextStyle(fontSize:)`、`Colors.*`。
/// 所有颜色、排版、形状均来自 `colorScheme` / `textTheme` / M3 内置默认值。
class M3Theme {
  M3Theme._();

  /// M3 基线 seed 色（Material Design 3 Baseline，官方示例默认值）。
  static const Color seed = Color(0xff6750a4);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      // ---- 统一排版：卡片标题/正文/标签由 textTheme 语义驱动，不再手写字号 ----
      textTheme: Typography.material2021().black.apply(
            bodyColor: scheme.onSurface,
            displayColor: scheme.onSurface,
          ),
      // ---- Card：默认平坦填充式，避免「每行一个 Card」的多层阴影 ----
      cardTheme: CardThemeData(
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // ---- 列表项：统一间距，leading 图标用 onSurfaceVariant ----
      listTileTheme: const ListTileThemeData(
        iconColor: null,
        titleTextStyle: null,
        subtitleTextStyle: null,
      ),
      // ---- Chip：标签片 / 筛选片统一形状 ----
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // ---- 输入框：M3 填充式 ----
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      // ---- 对话框：统一圆角 ----
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
      ),
      // ---- 底部导航 ----
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: scheme.secondaryContainer,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      // ---- 浮动按钮 ----
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
