// Copyright (c) 2020, the Dart project authors. Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:analysis_server/src/services/correction/fix.dart';
import 'package:analysis_server/src/services/linter/lint_names.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

import 'fix_processor.dart';

main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RemoveArgumentTest);
  });
}

@reflectiveTest
class RemoveArgumentTest extends FixProcessorLintTest {
  @override
  FixKind get kind => DartFixKind.REMOVE_ARGUMENT;

  @override
  String get lintCode => LintNames.avoid_redundant_argument_values;

  test_named_param() async {
    await resolveTestUnit('''
void f({bool valWithDefault = true, bool val}) {}

void main() {
  f(valWithDefault: /*LINT*/true);
}
''');
    await assertHasFix('''
void f({bool valWithDefault = true, bool val}) {}

void main() {
  f();
}
''');
  }

  test_named_param_2() async {
    await resolveTestUnit('''
void f({bool valWithDefault = true, bool val}) {}

void main() {
  f(valWithDefault: /*LINT*/true, false);
}
''');
    await assertHasFix('''
void f({bool valWithDefault = true, bool val}) {}

void main() {
  f(false);
}
''');
  }

  test_optional_positional() async {
    await resolveTestUnit('''
void g(int x, [int y = 0]) {}

void main() {
  g(1, /*LINT*/0);
}
''');
    await assertHasFix('''
void g(int x, [int y = 0]) {}

void main() {
  g(1);
}
''');
  }
}
