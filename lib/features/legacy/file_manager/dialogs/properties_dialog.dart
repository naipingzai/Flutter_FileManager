import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';
import 'package:flutter_file_manager/features/legacy/file_manager/file_manager_state.dart';
import 'package:flutter_file_manager/core/utils/formatters.dart';

class PropertiesDialog extends StatelessWidget {
  final FileEntry entry;
  final FileManagerState state;

  const PropertiesDialog({super.key, required this.entry, required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            entry.isDirectory ? Icons.folder : Icons.insert_drive_file,
            color: entry.isDirectory
                ? theme.colorScheme.tertiary
                : theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _section('基本信息', [
                _row('路径', entry.path),
                _row(
                  '类型',
                  entry.isDirectory
                      ? '目录'
                      : entry.isSymlink
                      ? '符号链接'
                      : entry.mimeType.isNotEmpty
                      ? entry.mimeType
                      : '文件',
                ),
                _row('大小', entry.sizeFormatted),
                _row('修改时间', entry.modifiedFormatted),
                if (entry.createdTime > 0)
                  _row('创建时间', Formatters.formatDate(entry.createdTime)),
                if (entry.accessTime > 0)
                  _row('访问时间', Formatters.formatDate(entry.accessTime)),
              ]),
              _section('权限', [
                _row(
                  '权限',
                  '${entry.permissionsFormatted} (${entry.octalPermissions})',
                ),
                _row('所有者', '${entry.ownerName} (${entry.uid})'),
                _row('组', '${entry.groupName} (${entry.gid})'),
                _row('可读', entry.isReadable ? '是' : '否'),
                _row('可写', entry.isWritable ? '是' : '否'),
                _row('可执行', entry.isExecutable ? '是' : '否'),
              ]),
              if (entry.isSymlink)
                _section('符号链接', [_row('目标', entry.symlinkTarget)]),
              if (entry.isFile) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '校验和',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                FutureBuilder<FileHash?>(
                  future: Future(() => state.computeHash(entry.path)),
                  builder: (ctx, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (!snap.hasData || snap.data == null) {
                      return const Text('计算失败');
                    }
                    final h = snap.data!;
                    return Column(
                      children: [
                        _row('MD5', h.md5),
                        _row('SHA1', h.sha1),
                        _row('SHA256', h.sha256),
                        _row('SHA512', h.sha512),
                        _row('CRC32', h.crc32),
                      ],
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
        const SizedBox(height: 4),
        ...children,
        const Divider(),
      ],
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
