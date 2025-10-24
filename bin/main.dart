#!/usr/bin/env dart

// Pure Dart entry point for Star PRNT Flutter testing
// This runs independently of Flutter

import '../lib/main.dart' as lib_main;

Future<void> main(List<String> args) async {
  await lib_main.main();
}