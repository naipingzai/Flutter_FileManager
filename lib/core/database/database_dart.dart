import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart';

/// 纯 Dart 数据库实现（sqlite3 包，替代原 C++ database.cpp FFI）。
///
/// 接口与旧的 DatabaseNative 保持一致（方法名、返回类型），
/// 因此 DatabaseService 及上层页面无需改动。所有数据以
/// Map / List[Map] 形式返回。
class DatabaseDart {
  Database? _db;
  String _dataDir = '';

  /// 打开/初始化数据库（建表）。dataDir 为数据库目录（files.db 与其 files/ 副本所在）。
  String? init(String dataDir) {
    try {
      _dataDir = dataDir;
      Directory('$dataDir/files').createSync(recursive: true);
      _db?.close();
      _db = sqlite3.open(p.join(dataDir, 'files.db'));
      _db!.execute(
        'CREATE TABLE IF NOT EXISTS files('
        ' id INTEGER PRIMARY KEY AUTOINCREMENT,'
        ' uuid TEXT, name TEXT NOT NULL, ext TEXT, mime TEXT,'
        ' size INTEGER DEFAULT 0, internal_path TEXT, source_path TEXT,'
        ' source_type TEXT, is_dir INTEGER DEFAULT 0, parent_id INTEGER DEFAULT 0,'
        ' import_time INTEGER, deleted INTEGER DEFAULT 0);'
        'CREATE TABLE IF NOT EXISTS tags('
        ' id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT UNIQUE NOT NULL,'
        ' color TEXT, builtin INTEGER DEFAULT 0);'
        'CREATE TABLE IF NOT EXISTS file_tags('
        ' file_id INTEGER NOT NULL, tag_id INTEGER NOT NULL,'
        ' PRIMARY KEY(file_id, tag_id));',
      );
      debugPrint('[DB] init OK: $dataDir');
      return null;
    } catch (e, st) {
      debugPrint('[DB] init FAILED: $e\n$st');
      return e.toString();
    }
  }

  int get _lastInsertId => _db!.lastInsertRowId;

  int get _nowEpoch =>
      DateTime.now().millisecondsSinceEpoch ~/ 1000;

  String _ext(String name) {
    final idx = name.lastIndexOf('.');
    if (idx <= 0 || idx == name.length - 1) return '';
    return name.substring(idx + 1).toLowerCase();
  }

