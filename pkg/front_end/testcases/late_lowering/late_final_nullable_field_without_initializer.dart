// Copyright (c) 2019, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

late final int? lateTopLevelField;

class Class<T> {
  static late final int? lateStaticField1;
  static late final int? lateStaticField2;

  static staticMethod() {
    throws(() => lateStaticField2,
        'Read value from uninitialized Class.lateStaticField2');
    lateStaticField2 = 42;
    expect(42, lateStaticField2);
    throws(() => lateStaticField2 = 43,
        'Write value to initialized Class.lateStaticField2');
  }

  late final int? lateInstanceField;

  late final T? lateGenericInstanceField;

  instanceMethod(T value) {
    throws(() => lateInstanceField,
        'Read value from uninitialized Class.lateInstanceField');
    lateInstanceField = 16;
    expect(16, lateInstanceField);
    throws(() => lateInstanceField = 17,
        'Write value to initialized Class.lateInstanceField');

    throws(() => lateGenericInstanceField,
        'Read value from uninitialized Class.lateGenericInstanceField');
    lateGenericInstanceField = value;
    expect(value, lateGenericInstanceField);
    throws(() => lateGenericInstanceField = value,
        'Write value to initialized Class.lateGenericInstanceField');
  }
}

extension Extension<T> on Class<T> {
  static late final int? lateExtensionField1;
  static late final int? lateExtensionField2;

  static staticMethod() {
    throws(() => lateExtensionField2,
        'Read value from uninitialized Class.lateExtensionField2');
    lateExtensionField2 = 42;
    expect(42, lateExtensionField2);
    throws(() => lateExtensionField2 = 43,
        'Write value to initialized Class.lateExtensionField2');
  }
}

main() {
  throws(() => lateTopLevelField,
      'Read value from uninitialized lateTopLevelField');
  lateTopLevelField = 123;
  expect(123, lateTopLevelField);
  throws(() => lateTopLevelField = 124,
      'Write value to initialized lateTopLevelField');

  throws(() => Class.lateStaticField1,
      'Read value from uninitialized Class.lateStaticField1');
  Class.lateStaticField1 = 87;
  expect(87, Class.lateStaticField1);
  throws(() => Class.lateStaticField1 = 88,
      'Write value to initialized Class.lateStaticField1');

  Class.staticMethod();
  new Class<int?>().instanceMethod(null);
  new Class<int?>().instanceMethod(0);
  new Class<int>().instanceMethod(0);

  throws(() => Extension.lateExtensionField1,
      'Read value from uninitialized Extension.lateExtensionField1');
  Extension.lateExtensionField1 = 87;
  expect(87, Extension.lateExtensionField1);
  throws(() => Extension.lateExtensionField1 = 88,
      'Write value to initialized Extension.lateExtensionField1');

  Extension.staticMethod();
}

expect(expected, actual) {
  if (expected != actual) throw 'Expected $expected, actual $actual';
}

throws(f(), String message) {
  dynamic value;
  try {
    value = f();
  } catch (e) {
    print(e);
    return;
  }
  throw '$message: $value';
}
