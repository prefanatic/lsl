// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:lsl/src/hook_helpers/sources.dart';
import 'package:test/test.dart';

import '../../hook/build.dart' show validateTarget;

import 'package:code_assets/code_assets.dart';

void main() {
  test('supports each native target and rejects unsupported targets', () {
    for (final os in [OS.macOS, OS.linux, OS.windows, OS.iOS]) {
      for (final arch in [Architecture.arm64, Architecture.x64]) {
        validateTarget(os, arch);
      }
    }
    for (final arch in [
      Architecture.arm,
      Architecture.arm64,
      Architecture.x64,
    ]) {
      validateTarget(OS.android, arch);
    }
    expect(
      () => validateTarget(OS.linux, Architecture.riscv64),
      throwsUnsupportedError,
    );
    expect(
      () => validateTarget(OS.macOS, Architecture.arm),
      throwsUnsupportedError,
    );
  });

  test('hash checks reject altered archives', () {
    final bytes = utf8.encode('source');
    verifyHash(bytes, sha256.convert(bytes).toString());
    expect(() => verifyHash(bytes, '0' * 64), throwsStateError);
  });

  test('offline archives require the pinned hash and no network', () async {
    final temp = await Directory.systemTemp.createTemp('lsl-source-test-');
    addTearDown(() => temp.delete(recursive: true));
    final archive = Archive()
      ..add(ArchiveFile.string('test-src/src/file.cpp', 'source'));
    final bytes = GZipEncoder().encode(TarEncoder().encode(archive));
    final spec = SourceArchive(
      name: 'test-src',
      url: 'https://invalid.example/',
      hash: sha256.convert(bytes).toString(),
    );
    await File.fromUri(temp.uri.resolve('test-src.tar.gz')).writeAsBytes(bytes);
    final cache = Directory.fromUri(temp.uri.resolve('cache/'));
    final root = await spec.prepare(cache, offlineArchives: temp);
    expect(
      await File.fromUri(root.uri.resolve('src/file.cpp')).readAsString(),
      'source',
    );
    final firstModified = await File.fromUri(root.uri.resolve('src/file.cpp'))
        .lastModified();
    await spec.prepare(cache, offlineArchives: temp);
    expect(
      await File.fromUri(root.uri.resolve('src/file.cpp')).lastModified(),
      firstModified,
    );
    await File.fromUri(temp.uri.resolve('test-src.tar.gz'))
        .writeAsString('corrupt');
    await expectLater(
      spec.prepare(cache, offlineArchives: temp),
      throwsStateError,
    );
    await expectLater(
      spec.prepare(cache, offlineArchives: cache),
      throwsA(isA<FileSystemException>()),
    );
  });

  test('archive paths cannot escape the extraction directory', () async {
    final temp = await Directory.systemTemp.createTemp('lsl-source-test-');
    addTearDown(() => temp.delete(recursive: true));
    final archive = Archive()
      ..add(ArchiveFile.string('test-src/../../escape.cpp', 'source'));
    final bytes = GZipEncoder().encode(TarEncoder().encode(archive));
    await File.fromUri(temp.uri.resolve('test-src.tar.gz')).writeAsBytes(bytes);
    final spec = SourceArchive(
      name: 'test-src',
      url: 'https://invalid.example/',
      hash: sha256.convert(bytes).toString(),
    );
    await expectLater(
      spec.prepare(temp, offlineArchives: temp),
      throwsFormatException,
    );
    expect(
      await File.fromUri(temp.uri.resolve('escape.cpp')).exists(),
      isFalse,
    );
  });

  test(
    'downloads are cached and HTTP failures do not leave partial files',
    () async {
      final temp = await Directory.systemTemp.createTemp('lsl-source-test-');
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() async {
        await server.close(force: true);
        await temp.delete(recursive: true);
      });
      final bytes = GZipEncoder().encode(
        TarEncoder().encode(
          Archive()..add(ArchiveFile.string('test-src/file.cpp', 'source')),
        ),
      );
      var requests = 0;
      server.listen((request) async {
        requests++;
        if (request.uri.path == '/fail') {
          request.response.statusCode = 503;
        } else if (request.uri.path == '/corrupt') {
          request.response.add([1, 2, 3]);
        } else {
          request.response.add(bytes);
        }
        await request.response.close();
      });
      final spec = SourceArchive(
        name: 'test-src',
        url: 'http://127.0.0.1:${server.port}/source',
        hash: sha256.convert(bytes).toString(),
      );
      await spec.prepare(temp);
      await spec.prepare(temp);
      expect(requests, 1);
      final failed = SourceArchive(
        name: 'failed',
        url: 'http://127.0.0.1:${server.port}/fail',
        hash: '0' * 64,
      );
      await expectLater(failed.prepare(temp), throwsA(isA<HttpException>()));
      final corrupt = SourceArchive(
        name: 'corrupt',
        url: 'http://127.0.0.1:${server.port}/corrupt',
        hash: spec.hash,
      );
      await expectLater(corrupt.prepare(temp), throwsStateError);
      expect(
        await File.fromUri(temp.uri.resolve('corrupt.tar.gz')).exists(),
        isFalse,
      );

      expect(
        await File.fromUri(temp.uri.resolve('failed.tar.gz')).exists(),
        isFalse,
      );
      expect(
        await temp.list().any((file) => file.path.endsWith('.tmp')),
        isFalse,
      );
    },
  );
}