  String _mime(String ext) {
    const map = {
      'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'gif': 'image/gif', 'webp': 'image/webp', 'bmp': 'image/bmp',
      'mp4': 'video/mp4', 'mkv': 'video/x-matroska', 'mov': 'video/quicktime',
      'webm': 'video/webm', 'avi': 'video/x-msvideo',
      'mp3': 'audio/mpeg', 'wav': 'audio/wav', 'flac': 'audio/flac',
      'aac': 'audio/aac', 'ogg': 'audio/ogg', 'm4a': 'audio/mp4',
      'zip': 'application/zip', 'epub': 'application/epub+zip',
      'pdf': 'application/pdf', 'txt': 'text/plain', 'md': 'text/markdown',
      'json': 'application/json', 'xml': 'application/xml', 'csv': 'text/csv',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  String _defaultTag(String ext) {
    const map = {
      'png': '图片', 'jpg': '图片', 'jpeg': '图片', 'gif': '图片',
      'mp4': '视频', 'mkv': '视频', 'mov': '视频', 'webm': '视频',
      'mp3': '音频', 'wav': '音频', 'flac': '音频', 'aac': '音频',
      'zip': '压缩包', 'rar': '压缩包', 'tar': '压缩包', 'gz': '压缩包',
      'epub': '电子书', 'mobi': '电子书', 'pdf': '文档', 'doc': '文档',
      'c': '代码', 'cpp': '代码', 'py': '代码', 'dart': '代码',
    };
    return map[ext] ?? '其他';
  }

  // ---- 查询辅助 ----

  List<Map<String, dynamic>> _queryFiles(String sql, [List<Object?> args = const []]) {
    final stmt = _db!.prepare(sql);
    try {
      final rows = <Map<String, dynamic>>[];
      for (final row in stmt.select(args)) {
        final f = {
          'id': row['id'],
          'name': row['name'],
          'ext': row['ext'],
          'mime': row['mime'],
          'size': row['size'],
          'path': row['internal_path'],
          'source': row['source_path'],
          'sourceType': row['source_type'],
          'isDir': row['is_dir'],
          'parentId': row['parent_id'],
          'importTime': row['import_time'],
          'deleted': row['deleted'],
          'tags': _fileTags(row['id'] as int),
        };
        rows.add(f);
      }
      return rows;
    } finally {
      stmt.close();
    }
  }

  List<Map<String, dynamic>> _fileTags(int fileId) {
    final stmt = _db!.prepare(
        'SELECT t.id,t.name,t.color FROM file_tags ft JOIN tags t ON t.id=ft.tag_id WHERE ft.file_id=?');
    try {
      return stmt
          .select([fileId])
          .map((r) => {'id': r['id'], 'name': r['name'], 'color': r['color']})
          .toList();
    } finally {
      stmt.close();
    }
  }

  // ---- 标签工具 ----

  int _ensureTag(String name) {
    final sel = _db!.prepare('SELECT id FROM tags WHERE name=?');
    try {
      final r = sel.select([name]);
      if (r.isNotEmpty) return r.first['id'] as int;
    } finally {
      sel.close();
    }
    _db!.execute('INSERT INTO tags(name,color,builtin) VALUES(?,?,0)', [name, '']);
    return _lastInsertId;
  }

  // ============================================================
  // FFI 兼容接口（与 DatabaseNative 方法签名一致）
  // ============================================================

  Map<String, dynamic>? importFile(String src, [String defaultTags = '']) {
    try {
      final srcPath = src;
      final name = p.basename(srcPath);
      final ext = _ext(name);
      final uuid = '${_nowEpoch}_$name';
      final dest = '$_dataDir/files/$uuid';
      File(srcPath).copySync(dest);
      final size = File(srcPath).lengthSync();

      _db!.execute(
        'INSERT INTO files(uuid,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted)'
        ' VALUES(?,?,?,?,?,?,?,?,0,0,?,0)',
        [uuid, name, ext, _mime(ext), size, dest, src, 'filesystem', _nowEpoch],
      );
      final fid = _lastInsertId;
      _linkDefaultTags(fid, defaultTags);
      return _queryFiles('SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE id=?', [fid]).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  void _linkDefaultTags(int fileId, String defaultTags) {
    if (defaultTags.isEmpty) return;
    for (final t in defaultTags.split(',')) {
      final name = t.trim();
      if (name.isEmpty) continue;
      final tid = _ensureTag(name);
      _db!.execute('INSERT OR IGNORE INTO file_tags(file_id,tag_id) VALUES(?,?)', [fileId, tid]);
    }
  }

  List<Map<String, dynamic>> listFiles([int parentId = -1]) {
    if (parentId < 0) {
      return _queryFiles('SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE deleted=0');
    }
    return _queryFiles(
        'SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE deleted=0 AND parent_id=?',
        [parentId]);
  }

  List<Map<String, dynamic>> search(String query) {
    if (query.isEmpty) return listFiles(-1);
    final esc = query.replaceAll('\\', '\\\\').replaceAll('%', '\\%').replaceAll('_', '\\_');
    return _queryFiles(
        "SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE deleted=0 AND name LIKE ? ESCAPE '\\'",
        ['%$esc%']);
  }

  ({int imported, int failed})? importDir(String dir, [String defaultTags = '']) {
    var imported = 0, failed = 0;
    try {
      final entries = <FileSystemEntity>[];
      _walk(dir, entries);
      for (final e in entries) {
        if (e is File) {
          final ok = importFile(e.path, defaultTags);
          if (ok != null) {
            imported++;
          } else {
            failed++;
          }
        }
      }
      return (imported: imported, failed: failed);
    } catch (_) {
      return null;
    }
  }

  void _walk(String dir, List<FileSystemEntity> out) {
    final d = Directory(dir);
    if (!d.existsSync()) return;
    for (final e in d.listSync(recursive: true, followLinks: false)) {
      try {
        if (e is File || e is Directory) out.add(e);
      } catch (_) {}
    }
  }

  Map<String, dynamic>? stats() {
    var files = 0, dirs = 0, size = 0, img = 0, vid = 0, aud = 0, doc = 0, other = 0;
    final rows = _queryFiles(
        'SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE deleted=0');
    for (final f in rows) {
      if ((f['isDir'] ?? 0) == 1) {
        dirs++;
        continue;
      }
      files++;
      size += (f['size'] ?? 0) as int;
      switch (_defaultTag((f['ext'] ?? '') as String)) {
        case '图片': img++;
        case '视频': vid++;
        case '音频': aud++;
        case '文档': doc++;
        case '电子书': doc++;
        default: other++;
      }
    }
    final byTag = <Map<String, dynamic>>[];
    final tc = tagCounts();
    for (final t in tc) {
      byTag.add({'name': t['name'], 'count': t['count']});
    }
    return {
      'files': files, 'dirs': dirs, 'size': size,
      'byType': {'image': img, 'video': vid, 'audio': aud, 'doc': doc, 'other': other},
      'byTag': byTag,
    };
  }

  List<Map<String, dynamic>> listAll() => listFiles(-1);

  Map<String, dynamic>? mkdir(String name, int parentId) {
    try {
      _db!.execute(
        "INSERT INTO files(uuid,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted)"
        " VALUES('dir',?, '', 'inode/directory', 0, '', '', 'internal', 1, ?, ?, 0)",
        [name, parentId, _nowEpoch],
      );
      final id = _lastInsertId;
      return _queryFiles('SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE id=?', [id]).firstOrNull;
    } catch (_) {
      return null;
    }
  }

  String? move(int fileId, int newParentId) {
    _db!.execute('UPDATE files SET parent_id=? WHERE id=?', [newParentId, fileId]);
    return null;
  }

  String? rename(int fileId, String name) {
    if (name.isEmpty) return 'empty name';
    _db!.execute('UPDATE files SET name=? WHERE id=?', [name, fileId]);
    return null;
  }

  String? delete(int fileId) {
    _db!.execute('UPDATE files SET deleted=1 WHERE id=?', [fileId]);
    return null;
  }

  List<Map<String, dynamic>> listDeleted() {
    return _queryFiles('SELECT id,name,ext,mime,size,internal_path,source_path,source_type,is_dir,parent_id,import_time,deleted FROM files WHERE deleted=1');
  }

  String? restore(int fileId) {
    _db!.execute('UPDATE files SET deleted=0 WHERE id=?', [fileId]);
    return null;
  }

  String? purge(int fileId) {
    final sel = _db!.prepare('SELECT internal_path,is_dir FROM files WHERE id=?');
    String? ipath;
    try {
      final r = sel.select([fileId]);
      if (r.isNotEmpty && (r.first['is_dir'] ?? 0) == 0) {
        ipath = r.first['internal_path'] as String?;
      }
    } finally {
      sel.close();
    }
    if (ipath != null && ipath.isNotEmpty) {
      try {
        File(ipath).deleteSync();
      } catch (_) {}
    }
    _db!.execute('DELETE FROM file_tags WHERE file_id=?', [fileId]);
    _db!.execute('DELETE FROM files WHERE id=?', [fileId]);
    return null;
  }

  String? emptyTrash() {
    final sel = _db!.prepare('SELECT id,internal_path,is_dir FROM files WHERE deleted=1');
    final rows = sel.select().toList();
    sel.close();
    for (final r in rows) {
      final fid = r['id'] as int;
      if ((r['is_dir'] ?? 0) == 0) {
        final ipath = r['internal_path'] as String?;
        if (ipath != null && ipath.isNotEmpty) {
          try {
            File(ipath).deleteSync();
          } catch (_) {}
        }
      }
      _db!.execute('DELETE FROM file_tags WHERE file_id=?', [fid]);
      _db!.execute('DELETE FROM files WHERE id=?', [fid]);
    }
    return null;
  }

  String? exportFile(int fileId, String dest) {
    final sel = _db!.prepare('SELECT internal_path,is_dir FROM files WHERE id=?');
    String? ipath;
    try {
      final r = sel.select([fileId]);
      if (r.isNotEmpty && (r.first['is_dir'] ?? 0) == 0) {
        ipath = r.first['internal_path'] as String?;
      }
    } finally {
      sel.close();
    }
    if (ipath == null || ipath.isEmpty) return 'not found or is dir';
    try {
      File(ipath).copySync(dest);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  // ---- 标签 ----

  List<Map<String, dynamic>> tagList() {
    final stmt = _db!.prepare('SELECT id,name,color,builtin FROM tags ORDER BY name');
    try {
      return stmt
          .select()
          .map((r) => {'id': r['id'], 'name': r['name'], 'color': r['color'], 'builtin': r['builtin']})
          .toList();
    } finally {
      stmt.close();
    }
  }

  List<Map<String, dynamic>> tagCounts() {
    final stmt = _db!.prepare(
        'SELECT t.id,t.name,t.color,COUNT(ft.file_id) AS cnt FROM tags t'
        ' LEFT JOIN file_tags ft ON ft.tag_id=t.id GROUP BY t.id ORDER BY t.name');
    try {
      return stmt
          .select()
          .map((r) => {'id': r['id'], 'name': r['name'], 'color': r['color'], 'count': r['cnt']})
          .toList();
    } finally {
      stmt.close();
    }
  }

  String? tagRename(int tagId, String name) {
    if (name.isEmpty) return 'empty name';
    _db!.execute('UPDATE tags SET name=? WHERE id=?', [name, tagId]);
    return null;
  }

  String? tagColor(int tagId, String color) {
    _db!.execute('UPDATE tags SET color=? WHERE id=?', [color, tagId]);
    return null;
  }

  Map<String, dynamic>? tagCreate(String name, [String color = '']) {
    if (name.isEmpty) return {'error': 'empty name'};
    final sel = _db!.prepare('SELECT id FROM tags WHERE name=?');
    try {
      if (sel.select([name]).isNotEmpty) return {'error': 'exists'};
    } finally {
      sel.close();
    }
    try {
      _db!.execute('INSERT INTO tags(name,color,builtin) VALUES(?,?,0)', [name, color]);
      final id = _lastInsertId;
      return {'id': id, 'name': name};
    } catch (_) {
      return {'error': 'create failed'};
    }
  }

  int tagAddToFiles(List<int> fileIds, List<int> tagIds) {
    var added = 0;
    for (final fid in fileIds) {
      for (final tid in tagIds) {
        try {
          _db!.execute('INSERT OR IGNORE INTO file_tags(file_id,tag_id) VALUES(?,?)', [fid, tid]);
          if (_db!.updatedRows > 0) added++;
        } catch (_) {}
      }
    }
    return added;
  }

  String? tagRemoveFromFile(int fileId, int tagId) {
    _db!.execute('DELETE FROM file_tags WHERE file_id=? AND tag_id=?', [fileId, tagId]);
    return null;
  }

  String? tagDelete(int tagId) {
    _db!.execute('DELETE FROM file_tags WHERE tag_id=?', [tagId]);
    _db!.execute('DELETE FROM tags WHERE id=?', [tagId]);
    return null;
  }

  List<Map<String, dynamic>> filesByTag(int tagId) {
    return _queryFiles(
        'SELECT f.id,f.name,f.ext,f.mime,f.size,f.internal_path,f.source_path,f.source_type,f.is_dir,f.parent_id,f.import_time,f.deleted'
        ' FROM files f JOIN file_tags ft ON ft.file_id=f.id WHERE ft.tag_id=? AND f.deleted=0',
        [tagId]);
  }

  List<Map<String, dynamic>> fileTags(int fileId) {
    final stmt = _db!.prepare(
        'SELECT t.id,t.name FROM file_tags ft JOIN tags t ON t.id=ft.tag_id WHERE ft.file_id=?');
    try {
      return stmt
          .select([fileId])
          .map((r) => {'id': r['id'], 'name': r['name']})
          .toList();
    } finally {
      stmt.close();
    }
  }
}
