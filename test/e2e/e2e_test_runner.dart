import 'package:flutter_test/flutter_test.dart';
import 'e2e_dairy_distribution_test.dart' as e2e_test;

/// Standalone entry point for executing the Milk HUB E2E Test Suite.
/// Runs all 4 tiers (72 tests) verifying R1-R5 requirements.
void main() {
  group('Milk HUB E2E Master Test Runner', () {
    e2e_test.main();
  });
}
