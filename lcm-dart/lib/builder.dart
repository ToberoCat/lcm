import 'dart:async';
import 'package:build/build.dart';

import 'src/parser/lexer.dart';
import 'src/parser/parser.dart';
import 'src/parser/token.dart';
import 'src/parser/ast.dart';
import 'src/generator/dart_generator.dart';

/// Builder that generates Dart code from LCM message definitions
///
/// This is a pure Dart implementation that doesn't require the external
/// lcm-gen binary to be installed.
class LcmBuilder implements Builder {
  @override
  final buildExtensions = const {
    '.lcm': ['.dart']
  };

  @override
  Future<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    final inputPath = inputId.path;

    // Generate output path - same directory, change extension
    final outputPath = inputPath.replaceAll('.lcm', '.dart');
    final outputId = AssetId(inputId.package, outputPath);

    // Read the input file
    final content = await buildStep.readAsString(inputId);

    try {
      // Tokenize
      final lexer = LcmLexer(content, inputPath);
      final tokens = lexer.tokenize();

      // Parse
      final parser = LcmParser(tokens, inputPath);
      final lcmFile = parser.parse();

      // Generate Dart code
      final generator = DartGenerator();
      final dartCode = generator.generate(lcmFile);

      // Write output
      await buildStep.writeAsString(outputId, dartCode);

      log.info('Generated ${outputId.path} from ${inputId.path}');
    } on LexerException catch (e) {
      log.severe('Lexer error in ${inputId.path}: $e');
    } on ParseException catch (e) {
      log.severe('Parse error in ${inputId.path}: $e');
    } catch (e, stack) {
      log.severe('Error generating ${inputId.path}: $e\n$stack');
    }
  }
}

/// Creates the LCM builder
Builder lcmBuilder(BuilderOptions options) => LcmBuilder();
