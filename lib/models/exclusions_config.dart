import 'dart:convert';
import 'dart:io';

class ExclusionsConfig {
  static const List<String> defaultExclusions = [
    'node_modules',
    '.git',
    '.vscode',
    '.idea',
    'bin',
    'obj',
    'dist',
    'build',
    '.next',
    '*.log',
    '*.tmp',
    '.DS_Store',
    'Thumbs.db',
  ];

  static const Map<String, List<String>> presetTemplates = {
    'General': [
      '.git',
      '.vscode',
      '.idea',
      '*.log',
      '*.tmp',
      '.DS_Store',
      'Thumbs.db',
    ],
    'Web': [
      'node_modules',
      '.next',
      '.nuxt',
      '.astro',
      '.svelte-kit',
      'dist',
      'build',
      '.turbo',
      '.vercel',
      '.output',
      'bun.lockb',
      'npm-debug.log*',
    ],
    'Flutter': [
      '.dart_tool',
      '.flutter-plugins*',
      'build',
      '.pub-cache',
      'ephemeral',
    ],
    'Python': [
      '__pycache__',
      '*.pyc',
      '.venv',
      'venv',
      '.pytest_cache',
      '*.egg-info',
    ],
    'Rust': ['target', 'Cargo.lock'],
    'Go': ['vendor', 'bin', '*.exe', '*.test', '*.out'],
    'Kotlin': ['.gradle', 'build', 'out', 'target', '*.class', '.mvn'],
    'Docker': ['*.log', '.dockerignore'],
  };

  final List<String> patterns;
  final bool enabled;
  final bool gitignoreOnly;
  final List<String> gitignorePatterns;

  const ExclusionsConfig({
    required this.patterns,
    this.enabled = true,
    this.gitignoreOnly = false,
    this.gitignorePatterns = const [],
  });

  factory ExclusionsConfig.defaults() {
    return const ExclusionsConfig(patterns: defaultExclusions);
  }

  ExclusionsConfig copyWith({
    List<String>? patterns,
    bool? enabled,
    bool? gitignoreOnly,
    List<String>? gitignorePatterns,
  }) {
    return ExclusionsConfig(
      patterns: patterns ?? this.patterns,
      enabled: enabled ?? this.enabled,
      gitignoreOnly: gitignoreOnly ?? this.gitignoreOnly,
      gitignorePatterns: gitignorePatterns ?? this.gitignorePatterns,
    );
  }

