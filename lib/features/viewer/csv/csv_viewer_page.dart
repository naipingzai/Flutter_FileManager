import 'package:flutter/material.dart';
import 'package:flutter_file_manager/core/services/file_service.dart';

/// CSV 查看器
class CsvViewerPage extends StatefulWidget {
  final String path;
  const CsvViewerPage({super.key, required this.path});

  @override
  State<CsvViewerPage> createState() => _CsvViewerPageState();
}

class _CsvViewerPageState extends State<CsvViewerPage> {
  List<List<String>> _rows = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = FileService().readCsvFile(widget.path);
      setState(() {
        _rows = rows;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(FileService.getFileName(widget.path))),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.table_rows_outlined,
                      size: 48,
                      color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(height: 12),
                  Text('无法解析 CSV',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: _rows.first
                    .map((h) => DataColumn(label: Text(h)))
                    .toList(),
                rows: _rows
                    .skip(1)
                    .map(
                      (row) => DataRow(
                        cells: row.map((c) => DataCell(Text(c))).toList(),
                      ),
                    )
                    .toList(),
              ),
            ),
    );
  }
}
