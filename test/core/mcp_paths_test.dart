import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/core/mcp/mcp_server.dart';

import '../../bin/src/oci_mcp_io.dart';

/// The root folder of the MCP server (bin/src/oci_mcp_io.dart): what it
/// lets through and what it refuses, on the file system itself.
void main() {
  late Directory base, rootDir, outside;
  late McpRootDirectory root;

  setUp(() {
    base = Directory.systemTemp.createTempSync('oci_mcp_paths_');
    rootDir = Directory('${base.path}/root')..createSync();
    outside = Directory('${base.path}/outside')..createSync();
    File('${outside.path}/secret.txt').writeAsStringSync('secret');
    File('${rootDir.path}/a.oci.json').writeAsStringSync('{}');
    Directory('${rootDir.path}/sub').createSync();
    File('${rootDir.path}/sub/b.dxf').writeAsStringSync('0\nEOF\n');
    root = McpRootDirectory.open(rootDir.path);
  });
  tearDown(() => base.deleteSync(recursive: true));

  Matcher refused(String what) => throwsA(isA<McpToolError>().having((e) => e.message, 'message', contains(what)));

  test('the root is the real folder, links resolved', () {
    final real = rootDir.resolveSymbolicLinksSync();
    expect(root.path, real);
    // macOS keeps the temporary folder behind a link (/var → /private/var): the same root through it
    Link('${base.path}/alias').createSync(rootDir.path);
    expect(McpRootDirectory.open('${base.path}/alias').path, real);
    expect(() => McpRootDirectory.open('${base.path}/nothing'), throwsA(isA<FileSystemException>()));
  });

  test('paths inside the root, relative or absolute, a file URI, ./ and doubled separators', () {
    final a = root.resolve('a.oci.json');
    expect(a.path, 'a.oci.json');
    expect(a.exists, isTrue);
    expect(a.isDirectory, isFalse);
    expect(a.size, 2);
    expect(root.resolve('./sub//b.dxf').path, 'sub/b.dxf');
    expect(root.resolve(r'sub\b.dxf').path, 'sub/b.dxf');
    expect(root.resolve('${root.path}/sub/b.dxf').path, 'sub/b.dxf');
    expect(root.resolve(Uri.file('${root.path}/a.oci.json').toString()).path, 'a.oci.json');
    expect(root.resolve('.').path, '');
    expect(root.resolve('.').isDirectory, isTrue);
    final fresh = root.resolve('new/deeper/c.oci.json');
    expect(fresh.exists, isFalse);
    expect(fresh.path, 'new/deeper/c.oci.json');
  });

  test('traversal, absolute paths outside, "~", NUL and empty paths are refused', () {
    expect(() => root.resolve('../outside/secret.txt'), refused('".." is not allowed'));
    expect(() => root.resolve('sub/../../outside/secret.txt'), refused('".."'));
    expect(() => root.resolve(r'sub\..\a.oci.json'), refused('".."'), reason: 'even back inside');
    expect(() => root.resolve('${outside.path}/secret.txt'), refused('outside the root'));
    expect(() => root.resolve('/etc/passwd'), refused('outside the root'));
    expect(() => root.resolve(Uri.file('${outside.path}/secret.txt').toString()), refused('outside the root'));
    expect(() => root.resolve('~/secret.txt'), refused('"~"'));
    expect(() => root.resolve('a\u0000.oci.json'), refused('NUL'));
    expect(() => root.resolve('  '), refused('empty path'));
  });

  test('symbolic links that lead out are refused, those that stay inside are followed', () {
    Link('${rootDir.path}/to_secret.txt').createSync('${outside.path}/secret.txt');
    Link('${rootDir.path}/out').createSync(outside.path);
    Link('${rootDir.path}/dangling.oci.json').createSync('${base.path}/nowhere.oci.json');
    Link('${rootDir.path}/inner.oci.json').createSync('${rootDir.path}/a.oci.json');
    expect(() => root.resolve('to_secret.txt'), refused('outside the root'));
    expect(() => root.resolve('out/secret.txt'), refused('outside the root'));
    expect(() => root.resolve('out/new.oci.json'), refused('outside the root'), reason: 'a file not there yet, in a folder out of the root');
    expect(() => root.resolve('dangling.oci.json'), refused('leads nowhere'));
    final inner = root.resolve('inner.oci.json');
    expect(inner.path, 'a.oci.json', reason: 'the real file');
    expect(inner.exists, isTrue);
    // the listing leaves out the links that lead out, the dangling one and hidden files
    File('${rootDir.path}/.hidden').writeAsStringSync('x');
    Directory('${rootDir.path}/.git').createSync();
    File('${rootDir.path}/.git/config').writeAsStringSync('x');
    final listed = [for (final f in root.list(root.resolve('.'), recursive: true, limit: 100)) f.path];
    expect(listed, ['a.oci.json', 'inner.oci.json', 'sub/b.dxf']);
    expect([for (final f in root.list(root.resolve('.'), recursive: false, limit: 100)) f.path], ['a.oci.json', 'inner.oci.json']);
    expect(root.list(root.resolve('.'), recursive: true, limit: 2), hasLength(2));
  });

  test('a pipe or another special file is not read', () async {
    final fifo = '${rootDir.path}/fifo';
    final made = await Process.run('mkfifo', [fifo]);
    if (made.exitCode != 0) return; // no mkfifo here
    expect(() => root.resolve('fifo'), refused('not a regular file'));
  }, skip: Platform.isWindows);

  test('writing makes the folders, replaces the file whole and stays inside', () {
    final f = root.resolve('made/here/x.oci.json');
    root.write(f, utf8.encode('one'));
    expect(File('${rootDir.path}/made/here/x.oci.json').readAsStringSync(), 'one');
    root.write(root.resolve('made/here/x.oci.json'), utf8.encode('two'));
    expect(File('${rootDir.path}/made/here/x.oci.json').readAsStringSync(), 'two');
    expect(Directory('${rootDir.path}/made/here').listSync().map((e) => e.path.split('/').last), ['x.oci.json'], reason: 'no temporary file left');
    expect(() => root.write(root.resolve('sub'), [1]), refused('is a folder'));
    expect(root.read(root.resolve('a.oci.json'), maxBytes: 10), utf8.encode('{}'));
    expect(() => root.read(root.resolve('a.oci.json'), maxBytes: 1), refused('above the 1'));
    expect(() => root.read(root.resolve('nothing'), maxBytes: 10), refused('no such file'));
  });
}