  static List<String> parseRulesString(String rulesStr) {
    final list = <String>[];
    final parts = rulesStr.split(RegExp(r'[\n,]'));
    for (final raw in parts) {
      var clean = raw.trim().replaceAll(r'\', '/');
      if (clean.isEmpty) continue;

      // Strip optional leading slash unless root-only regex
      if (clean.startsWith('/') && clean.length > 1) {
        clean = clean.substring(1);
      }

      // Strip trailing slash if it is a directory pattern like "node_modules/"
      if (clean.endsWith('/') && !clean.endsWith('/*') && clean.length > 1) {
        clean = clean.substring(0, clean.length - 1);
      }

      if (clean.isNotEmpty && !list.contains(clean)) {
        list.add(clean);
      }
    }
    return list;
  }

  factory ExclusionsConfig.fromRulesString(
    String rulesStr, {
    bool enabled = true,
    bool gitignoreOnly = false,
    List<String> gitignorePatterns = const [],
  }) {
    final list = parseRulesString(rulesStr);
    return ExclusionsConfig(
      patterns: list.isEmpty ? List.from(defaultExclusions) : list,
      enabled: enabled,
      gitignoreOnly: gitignoreOnly,
      gitignorePatterns: gitignorePatterns,
    );
  }

  String toRulesString() => patterns.join(', ');

  static Future<ExclusionsConfig> loadFromFile(File configFile) async {
    try {
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final data = jsonDecode(content) as Map<String, dynamic>;
        final list = (data['exclusions'] as List<dynamic>?)
                ?.map((e) => e.toString().replaceAll(r'\', '/'))
                .toList() ??
            List.from(defaultExclusions);
        final enabled = data['enabled'] as bool? ?? true;
        final gitignoreOnly = data['gitignoreOnly'] as bool? ?? false;
        return ExclusionsConfig(
          patterns: list,
          enabled: enabled,
          gitignoreOnly: gitignoreOnly,
        );
      }
    } catch (_) {}
    return ExclusionsConfig.defaults();
  }

  Future<void> saveToFile(File configFile) async {
    final data = {
      'enabled': enabled,
      'gitignoreOnly': gitignoreOnly,
      'exclusions': patterns,
    };
    const encoder = JsonEncoder.withIndent('  ');
    await configFile.writeAsString(encoder.convert(data));
  }

  /// [name] is the bare entry name (last path segment).
  /// [relativePath] is the path relative to the scan root, using forward
  /// slashes, e.g. "build/flutter_assets". When supplied, patterns that
  /// contain a slash are matched against it in addition to the bare name.
  bool isExcluded(String name, {String? relativePath}) {
    if (gitignoreOnly) {
      if (name == '.git') return true;
      for (final pattern in gitignorePatterns) {
        if (_isFoldersOnlyPattern(pattern)) continue;
        if (_checkMatch(name, relativePath, pattern)) return true;
      }
      if (enabled) {
        for (final pattern in patterns) {
          if (_isFoldersOnlyPattern(pattern)) continue;
          if (_checkMatch(name, relativePath, pattern)) return true;
        }
      }
      return false;
    }

    if (!enabled) return false;

    for (final pattern in patterns) {
      if (_isFoldersOnlyPattern(pattern)) continue;
      if (_checkMatch(name, relativePath, pattern)) return true;
    }
    return false;
  }

  bool _checkMatch(String name, String? relativePath, String pattern) {
    if (_matchesPattern(name, pattern)) return true;

    if (relativePath != null) {
      if (_isPathPattern(pattern) && _matchesPathPattern(relativePath, pattern)) {
        return true;
      }

      // Check each folder segment in relativePath against bare pattern
      final parts = relativePath.replaceAll(r'\', '/').split('/');
      for (final part in parts) {
        if (part.isNotEmpty && _matchesPattern(part, pattern)) {
          return true;
        }
      }
    }

    return false;
  }

  static bool _isFoldersOnlyPattern(String pattern) =>
      pattern.trimRight().endsWith('/*');

  bool isFoldersOnly(String relativePath) {
    if (!enabled && !gitignoreOnly) return false;

    final rp = relativePath.replaceAll(r'\', '/').toLowerCase();

    bool check(String pattern) {
      var p = pattern.trim().replaceAll(r'\', '/');
      if (!p.endsWith('/*')) return false;
      final base = p.substring(0, p.length - 2).toLowerCase();
      final cleanBase = base.startsWith('/') ? base.substring(1) : base;
      return cleanBase == rp;
    }

    for (final pattern in patterns) {
      if (check(pattern)) return true;
    }
    return false;
  }

  static bool _isPathPattern(String pattern) =>
      pattern.contains('/') || pattern.contains(r'\');

  static List<String> parseGitignoreFile(File file) {
    try {
      if (file.existsSync()) {
        final lines = file.readAsLinesSync();
        final result = <String>[];
        for (final rawLine in lines) {
          final line = rawLine.trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          var pattern = line.replaceAll(r'\', '/');
          if (pattern.startsWith('/')) pattern = pattern.substring(1);
          if (pattern.endsWith('/') && !pattern.endsWith('/*')) {
            pattern = pattern.substring(0, pattern.length - 1);
          }
          if (pattern.isNotEmpty && !result.contains(pattern)) {
            result.add(pattern);
          }
        }
        return result;
      }
    } catch (_) {}
    return [];
  }

  static final Map<String, RegExp> _patternRegexCache = {};
  static final Map<String, RegExp> _pathPatternRegexCache = {};

  static bool _matchesPathPattern(String relativePath, String pattern) {
    var p = pattern.trim().replaceAll(r'\', '/');
    var rp = relativePath.replaceAll(r'\', '/');

    if (p.startsWith('/')) p = p.substring(1);
    if (p.endsWith('/') && !p.endsWith('/*')) p = p.substring(0, p.length - 1);
    if (p.isEmpty) return false;

    if (rp.toLowerCase() == p.toLowerCase()) return true;

    final lowerRp = rp.toLowerCase();
    final lowerP = p.toLowerCase();
    if (lowerRp.startsWith('$lowerP/')) return true;

    if (p.contains('*') || p.contains('?')) {
      final regex = _pathPatternRegexCache.putIfAbsent(p, () {
        final regexString =
            '^${RegExp.escape(p).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$';
        return RegExp(regexString, caseSensitive: false);
      });
      return regex.hasMatch(rp) || regex.hasMatch('$rp/');
    }

    return false;
  }

  static bool _matchesPattern(String text, String pattern) {
    var p = pattern.trim();
    if (p.isEmpty) return false;

    if (p.endsWith('/') && !p.endsWith('/*')) {
      p = p.substring(0, p.length - 1);
    }
    if (p.isEmpty) return false;

    // Handle extension pattern like '.svg' or '.png' -> treat as '*.svg' or '*.png'
    if (p.startsWith('.') && !p.contains('*') && !p.contains('?')) {
      if (text.toLowerCase().endsWith(p.toLowerCase())) {
        return true;
      }
    }

    if (p.toLowerCase() == text.toLowerCase()) return true;

    if (p.contains('*') || p.contains('?')) {
      final regex = _patternRegexCache.putIfAbsent(p, () {
        final regexString =
            '^${RegExp.escape(p).replaceAll(r'\*', '.*').replaceAll(r'\?', '.')}\$';
        return RegExp(regexString, caseSensitive: false);
      });
      return regex.hasMatch(text);
    }

    return text.toLowerCase() == p.toLowerCase();
  }
}
