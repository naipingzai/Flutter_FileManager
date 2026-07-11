import 'package:flutter/material.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          _section('通用设置', [
            _item(Icons.language, '语言', '跟随系统', () {}),
            _item(Icons.folder, '默认目录', '主目录', () {}),
            _item(Icons.sort, '排序方式', '按名称', () {}),
            _item(Icons.text_fields, '文件名显示', '完整显示', () {}),
            _item(Icons.visibility_off, '显示隐藏文件', '否', () {}),
          ]),
          _section('显示设置', [
            _item(Icons.format_size, '字体大小', '100%', () {}),
            _item(Icons.space_bar, '界面间距', '默认', () {}),
            _item(Icons.height, '列表项高度', '默认', () {}),
            _item(Icons.image, '图标大小', '默认', () {}),
          ]),
          _section('功能设置', [
            _item(Icons.build, '文件工具', '已启用', () {}),
            _item(Icons.movie, '媒体工具', '已启用', () {}),
            _item(Icons.delete, '回收站', '已启用', () {}),
          ]),
          _section('关于', [
            _item(Icons.info, '版本', '1.0.0', () {}),
            _item(Icons.code, '源代码', 'GPL-3.0', () {}),
          ]),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blue)),
        ),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _item(IconData icon, String title, String subtitle, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
      onTap: onTap,
    );
  }
}
