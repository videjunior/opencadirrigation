import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_test/flutter_test.dart';
import 'package:opencadirrigation/app/i18n.dart';

/// Runs around every test file: a file fails when the interface asked for a
/// string key the table does not have, which the user would see as the key
/// itself (as `welcome.open` once showed on every card of the welcome dialog).
/// A test that wants an unknown key on purpose clears [missingKeys].
final missingKeys = <String>{};

/// Hosts a test tried to reach beyond the loopback interface: the file fails
/// (see [LoopbackOnlyHttpOverrides]). A test that probes the guard itself
/// clears it.
final blockedHosts = <String>{};

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  onMissingI18nKey = missingKeys.add;
  // No test reaches the network: fake servers listen on the loopback
  // interface, everything else fails the file. testWidgets files swap this
  // for flutter_test's own client, which answers 400 to everything.
  // OCI_TEST_NETWORK=1 lifts the guard for a deliberate live check.
  // (In the browser suite, test/web, dart:io has no network to guard.)
  if (!kIsWeb && Platform.environment['OCI_TEST_NETWORK'] != '1') HttpOverrides.global = LoopbackOnlyHttpOverrides();
  tearDownAll(() {
    expect(missingKeys, isEmpty, reason: 'keys used by the app but missing from lib/app/i18n.dart');
    expect(
      blockedHosts,
      isEmpty,
      reason:
          'a test reached for the network (test/flutter_test_config.dart allows only the loopback interface): '
          'serve the answers from a fake or a server bound to InternetAddress.loopbackIPv4',
    );
  });
  await testMain();
}

/// Whether [host] (a URL host, IPv6 literals with or without brackets) is
/// this machine's loopback interface.
bool isLoopbackHost(String host) {
  final h = host.startsWith('[') && host.endsWith(']') ? host.substring(1, host.length - 1) : host;
  if (h == 'localhost' || h.endsWith('.localhost')) return true;
  return InternetAddress.tryParse(h)?.isLoopback ?? false;
}

/// [HttpClient]s that connect only to the loopback interface: a request to
/// any other host fails with a [SocketException] naming the guard, and the
/// host is recorded in [blockedHosts] so that the file fails even when the
/// code under test swallows the error (as the offline paths do).
class LoopbackOnlyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.connectionFactory = (uri, proxyHost, proxyPort) {
      if (!isLoopbackHost(uri.host)) {
        blockedHosts.add(uri.host);
        return Future.error(SocketException('network access to ${uri.host} is blocked in tests (test/flutter_test_config.dart): use a fake or a loopback server'));
      }
      final host = proxyHost ?? uri.host;
      final port = proxyPort ?? uri.port;
      // through a proxy the client tunnels and secures the plain socket itself
      return uri.scheme == 'https' && proxyHost == null ? SecureSocket.startConnect(host, port, context: context) : Socket.startConnect(host, port);
    };
    return client;
  }
}
