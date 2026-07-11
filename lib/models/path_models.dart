import 'mime_type.dart';

// Port of filelist/BreadcrumbData.kt
class BreadcrumbData {
  final List<String> paths;
  final List<String> names;
  final int selectedIndex;

  const BreadcrumbData({
    required this.paths,
    required this.names,
    required this.selectedIndex,
  });

  static BreadcrumbData fromPath(String path, {String? homeLabel}) {
    final parts = _pathParts(path);
    final names = parts
        .map((p) => p == '/' ? (homeLabel ?? '/') : fileName(p))
        .toList();
    return BreadcrumbData(
      paths: parts,
      names: names,
      selectedIndex: parts.length - 1,
    );
  }

  static List<String> _pathParts(String path) {
    if (path == '/') return ['/'];
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final result = <String>['/'];
    String accum = '';
    for (final s in segments) {
      accum += '/$s';
      result.add(accum);
    }
    return result;
  }
}

// Port of filelist/TrailData.kt
class TrailData {
  final List<String> trail;
  final List<Object?> states;
  final int currentIndex;

  const TrailData._(this.trail, this.states, this.currentIndex);

  factory TrailData.of(String path) {
    final trail = _createTrail(path);
    final states = List<Object?>.filled(trail.length, null);
    return TrailData._(trail, states, trail.length - 1);
  }

  TrailData? navigateUp() {
    if (currentIndex == 0) return null;
    return TrailData._(trail, states, currentIndex - 1);
  }

  TrailData navigateTo(String path, {Object? lastState}) {
    final newTrail = _createTrail(path);
    final newStates = List<Object?>.filled(newTrail.length, null);
    var isPrefix = true;
    for (var index = 0; index < newTrail.length; index++) {
      if (isPrefix && index < trail.length) {
        if (newTrail[index] == trail[index]) {
          newStates[index] = (index != currentIndex)
              ? states[index]
              : lastState;
        } else {
          isPrefix = false;
          newStates[index] = null;
        }
      } else {
        newStates[index] = null;
      }
    }
    return TrailData._(newTrail, newStates, newTrail.length - 1);
  }

  Object? get pendingState {
    final state = states[currentIndex];
    states[currentIndex] = null;
    return state;
  }

  String get currentPath => trail[currentIndex];

  static List<String> _createTrail(String path) {
    final segments = path.split('/').where((s) => s.isNotEmpty).toList();
    final trail = <String>[];
    String accum = '';
    for (final s in segments) {
      accum += '/$s';
      trail.add(accum);
    }
    if (trail.isEmpty) trail.add('/');
    return trail;
  }
}

// Port of filelist/PathExtensions.kt helpers
String pathName(String path) =>
    path.isEmpty || path == '/' ? '/' : fileName(path);

String fileName(String path) {
  if (path == '/') return '/';
  final idx = path.lastIndexOf('/');
  return idx < 0 ? path : path.substring(idx + 1);
}

String parentPath(String path) {
  if (path == '/' || path.isEmpty) return '/';
  final idx = path.lastIndexOf('/');
  return idx <= 0 ? '/' : path.substring(0, idx);
}

String toUserFriendlyString(String path) => path;

bool isArchiveFile(String path, MimeType mimeType) {
  if (path.isEmpty) return false;
  return !path.contains(':') && mimeType.isSupportedArchive;
}

bool isLocalPath(String path) => true;

bool isRemotePath(String path) => false;
