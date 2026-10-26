// Copyright (c) 2026 Cody Goldberg. See LICENSE for the license terms.

import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

void main() {
  final workflow =
      loadYaml(File('.github/workflows/ci.yaml').readAsStringSync()) as YamlMap;
  final jobs = workflow['jobs'] as YamlMap;

  test('every hosted job and step has a finite runtime budget', () {
    for (final entry in jobs.entries) {
      final job = entry.value as YamlMap;
      final limit = job['timeout-minutes'];
      expect(
        limit,
        allOf(isA<int>(), inInclusiveRange(1, 25)),
        reason: '${entry.key} needs a job timeout.',
      );
      for (final step in (job['steps'] as YamlList).cast<YamlMap>()) {
        expect(
          step['timeout-minutes'],
          allOf(isA<int>(), inInclusiveRange(1, limit as int)),
          reason:
              '${entry.key}: ${step['name'] ?? step['run'] ?? step['uses']} needs a step timeout.',
        );
      }
    }
  });

  test('new commits cancel superseded runs on the same ref', () {
    final concurrency = workflow['concurrency'] as YamlMap;
    expect(concurrency['cancel-in-progress'], isTrue);
    expect(concurrency['group'], contains('github.workflow'));
    expect(concurrency['group'], contains('github.ref'));
  });

  test('simulator startup, transport, and cleanup have separate deadlines', () {
    final steps = ((jobs['ios'] as YamlMap)['steps'] as YamlList)
        .cast<YamlMap>();
    final create = steps.singleWhere(
      (step) => step['name'] == 'Create an iOS simulator',
    );
    final boot = steps.singleWhere(
      (step) => step['name'] == 'Boot the iOS simulator',
    );
    final transport = steps.singleWhere(
      (step) => step['name'] == 'Test transport on an iOS simulator',
    );
    final cleanup = steps.singleWhere(
      (step) => step['name'] == 'Delete the iOS simulator',
    );
    expect(create['run'], contains('simctl create'));
    expect(create['run'], isNot(contains('simctl list')));
    expect(boot['run'], contains('Applications/Simulator.app'));
    expect(boot['timeout-minutes'], lessThanOrEqualTo(3));
    expect(boot['run'], isNot(contains('flutter test')));
    expect(transport['timeout-minutes'], lessThanOrEqualTo(8));
    expect(transport['run'], contains('--timeout 2m'));
    expect(transport['run'], contains('--verbose'));
    expect(transport['continue-on-error'], isNot(true));
    expect(cleanup['if'], contains('always()'));
    expect(cleanup['timeout-minutes'], 1);
    expect(cleanup['run'], contains('simctl delete'));
    expect(
      steps.any((step) => '${step['run']}'.contains('build ios --simulator')),
      isFalse,
      reason: 'The transport command already builds the simulator app.',
    );
  });
}
