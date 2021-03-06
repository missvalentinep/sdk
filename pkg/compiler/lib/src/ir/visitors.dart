// Copyright (c) 2017, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:kernel/ast.dart' as ir;
import 'package:kernel/class_hierarchy.dart' as ir;
import 'package:kernel/core_types.dart' as ir;
import 'package:kernel/type_algebra.dart' as ir;
import 'package:kernel/type_environment.dart' as ir;

import '../constants/constant_system.dart' as constant_system;
import '../constants/values.dart';
import '../elements/entities.dart';
import '../elements/types.dart';
import '../ir/element_map.dart';

/// Visitor that converts string literals and concatenations of string literals
/// into the string value.
class Stringifier extends ir.ExpressionVisitor<String> {
  @override
  String visitStringLiteral(ir.StringLiteral node) => node.value;

  @override
  String visitStringConcatenation(ir.StringConcatenation node) {
    StringBuffer sb = new StringBuffer();
    for (ir.Expression expression in node.expressions) {
      String value = expression.accept(this);
      if (value == null) return null;
      sb.write(value);
    }
    return sb.toString();
  }

  @override
  String visitConstantExpression(ir.ConstantExpression node) {
    ir.Constant constant = node.constant;
    if (constant is ir.StringConstant) {
      return constant.value;
    }
    return null;
  }
}

/// Visitor that converts kernel dart types into [DartType].
class DartTypeConverter extends ir.DartTypeVisitor<DartType> {
  final IrToElementMap elementMap;
  final Map<ir.TypeParameter, DartType> currentFunctionTypeParameters =
      <ir.TypeParameter, DartType>{};
  bool topLevel = true;

  DartTypeConverter(this.elementMap);

  DartType convert(ir.DartType type) {
    topLevel = true;
    return type.accept(this);
  }

  /// Visit a inner type.
  DartType visitType(ir.DartType type) {
    topLevel = false;
    return type.accept(this);
  }

  InterfaceType visitSupertype(ir.Supertype node) {
    ClassEntity cls = elementMap.getClass(node.classNode);
    return new InterfaceType(cls, visitTypes(node.typeArguments));
  }

  List<DartType> visitTypes(List<ir.DartType> types) {
    topLevel = false;
    return new List.generate(
        types.length, (int index) => types[index].accept(this));
  }

  @override
  DartType visitTypeParameterType(ir.TypeParameterType node) {
    DartType typeParameter = currentFunctionTypeParameters[node.parameter];
    if (typeParameter != null) {
      return typeParameter;
    }
    if (node.parameter.parent is ir.Typedef) {
      // Typedefs are only used in type literals so we never need their type
      // variables.
      return DynamicType();
    }
    return new TypeVariableType(elementMap.getTypeVariable(node.parameter));
  }

  @override
  DartType visitFunctionType(ir.FunctionType node) {
    int index = 0;
    List<FunctionTypeVariable> typeVariables;
    for (ir.TypeParameter typeParameter in node.typeParameters) {
      FunctionTypeVariable typeVariable = new FunctionTypeVariable(index);
      currentFunctionTypeParameters[typeParameter] = typeVariable;
      typeVariables ??= <FunctionTypeVariable>[];
      typeVariables.add(typeVariable);
      index++;
    }
    if (typeVariables != null) {
      for (int index = 0; index < typeVariables.length; index++) {
        typeVariables[index].bound =
            node.typeParameters[index].bound.accept(this);
      }
    }

    FunctionType type = new FunctionType(
        visitType(node.returnType),
        visitTypes(node.positionalParameters
            .take(node.requiredParameterCount)
            .toList()),
        visitTypes(node.positionalParameters
            .skip(node.requiredParameterCount)
            .toList()),
        node.namedParameters.map((n) => n.name).toList(),
        node.namedParameters.map((n) => visitType(n.type)).toList(),
        typeVariables ?? const <FunctionTypeVariable>[]);
    for (ir.TypeParameter typeParameter in node.typeParameters) {
      currentFunctionTypeParameters.remove(typeParameter);
    }
    return type;
  }

  @override
  DartType visitInterfaceType(ir.InterfaceType node) {
    ClassEntity cls = elementMap.getClass(node.classNode);
    if (cls.name == 'FutureOr' &&
        cls.library == elementMap.commonElements.asyncLibrary) {
      return new FutureOrType(visitTypes(node.typeArguments).single);
    }
    return new InterfaceType(cls, visitTypes(node.typeArguments));
  }

  @override
  DartType visitVoidType(ir.VoidType node) {
    return VoidType();
  }

  @override
  DartType visitDynamicType(ir.DynamicType node) {
    return DynamicType();
  }

