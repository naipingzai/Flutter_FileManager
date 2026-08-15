import 'dart:ui';
import 'package:flutter/material.dart';

/// 液态玻璃（Glassmorphism）工具组件
///
/// 用 BackdropFilter + blur 实现半透明模糊质感：
/// 半透明白卡片 + 圆角 + 细边框，背景用渐变衬托。
class Glass {
  static const blur = 18.0;
  static const radius = 20.0;

  /// 玻璃卡片容器
  static Widget card({
    required Widget child,
    EdgeInsetsGeometry padding = const EdgeInsets.all(16),
    double radius = Glass.radius,
    double opacity = 0.55,
    VoidCallback? onTap,
    BorderRadius? borderRadius,
  }) {
    final rounded = borderRadius ?? BorderRadius.circular(radius);
    Widget content = ClipRRect(
      borderRadius: rounded,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: Glass.blur, sigmaY: Glass.blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: rounded,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4)),
          ),
          child: child,
        ),
      ),
    );
    if (onTap != null) {
      content = InkWell(
        onTap: onTap,
        borderRadius: rounded,
        child: content,
      );
    }
    return content;
  }

  /// 玻璃卡片（圆角+内边距，短参数版）
  static Widget box({
    required Widget child,
    double radius = 16,
    EdgeInsetsGeometry padding = const EdgeInsets.all(12),
    double opacity = 0.5,
    VoidCallback? onTap,
  }) =>
      Glass.card(
        child: child,
        radius: radius,
        padding: padding,
        opacity: opacity,
        onTap: onTap,
      );

  /// 渐变背景（液态玻璃需要有层次的底色衬托）
  static Widget background(Widget child, {Color? seed}) {
    final c = seed ?? Colors.blue;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            c.withValues(alpha: 0.35),
            c.withValues(alpha: 0.12),
            Colors.deepPurple.withValues(alpha: 0.15),
          ],
        ),
      ),
      child: child,
    );
  }

  /// 玻璃 app bar（title 为 Widget，可传 Text/TextField）
  static PreferredSizeWidget appBar(
    BuildContext context, {
    required Widget title,
    List<Widget>? actions,
    Widget? leading,
  }) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(64),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: Glass.blur, sigmaY: Glass.blur),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.4),
              border: Border(
                bottom: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    if (leading != null) leading,
                    Expanded(
                      child: DefaultTextStyle(
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        child: title,
                      ),
                    ),
                    if (actions != null) ...actions,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 玻璃底部导航栏
  static Widget bottomNav({
    required int current,
    required ValueChanged<int> onChanged,
    required List<({IconData icon, IconData active, String label})> items,
  }) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: Glass.blur, sigmaY: Glass.blur),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            border: Border(
              top: BorderSide(color: Colors.white.withValues(alpha: 0.3)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 60,
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: InkWell(
                        onTap: () => onChanged(i),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              i == current ? items[i].active : items[i].icon,
                              color: i == current
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              items[i].label,
                              style: TextStyle(
                                fontSize: 11,
                                color: i == current
                                    ? Colors.blue.shade700
                                    : Colors.grey.shade700,
                                fontWeight: i == current
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
