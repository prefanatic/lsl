// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

const liblslVersion = '1.17.7';
const pugixmlVersion = '1.15';

const sourceArchives = [
  SourceArchive(
    name: 'liblsl-$liblslVersion',
    url:
        'https://codeload.github.com/sccn/liblsl/tar.gz/refs/tags/v$liblslVersion',
    hash: '19604fb1b30c753457e8bf1430341d84012834c0cf8d2ca921e8151d31220df9',
  ),
  SourceArchive(
    name: 'pugixml-$pugixmlVersion',
    url:
        'https://codeload.github.com/zeux/pugixml/tar.gz/refs/tags/v$pugixmlVersion',
    hash: 'b39647064d9e28297a34278bfb897092bf33b7c487906ddfc094c9e8868bddcb',
  ),
];

/// A pinned source archive for the native build.
class SourceArchive {
  const SourceArchive({
    required this.name,
    required this.url,
    required this.hash,
  });

  final String name;
  final String url;
  final String hash;

  /// Fetches and verifies an archive before it writes any source files.
  Future<Directory> prepare(
    Directory cache, {
    Directory? offlineArchives,
    Directory? sourceDirectory,
  }) async {
    await cache.create(recursive: true);
    final archive = File.fromUri(
      (offlineArchives ?? cache).uri.resolve('$name.tar.gz'),
    );
    if (!await archive.exists()) {
      if (offlineArchives != null) {
        throw FileSystemException(
          'Missing offline source archive',
          archive.path,
        );
      }
      await _download(Uri.parse(url), archive, hash);
    }
    final bytes = await archive.readAsBytes();
    verifyHash(bytes, hash);
    final root =
        sourceDirectory ?? Directory.fromUri(cache.uri.resolve('sources/'));
    await root.create(recursive: true);
    final contents = TarDecoder().decodeBytes(GZipDecoder().decodeBytes(bytes));
    for (final entry in contents.files) {
      final segments = entry.name.split('/');
      if (segments.first != name ||
          segments.any((part) => part == '..' || part.contains('\\')) ||
          entry.isSymbolicLink) {
        throw FormatException('Unsafe source archive entry: ${entry.name}');
      }
      if (!entry.isFile) continue;
      final file = File.fromUri(
        root.uri.resolve(segments.map(Uri.encodeComponent).join('/')),
      );
      await file.parent.create(recursive: true);
      if (!await file.exists() ||
          sha256.convert(await file.readAsBytes()) !=
              sha256.convert(entry.content)) {
        await file.writeAsBytes(entry.content);
      }
    }
    return Directory.fromUri(root.uri.resolve('$name/'));
  }
}

void verifyHash(List<int> bytes, String expected) {
  final actual = sha256.convert(bytes).toString();
  if (actual != expected) {
    throw StateError(
      'Source archive SHA-256 mismatch: $actual; expected $expected.',
    );
  }
}

Future<void> _download(Uri uri, File destination, String expectedHash) async {
  final client = HttpClient()
    ..findProxy = HttpClient.findProxyFromEnvironment
    ..connectionTimeout = const Duration(seconds: 30);
  final temporary = File('${destination.path}.$pid.tmp');
  try {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 30));
    final response = await request.close().timeout(const Duration(seconds: 30));
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Source download returned HTTP ${response.statusCode}',
        uri: uri,
      );
    }
    await response
        .timeout(const Duration(seconds: 60))
        .pipe(temporary.openWrite());
    verifyHash(await temporary.readAsBytes(), expectedHash);
    await temporary.rename(destination.path);
  } finally {
    client.close(force: true);
    if (await temporary.exists()) await temporary.delete();
  }
}
