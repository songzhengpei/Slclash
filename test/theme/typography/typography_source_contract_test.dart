import 'dart:io';

// analyzer is already present through the repository's lint toolchain.
// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/analysis/utilities.dart';
// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/ast/ast.dart';
// ignore: depend_on_referenced_packages
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:flutter_test/flutter_test.dart';

const _twemojiFiles = {
  'lib/widgets/text.dart',
  'lib/views/dashboard/widgets/network_detection.dart',
  'lib/views/dashboard/widgets/network_overview_card.dart',
};

const _thirdPartyAdapterFiles = {'lib/pages/editor.dart'};
const _nonTextFittedBoxFiles = {'lib/widgets/open_container.dart'};

class _TypographyContractVisitor extends RecursiveAstVisitor<void> {
  _TypographyContractVisitor(this.path, this.source);

  final String path;
  final String source;
  final List<String> violations = [];

  void _report(AstNode node, String rule) {
    final line = '\n'.allMatches(source.substring(0, node.offset)).length + 1;
    violations.add('$path:$line: $rule');
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    if (node.constructorName.type.name.lexeme == 'TextStyle') {
      _report(node, 'create typography through a semantic role, not TextStyle');
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitNamedExpression(NamedExpression node) {
    final name = node.name.label.name;
    if ({'fontSize', 'fontWeight', 'letterSpacing'}.contains(name)) {
      if (!_thirdPartyAdapterFiles.contains(path)) {
        _report(node, 'direct $name is forbidden');
      }
    }
    if (name == 'fontFamily' &&
        !_twemojiFiles.contains(path) &&
        !_thirdPartyAdapterFiles.contains(path)) {
      _report(node, 'fontFamily is restricted to registered adapters');
    }
    final call = node.parent?.parent;
    if (name == 'height' &&
        call is MethodInvocation &&
        call.methodName.name == 'copyWith') {
      _report(node, 'direct text height override is forbidden');
    }
    super.visitNamedExpression(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    if (node.propertyName.name == 'noScaling' &&
        node.target?.toSource() == 'TextScaler') {
      _report(node, 'TextScaler.noScaling is forbidden');
    }
    if ({
      'toBold',
      'toSoftBold',
      'ap',
      'mAp',
    }.contains(node.propertyName.name)) {
      _report(node, 'removed typography property ${node.propertyName.name}');
    }
    super.visitPropertyAccess(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    const removed = {
      'adjustSize',
      'toJetBrainsMono',
      'legacyType',
      'textScalerForDashboard',
    };
    if (removed.contains(node.methodName.name)) {
      _report(node, 'removed typography API ${node.methodName.name}');
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitNamedType(NamedType node) {
    if (node.name.lexeme == 'FittedBox' &&
        !_nonTextFittedBoxFiles.contains(path)) {
      _report(node, 'FittedBox requires a registered non-text adapter');
    }
    super.visitNamedType(node);
  }
}

void main() {
  test('production Dart AST obeys the typography source contract', () {
    final violations = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));

    for (final file in files) {
      final path = file.path.replaceAll('\\', '/');
      if (path.startsWith('lib/theme/typography/')) continue;
      if (path.contains('/generated/')) continue;
      if (path.contains('/app_bar/')) continue;
      final source = file.readAsStringSync();
      final result = parseString(content: source, path: path);
      final visitor = _TypographyContractVisitor(path, source);
      result.unit.accept(visitor);
      violations.addAll(visitor.violations);
    }

    expect(violations, isEmpty, reason: violations.join('\n'));
  });

  test('AST check accepts semantic styling and rejects direct structure', () {
    const allowed = '''
void build(dynamic context) {
  context.typography.body.copyWith(color: const Color(0xFF000000));
}
''';
    const forbidden = '''
void build() {
  const TextStyle(fontSize: 9, fontWeight: FontWeight.bold);
}
''';

    List<String> check(String source) {
      final visitor = _TypographyContractVisitor('fixture.dart', source);
      parseString(content: source).unit.accept(visitor);
      return visitor.violations;
    }

    expect(check(allowed), isEmpty);
    expect(check(forbidden), hasLength(3));
  });
}
