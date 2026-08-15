import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/ui_scale.dart';

class DisplaySettingsPage extends StatefulWidget {
  const DisplaySettingsPage({super.key});

  @override
  State<DisplaySettingsPage> createState() => _DisplaySettingsPageState();
}

class _DisplaySettingsPageState extends State<DisplaySettingsPage> {
  late UiScale _s;
  final _c = UiScaleController.instance;

  @override
  void initState() {
    super.initState();
    _s = _c.value;
  }

  void _set(void Function(UiScale) f) {
    setState(() {
      f(_s);
      _c.value = UiScale(
        font: _s.font,
        spacing: _s.spacing,
        listItemHeight: _s.listItemHeight,
        icon: _s.icon,
        pageMargin: _s.pageMargin,
        dialogPadding: _s.dialogPadding,
        buttonSpacing: _s.buttonSpacing,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('显示设置')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _presetCard(),
          const Divider(height: 24, indent: 16, endIndent: 16),
          _slider('字体大小', _s.font, (v) => _set((x) => x.font = v)),
          _slider('界面间距', _s.spacing, (v) => _set((x) => x.spacing = v)),
          _slider(
            '列表项高度',
            _s.listItemHeight,
            (v) => _set((x) => x.listItemHeight = v),
          ),
          _slider('图标大小', _s.icon, (v) => _set((x) => x.icon = v)),
          _slider('页面边距', _s.pageMargin, (v) => _set((x) => x.pageMargin = v)),
          _slider(
            '对话框内边距',
            _s.dialogPadding,
            (v) => _set((x) => x.dialogPadding = v),
          ),
          _slider(
            '按钮间距',
            _s.buttonSpacing,
            (v) => _set((x) => x.buttonSpacing = v),
          ),
        ],
      ),
    );
  }

  Widget _presetCard() {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      leading: Icon(
        Icons.dashboard_customize_outlined,
        color: cs.onSurfaceVariant,
      ),
      title: const Text('预设'),
      subtitle: Text(
        '紧凑 / 默认 / 宽松',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () async {
        final sel = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('选择预设'),
            children: [
              for (final e in UiScale.presets.entries)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, e.key),
                  child: Text(e.key),
                ),
            ],
          ),
        );
        if (sel != null && UiScale.presets.containsKey(sel)) {
          final p = UiScale.presets[sel]!;
          _set((x) {
            x.font = p;
            x.spacing = p;
            x.listItemHeight = p;
            x.icon = p;
            x.pageMargin = p;
            x.dialogPadding = p;
            x.buttonSpacing = p;
          });
        }
      },
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                Text(
                  '${(value * 100).round()}%',
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: cs.primary),
                ),
              ],
            ),
          ),
          Slider(
            value: value.clamp(0.5, 2.0),
            min: 0.5,
            max: 2.0,
            divisions: 30,
            label: '${(value * 100).round()}%',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
