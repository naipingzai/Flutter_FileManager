import 'package:flutter/material.dart';

/// 界面缩放模型（design_skill 3.7 / 13.2）
/// 全局 ValueNotifier，改变即时生效，无需重启。
class UiScale {
  double font;
  double spacing;
  double listItemHeight;
  double icon;
  double pageMargin;
  double dialogPadding;
  double buttonSpacing;

  UiScale({
    this.font = 1.0,
    this.spacing = 1.0,
    this.listItemHeight = 1.0,
    this.icon = 1.0,
    this.pageMargin = 1.0,
    this.dialogPadding = 1.0,
    this.buttonSpacing = 1.0,
  });

  static const Map<String, double> presets = {
    '紧凑': 0.8,
    '默认': 1.0,
    '宽松': 1.25,
  };

  // 便捷取整值
  double dp(double v) => v * spacing;
  double fontDp(double v) => v * font;
  double iconDp(double v) => v * icon;
  double marginDp(double v) => v * pageMargin;
}

/// 全局界面缩放状态
class UiScaleController extends ValueNotifier<UiScale> {
  UiScaleController(super.value);

  static final UiScaleController instance = UiScaleController(UiScale());
}

/// 通过 InheritedNotifier 把 UiScale 提供给子树，改变时依赖方自动重建。
class UiScaleScope extends InheritedNotifier<UiScaleController> {
  const UiScaleScope({
    super.key,
    required UiScaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static UiScale of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<UiScaleScope>();
    return scope?.notifier?.value ?? UiScale();
  }
}