  @override
  DartType visitInvalidType(ir.InvalidType node) {
    // Root uses such a `o is Unresolved` and `o as Unresolved` must be special
    // cased in the builder, nested invalid types are treated as `dynamic`.
    return DynamicType();
  }

  @override
  DartType visitBottomType(ir.BottomType node) {
    // TODO(fishythefish): Change `Null` to `Never` for NNBD.
    return elementMap.commonElements.nullType;
  }
}

class ConstantValuefier extends ir.ComputeOnceConstantVisitor<ConstantValue> {
  final IrToElementMap elementMap;

  ConstantValuefier(this.elementMap);

  @override
  ConstantValue defaultConstant(ir.Constant node) {
    throw new UnsupportedError(
        "Unexpected constant $node (${node.runtimeType}).");
  }

  @override
  ConstantValue visitUnevaluatedConstant(ir.UnevaluatedConstant node) {
    throw new UnsupportedError("Unexpected unevaluated constant $node.");
  }

  @override
  ConstantValue visitTypeLiteralConstant(ir.TypeLiteralConstant node) {
    DartType type;
    if (node.type is ir.FunctionType) {
      ir.FunctionType functionType = node.type;
      type = elementMap.getTypedefType(functionType.typedef);
    } else {
      type = elementMap.getDartType(node.type);
    }
    return constant_system.createType(elementMap.commonElements, type);
  }

  @override
  ConstantValue visitTearOffConstant(ir.TearOffConstant node) {
    FunctionEntity function = elementMap.getMethod(node.procedure);
    DartType type = elementMap.getFunctionType(node.procedure.function);
    return new FunctionConstantValue(function, type);
  }

  @override
  ConstantValue visitPartialInstantiationConstant(
      ir.PartialInstantiationConstant node) {
    List<DartType> typeArguments = [];
    for (ir.DartType type in node.types) {
      typeArguments.add(elementMap.getDartType(type));
    }
    FunctionConstantValue function = visitConstant(node.tearOffConstant);
    return new InstantiationConstantValue(typeArguments, function);
  }

  @override
  ConstantValue visitInstanceConstant(ir.InstanceConstant node) {
    InterfaceType type =
        elementMap.createInterfaceType(node.classNode, node.typeArguments);
    Map<FieldEntity, ConstantValue> fields = {};
    node.fieldValues.forEach((ir.Reference reference, ir.Constant value) {
      FieldEntity field = elementMap.getField(reference.asField);
      fields[field] = visitConstant(value);
    });
    return new ConstructedConstantValue(type, fields);
  }

  @override
  ConstantValue visitListConstant(ir.ListConstant node) {
    List<ConstantValue> elements = [];
    for (ir.Constant element in node.entries) {
      elements.add(visitConstant(element));
    }
    DartType type = elementMap.commonElements
        .listType(elementMap.getDartType(node.typeArgument));
    return constant_system.createList(
        elementMap.commonElements, type, elements);
  }

  @override
  ConstantValue visitSetConstant(ir.SetConstant node) {
    List<ConstantValue> elements = [];
    for (ir.Constant element in node.entries) {
      elements.add(visitConstant(element));
    }
    DartType type = elementMap.commonElements
        .setType(elementMap.getDartType(node.typeArgument));
    return constant_system.createSet(elementMap.commonElements, type, elements);
  }

  @override
  ConstantValue visitMapConstant(ir.MapConstant node) {
    List<ConstantValue> keys = [];
    List<ConstantValue> values = [];
    for (ir.ConstantMapEntry element in node.entries) {
      keys.add(visitConstant(element.key));
      values.add(visitConstant(element.value));
    }
    DartType type = elementMap.commonElements.mapType(
        elementMap.getDartType(node.keyType),
        elementMap.getDartType(node.valueType));
    return constant_system.createMap(
        elementMap.commonElements, type, keys, values);
  }

  @override
  ConstantValue visitSymbolConstant(ir.SymbolConstant node) {
    return constant_system.createSymbol(elementMap.commonElements, node.name);
  }

  @override
  ConstantValue visitStringConstant(ir.StringConstant node) {
    return constant_system.createString(node.value);
  }

  @override
  ConstantValue visitDoubleConstant(ir.DoubleConstant node) {
    return constant_system.createDouble(node.value);
  }

  @override
  ConstantValue visitIntConstant(ir.IntConstant node) {
    return constant_system.createIntFromInt(node.value);
  }

  @override
  ConstantValue visitBoolConstant(ir.BoolConstant node) {
    return constant_system.createBool(node.value);
  }

  @override
  ConstantValue visitNullConstant(ir.NullConstant node) {
    return constant_system.createNull();
  }
}
