import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../support/toolchain.dart';

/// `dart run bin/oci.dart mcp --root <folder>` as an AI application starts
/// it: a real process, messages on its stdin and stdout, logs on stderr,
/// and it ends when its stdin closes.
void main() {
  final sdk = FlutterSdk.current();

  test(
    'the real process answers a discovery, a handshake and a tool call, then ends with its input',
    () async {
      final tmp = Directory.systemTemp.createTempSync('oci_mcp_proc_');
      try {
        final p = await Process.start(sdk!.dart, ['run', 'bin/oci.dart', 'mcp', '--root', tmp.path]);
        final lines = p.stdout.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
        final errors = StringBuffer();
        p.stderr.transform(utf8.decoder).listen(errors.write);
        Future<Map<String, dynamic>> answer(Object id) => lines.map((l) => jsonDecode(l) as Map<String, dynamic>).firstWhere((m) => m['id'] == id).timeout(const Duration(minutes: 3));
        void send(Map<String, Object?> m) => p.stdin.writeln(jsonEncode(m));

        // a client of both kinds probes first
        final discovered = answer('d');
        send({
          'jsonrpc': '2.0',
          'id': 'd',
          'method': 'server/discover',
          'params': {
            '_meta': {'io.modelcontextprotocol/protocolVersion': '2026-07-28', 'io.modelcontextprotocol/clientCapabilities': {}},
          },
        });
        final d = (await discovered)['result'] as Map<String, dynamic>;
        expect(d['supportedVersions'], contains('2026-07-28'));
        expect(((d['_meta'] as Map)['io.modelcontextprotocol/serverInfo'] as Map)['name'], 'opencadirrigation');

        // a client of the handshake revision
        final initialized = answer(1);
        send({
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'initialize',
          'params': {
            'protocolVersion': '2025-11-25',
            'capabilities': {},
            'clientInfo': {'name': 'process-test', 'version': '1'},
          },
        });
        expect(((await initialized)['result'] as Map)['protocolVersion'], '2025-11-25');
        send({'jsonrpc': '2.0', 'method': 'notifications/initialized'});
        final listed = answer(2);
        send({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list'});
        expect(((await listed)['result']['tools'] as List).length, 21);
        final copied = answer(3);
        send({
          'jsonrpc': '2.0',
          'id': 3,
          'method': 'tools/call',
          'params': {
            'name': 'copy_example',
            'arguments': {'example': 'orchard', 'out': 'orchard.oci.json'},
          },
        });
        final r = (await copied)['result'] as Map<String, dynamic>;
        expect(r['isError'], isFalse, reason: '${r['content']}');
        expect(File('${tmp.path}/orchard.oci.json').existsSync(), isTrue);

        await p.stdin.close();
        expect(await p.exitCode.timeout(const Duration(minutes: 1)), 0);
        expect('$errors', contains('oci mcp: '), reason: 'the logs go to stderr');
      } finally {
        tmp.deleteSync(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 5)),
    skip: sdk == null ? 'run through flutter test (FLUTTER_ROOT)' : false,
  );
}
