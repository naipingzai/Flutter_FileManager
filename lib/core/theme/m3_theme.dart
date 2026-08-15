import 'package:flutter/material.dart';

/// Material 3 主题 —— 严格对齐官方 M3 基线（material_3_demo）。
///
/// 参考 Flutter 官方 demo：https://github.com/flutter/samples/tree/main/material_3_demo
/// 官方只做 `ThemeData(colorSchemeSeed: X, useMaterial3: true)`，
/// M3 的完整视觉（色彩角色/排版/形状/高度）由 Flutter 内置 M3 默认值提供，
/// 额外覆盖反而会破坏原生 M3 外观。因此这里保持极简，仅设置基线 seed 色。
class M3Theme {
  M3Theme._();

  /// M3 基线 seed 色（Material Design 3 Baseline，官方示例默认值）。
  static const Color seed = Color(0xff6750a4);

  static ThemeData light() => _build(Brightness.light);

  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: seed,
    );
  }
}
