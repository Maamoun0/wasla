import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ENGINEERING_STANDARDS Rule 4.1: only repositories talk to Supabase.
/// Allowed elsewhere: the client provider itself, app start-up, and the push
/// service (static, runs before any provider exists).
void main() {
  const allowed = {
    'lib/core/supabase/supabase_client_provider.dart',
    'lib/core/supabase/push_notification_service.dart',
    'lib/main.dart',
  };
  final direct = RegExp(
      r"supabaseClientProvider|Supabase\.instance|\.from\('|\.rpc\(|\.rpc<|functions\.invoke|\.storage\.|\.channel\(");

  test('no Supabase access outside lib/data/repositories', () {
    final offenders = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>()) {
      final path = file.path.replaceAll(r'\', '/');
      if (!path.endsWith('.dart') || path.endsWith('.g.dart')) continue;
      if (path.startsWith('lib/data/repositories/') || allowed.contains(path)) continue;
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i].trimLeft();
        if (line.startsWith('//') || line.startsWith('///') || line.startsWith('export ')) continue;
        if (direct.hasMatch(line)) offenders.add('$path:${i + 1}: $line');
      }
    }
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });
}
