/// Dart bindings and code generator for LCM (Lightweight Communications and Marshalling)
library lcm_dart;

// Core LCM functionality
export 'src/lcm_buffer.dart';
export 'src/lcm.dart';

// Parser (for programmatic use)
export 'src/parser/token.dart';
export 'src/parser/lexer.dart';
export 'src/parser/ast.dart';
export 'src/parser/parser.dart';

// Generator (for programmatic use)
export 'src/generator/fingerprint.dart';
export 'src/generator/type_mapper.dart';
export 'src/generator/dart_generator.dart';
