// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:lsl/src/hook_helpers/sources.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> arguments) async {
  await build(arguments, (input, output) async {
    if (!input.config.buildCodeAssets) return;
    final os = input.config.code.targetOS;
    final arch = input.config.code.targetArchitecture;
    validateTarget(os, arch);
    final offline = input.userDefines.path('source_archives');
    final roots = <Directory>[];
    for (final archive in sourceArchives) {
      roots.add(
        await archive.prepare(
          Directory.fromUri(input.outputDirectoryShared),
          // Each target extracts into its own directory to prevent concurrent writes.
          sourceDirectory: Directory.fromUri(
            input.outputDirectory.resolve('sources/'),
          ),
          offlineArchives: offline == null ? null : Directory.fromUri(offline),
        ),
      );
      if (offline != null) {
        output.dependencies.add(
          Directory.fromUri(offline).uri.resolve('${archive.name}.tar.gz'),
        );
      }
    }
    final lsl = roots[0].uri;
    final pugi = roots[1].uri;
    // This list follows upstream cmake/SourceFiles.cmake for liblsl 1.17.7.
    const sources = [
      'api_config.cpp',
      'cancellation.cpp',
      'common.cpp',
      'consumer_queue.cpp',
      'data_receiver.cpp',
      'info_receiver.cpp',
      'inlet_connection.cpp',
      'lsl_resolver_c.cpp',
      'lsl_inlet_c.cpp',
      'lsl_outlet_c.cpp',
      'lsl_streaminfo_c.cpp',
      'lsl_xml_element_c.cpp',
      'netinterfaces.cpp',
      'resolver_impl.cpp',
      'resolve_attempt_udp.cpp',
      'sample.cpp',
      'send_buffer.cpp',
      'socket_utils.cpp',
      'stream_info_impl.cpp',
      'stream_outlet_impl.cpp',
      'tcp_server.cpp',
      'time_postprocessor.cpp',
      'time_receiver.cpp',
      'udp_server.cpp',
      'util/cast.cpp',
      'util/endian.cpp',
      'util/inireader.cpp',
      'util/strfuns.cpp',
      'buildinfo.cpp',
    ];
    await CBuilder.library(
      name: 'lsl',
      assetName: 'src/third_party/liblsl.g.dart',
      language: Language.cpp,
      std: 'c++17',
      cppLinkStdLib: os == OS.android ? 'c++_static' : null,
      sources: [
        for (final source in sources) lsl.resolve('src/$source').toFilePath(),
        lsl.resolve('thirdparty/loguru/loguru.cpp').toFilePath(),
        pugi.resolve('src/pugixml.cpp').toFilePath(),
      ],
      includes: [
        for (final path in [
          'include/',
          'lslboost/',
          'thirdparty/loguru/',
          'thirdparty/asio/',
        ])
          lsl.resolve(path).toFilePath(),
        pugi.resolve('src/').toFilePath(),
      ],
      defines: {
        'LIBLSL_EXPORTS': null,
        'BOOST_ALL_NO_LIB': null,
        'ASIO_NO_DEPRECATED': null,
        'ASIO_DISABLE_VISIBILITY': null,
        'LOGURU_DEBUG_LOGGING': '0',
        'LOGURU_STACKTRACES': '0',
        'LSL_LIBRARY_INFO_STR':
            '"liblsl:$liblslVersion/pugixml:1.15/dart-hooks"',
        if (os == OS.windows) ...{
          'LSLNOAUTOLINK': null,
          '_CRT_SECURE_NO_WARNINGS': null,
          '_WIN32_WINNT': '0x0A00',
        },
      },
      flags: [
        // LSL timeout exceptions must release native mutexes during unwinding.
        if (os == OS.windows) '/EHsc',
        if (os != OS.windows) ...[
          '-fvisibility=hidden',
          '-fvisibility-inlines-hidden',
        ],
        if (os == OS.linux) '-pthread',
      ],
      libraries: [
        if (os == OS.windows) ...[
          'iphlpapi',
          'winmm',
          'mswsock',
          'ws2_32',
          'bcrypt',
        ],
        if (os == OS.linux) ...['dl', 'pthread'],
        if (os == OS.android) 'log',
      ],
    ).run(input: input, output: output);
  });
}

void validateTarget(OS os, Architecture architecture) {
  final supported = switch (os) {
    OS.macOS ||
    OS.linux ||
    OS.windows => [Architecture.arm64, Architecture.x64],
    OS.iOS => [Architecture.arm64, Architecture.x64],
    OS.android => [Architecture.arm, Architecture.arm64, Architecture.x64],
    _ => <Architecture>[],
  };
  if (!supported.contains(architecture)) {
    throw UnsupportedError(
      'liblsl does not support $os/$architecture in this package.',
    );
  }
}
