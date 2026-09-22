/// Announces the pages of opencadirrigation.com to IndexNow (Bing, Yandex,
/// Seznam, Naver…) after a deploy, so they are crawled again within minutes
/// instead of days; Bing's index also answers Copilot and ChatGPT search.
/// The key is `indexNowKey` in tool/site.dart, published by gen_site as
/// `web/<key>.txt`. Run once the new build is live:
///   dart run tool/indexnow.dart [--dry-run]
/// With --dry-run the request body is printed and nothing is sent.
library;

import 'dart:convert';
import 'dart:io';

import 'site.dart';

Future<void> main(List<String> args) async {
  final keyUrl = '$siteUrl$indexNowKey.txt';
  final urls = [for (final l in siteLanguages) l.url, '${siteUrl}llms.txt', '${siteUrl}llms-full.txt'];
  final body = jsonEncode({'host': Uri.parse(siteUrl).host, 'key': indexNowKey, 'keyLocation': keyUrl, 'urlList': urls});
  if (args.contains('--dry-run')) {
    stdout.writeln(body);
    return;
  }
  final client = HttpClient();
  try {
    final check = await (await client.getUrl(Uri.parse(keyUrl))).close();
    final published = (await check.transform(utf8.decoder).join()).trim();
    if (check.statusCode != 200 || published != indexNowKey) {
      stderr.writeln('$keyUrl is not live yet (HTTP ${check.statusCode}): deploy the site first.');
      exitCode = 1;
      return;
    }
    final request = await client.postUrl(Uri.parse('https://api.indexnow.org/indexnow'));
    request.headers.contentType = ContentType('application', 'json', charset: 'utf-8');
    request.write(body);
    final response = await request.close();
    final answer = (await response.transform(utf8.decoder).join()).trim();
    // 200 and 202 mean accepted (202: the key is still being validated).
    stdout.writeln('IndexNow: HTTP ${response.statusCode} for ${urls.length} URLs${answer.isEmpty ? '' : ': $answer'}');
    if (response.statusCode >= 300) exitCode = 1;
  } finally {
    client.close();
  }
}
